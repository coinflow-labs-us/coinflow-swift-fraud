import Foundation

#if canImport(VerisoulSDK)
import VerisoulSDK
#endif
#if canImport(nSure)
import nSure
#endif
#if canImport(ForterSDK)
import ForterSDK
#endif

// Builds the built-in providers. `base` runs once per initialize cycle; `device` once the merchant's
// partner id resolves, so a config retry never re-runs the other SDKs' setup.
struct ProviderFactory {
    let base: (CoinflowFraudEnv) -> [FraudProvider]
    let device: (String) -> FraudProvider?
}

// Each adapter compiles in only when its vendor module is linked: the CocoaPods spec's default
// subspecs bring all three in, while a SwiftPM build of the core has none.
enum BuiltInProviders {
    static let factory = ProviderFactory(base: base, device: device)

    private static func base(env: CoinflowFraudEnv) -> [FraudProvider] {
        var providers: [FraudProvider] = []
        #if canImport(VerisoulSDK)
        providers.append(SessionProvider(env: env))
        #endif
        #if canImport(ForterSDK)
        providers.append(PurchaseProvider(env: env))
        #endif
        return providers
    }

    private static func device(partnerId: String) -> FraudProvider? {
        #if canImport(nSure)
        return DeviceProvider(partnerId: partnerId)
        #else
        return nil
        #endif
    }
}

// The device and purchase SDKs compute their token asynchronously after setup, so a cold read can
// come back empty. Poll briefly; CoinflowFraud's per-provider timeout bounds the total wait.
enum TokenPoller {
    private static let attempts = 10
    private static let intervalNanoseconds: UInt64 = 300_000_000

    static func poll(_ read: () -> String?) async -> String? {
        for attempt in 0..<attempts {
            if let token = read(), !token.isEmpty { return token }
            if attempt < attempts - 1 { try? await Task.sleep(nanoseconds: intervalNanoseconds) }
        }
        return nil
    }
}

#if canImport(VerisoulSDK)
/// Session token. Configured once per provider instance; `token()` only reads.
struct SessionProvider: FraudProvider {
    let slot: ProtectionSlot = .session

    init(env: CoinflowFraudEnv) {
        Verisoul.shared.configure(
            env: env == .prod ? .prod : .sandbox,
            projectId: Self.projectId(env: env)
        )
    }

    func token() async -> String? {
        try? await Verisoul.shared.session()
    }

    private static func projectId(env: CoinflowFraudEnv) -> String {
        switch env {
        case .prod: return "315da543-c486-435a-aa21-53844c469822"
        case .sandbox: return "e9f629c4-80ee-4c6d-967e-62af47d8679e"
        }
    }
}
#endif

#if canImport(nSure)
/// Device token. `partherID` is the vendor SDK's own selector spelling.
struct DeviceProvider: FraudProvider {
    let slot: ProtectionSlot = .device
    private static let appId = "9JBW2RHC7JNJN8ZQ"

    init(partnerId: String) {
        NSure.sharedInstance(withAppID: Self.appId, partherID: partnerId)
    }

    func token() async -> String? {
        await TokenPoller.poll { NSure.sharedInstance()?.deviceId }
    }
}
#endif

#if canImport(ForterSDK)
/// Purchase token.
struct PurchaseProvider: FraudProvider {
    let slot: ProtectionSlot = .purchase

    init(env: CoinflowFraudEnv) {
        ForterSDK.setup(withSiteId: Self.siteId(env: env))
    }

    func token() async -> String? {
        await TokenPoller.poll { ForterSDK.getForterToken(nil) }
    }

    static func siteId(env: CoinflowFraudEnv) -> String {
        switch env {
        case .prod: return "eb77dd3f5be4"
        case .sandbox: return "550084f08541"
        }
    }
}
#endif
