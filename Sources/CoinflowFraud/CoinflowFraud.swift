import Foundation

public enum CoinflowFraudEnv: String, Sendable {
    case prod
    case sandbox
}

/// Which field of the `x-device-id` payload a provider fills.
public enum ProtectionSlot: Sendable {
    case device
    case session
    case purchase
}

/// A source of one fraud token. The built-in providers conform to this; apps can `register` their
/// own as well.
public protocol FraudProvider: Sendable {
    var slot: ProtectionSlot { get }
    func token() async -> String?
}

/// Coinflow fraud protection for iOS. Call `initialize` early (app start or checkout), then attach
/// `purchaseHeaders()` to the charge request.
///
/// Main-actor isolated so the init state needs no locking across `await`.
@MainActor
public final class CoinflowFraud {
    public static let shared = CoinflowFraud()

    // Bounds every provider so a slow vendor SDK can't hold up a charge.
    private let tokenTimeoutNanoseconds: UInt64

    private let fetchPartnerId: @Sendable (String, CoinflowFraudEnv) async -> PartnerIdLookup
    private let providerFactory: ProviderFactory

    private var builtInProviders: [FraudProvider] = []
    private var registeredProviders: [FraudProvider] = []
    // The boot initialize started; purchaseHeaders waits for it so the providers exist.
    private var initTask: Task<Void, Never>?
    // The latest boot, including a background retry that nothing waits on.
    private var bootTask: Task<Void, Never>?
    // The last merchant/env passed to initialize, so purchaseHeaders can retry a failed lookup.
    private var config: (merchantId: String, env: CoinflowFraudEnv)?
    private var booting = false
    private var baseProvidersBuilt = false
    // Latched once the merchant config resolved (with or without a device partner id). Only a failed
    // lookup leaves it unset, so a later initialize retries.
    private var initialized = false
    // Bumped by reset() so a boot still awaiting the network can't overwrite a newer one.
    private var generation = 0
    // Test seam: awaited at the start of each boot task, to hold a boot before it first runs.
    var bootWillStart: (@MainActor () async -> Void)?

    private convenience init() {
        self.init(
            fetchPartnerId: { merchantId, env in
                await MerchantFraudConfig.fetchPartnerId(merchantId: merchantId, env: env)
            },
            providerFactory: BuiltInProviders.factory,
            tokenTimeoutNanoseconds: 8_000_000_000
        )
    }

    init(
        fetchPartnerId: @escaping @Sendable (String, CoinflowFraudEnv) async -> PartnerIdLookup,
        providerFactory: ProviderFactory,
        tokenTimeoutNanoseconds: UInt64
    ) {
        self.fetchPartnerId = fetchPartnerId
        self.providerFactory = providerFactory
        self.tokenTimeoutNanoseconds = tokenTimeoutNanoseconds
    }

    /// Adds a provider alongside the built-in ones; it survives `initialize(..., force: true)`. When two
    /// providers fill the same slot, the first non-nil token wins (built-in first, then registration
    /// order).
    public func register(_ provider: FraudProvider) {
        registeredProviders.append(provider)
    }

    /// Registers the providers and starts warming their tokens in the background. Idempotent and
    /// fail-open. Pass `force: true` to start over with a different merchant or env.
    public func initialize(merchantId: String, env: CoinflowFraudEnv, force: Bool = false) async {
        if force { reset() }
        config = (merchantId, env)
        if initialized { return }
        // Share an in-flight boot's outcome rather than racing it; a later call retries if it failed.
        if booting, let bootTask {
            await bootTask.value
            return
        }

        let task = startBoot(merchantId: merchantId, env: env)
        initTask = task
        await task.value
    }

    /// Returns `["x-device-id": <payload>]`, or `[:]` when no provider produced a token. Waits for an
    /// in-flight `initialize` to register the providers, so an early charge still carries the header.
    public func purchaseHeaders() async -> [String: String] {
        await initTask?.value
        retryFailedLookupInBackground()

        let tokens = await collectTokens()
        guard let header = ProtectionHeader.encode(
            deviceId: tokens[.device],
            sessionId: tokens[.session],
            purchaseToken: tokens[.purchase]
        ) else { return [:] }
        return [ProtectionHeader.name: header]
    }

    func reset() {
        generation += 1
        initTask = nil
        bootTask = nil
        config = nil
        booting = false
        baseProvidersBuilt = false
        initialized = false
        builtInProviders = []
    }

    @discardableResult
    private func startBoot(merchantId: String, env: CoinflowFraudEnv) -> Task<Void, Never> {
        booting = true
        // Captured now, not when the task starts: a force reset can land before it first runs.
        let bootGeneration = generation
        let task = Task {
            await bootWillStart?()
            await boot(merchantId: merchantId, env: env, generation: bootGeneration)
        }
        bootTask = task
        return task
    }

    // Merchants call initialize once, so a lookup that failed then (offline, 5xx, timeout) is retried
    // from the charge path. This charge doesn't wait for it; the next one picks up the device token.
    private func retryFailedLookupInBackground() {
        guard !initialized, !booting, let config else { return }
        startBoot(merchantId: config.merchantId, env: config.env)
    }

    private func boot(merchantId: String, env: CoinflowFraudEnv, generation bootGeneration: Int) async {
        guard bootGeneration == generation else { return }
        if !baseProvidersBuilt {
            builtInProviders = providerFactory.base(env)
            baseProvidersBuilt = true
        }

        let lookup = await fetchPartnerId(merchantId, env)
        guard bootGeneration == generation else { return }
        booting = false

        guard case .resolved(let partnerId) = lookup else { return }
        if let partnerId, let device = providerFactory.device(partnerId) {
            builtInProviders.append(device)
        }
        initialized = true

        // Warm the tokens without holding up initialize or an early purchaseHeaders().
        Task { _ = await collectTokens() }
    }

    private func collectTokens() async -> [ProtectionSlot: String] {
        let providers = builtInProviders + registeredProviders
        let timeout = tokenTimeoutNanoseconds
        let values = await withTaskGroup(of: (Int, String?).self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask { (index, await Self.boundedToken(provider, timeoutNanoseconds: timeout)) }
            }
            var values = [String?](repeating: nil, count: providers.count)
            for await (index, value) in group { values[index] = value }
            return values
        }

        var tokens: [ProtectionSlot: String] = [:]
        for (provider, value) in zip(providers, values) {
            guard let value, !value.isEmpty, tokens[provider.slot] == nil else { continue }
            tokens[provider.slot] = value
        }
        return tokens
    }

    // Unstructured tasks race the deadline: a task group would still wait for a vendor call that
    // ignores cancellation. The losing call finishes in the background.
    private nonisolated static func boundedToken(
        _ provider: FraudProvider,
        timeoutNanoseconds: UInt64
    ) async -> String? {
        await withCheckedContinuation { continuation in
            let resumer = ResumeOnce(continuation)
            Task { resumer.resume(await provider.token()) }
            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                resumer.resume(nil)
            }
        }
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String?, Never>?

    init(_ continuation: CheckedContinuation<String?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: String?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
