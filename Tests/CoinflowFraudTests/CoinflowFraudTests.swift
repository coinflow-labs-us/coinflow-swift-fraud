import XCTest
@testable import CoinflowFraud

private final class FakeProvider: FraudProvider, @unchecked Sendable {
    let slot: ProtectionSlot
    private let value: String?
    private let delayNanoseconds: UInt64
    private let lock = NSLock()
    private var _calls = 0
    var calls: Int { lock.withLock { _calls } }

    init(slot: ProtectionSlot, value: String?, delayNanoseconds: UInt64 = 0) {
        self.slot = slot
        self.value = value
        self.delayNanoseconds = delayNanoseconds
    }

    func token() async -> String? {
        lock.withLock { _calls += 1 }
        if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
        return value
    }
}

// Never returns and ignores cancellation, like a vendor call that doesn't check for it.
private struct HangingProvider: FraudProvider {
    let slot: ProtectionSlot

    func token() async -> String? {
        await withUnsafeContinuation { (_: UnsafeContinuation<String?, Never>) in }
    }
}

private actor LookupStub {
    private var responses: [PartnerIdLookup]
    private(set) var calls: [(String, CoinflowFraudEnv)] = []
    private let delayNanoseconds: UInt64

    init(_ responses: [PartnerIdLookup], delayNanoseconds: UInt64 = 0) {
        self.responses = responses
        self.delayNanoseconds = delayNanoseconds
    }

    func fetch(_ merchantId: String, _ env: CoinflowFraudEnv) async -> PartnerIdLookup {
        calls.append((merchantId, env))
        if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
        return responses.isEmpty ? .failed : responses.removeFirst()
    }
}

private actor Gate {
    private var waiter: CheckedContinuation<Void, Never>?
    private var watchers: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiter = continuation
            watchers.forEach { $0.resume() }
            watchers = []
        }
    }

    func untilWaiting() async {
        if waiter != nil || isOpen { return }
        await withCheckedContinuation { watchers.append($0) }
    }

    func open() {
        isOpen = true
        waiter?.resume()
        waiter = nil
    }
}

@MainActor
private final class FactoryRecorder {
    var baseEnvs: [CoinflowFraudEnv] = []
    var devicePartnerIds: [String] = []
    var base: [FraudProvider] = []
    var device: FraudProvider?

    var factory: ProviderFactory {
        ProviderFactory(
            base: { env in
                self.baseEnvs.append(env)
                return self.base
            },
            device: { partnerId in
                self.devicePartnerIds.append(partnerId)
                return self.device
            }
        )
    }
}

@MainActor
final class CoinflowFraudTests: XCTestCase {
    private static let shortTimeoutNanoseconds: UInt64 = 500_000_000
    private let merchantId = UUID().uuidString

    private func makeSdk(lookups: LookupStub, factory: FactoryRecorder) -> CoinflowFraud {
        CoinflowFraud(
            fetchPartnerId: { merchantId, env in await lookups.fetch(merchantId, env) },
            providerFactory: factory.factory,
            tokenTimeoutNanoseconds: Self.shortTimeoutNanoseconds
        )
    }

    private func decoded(_ headers: [String: String]) -> DecodedProtectionHeader? {
        DecodedProtectionHeader(headers[ProtectionHeader.name])
    }

    func testMapsEachSlotToItsPayloadField() async {
        let device = UUID().uuidString, session = UUID().uuidString, purchase = UUID().uuidString
        let factory = FactoryRecorder()
        factory.base = [FakeProvider(slot: .session, value: session), FakeProvider(slot: .purchase, value: purchase)]
        factory.device = FakeProvider(slot: .device, value: device)
        let sdk = makeSdk(lookups: LookupStub([.resolved(UUID().uuidString)]), factory: factory)

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        let headers = await sdk.purchaseHeaders()

        XCTAssertEqual(
            decoded(headers),
            DecodedProtectionHeader(deviceId: device, sessionId: session, purchaseToken: purchase)
        )
    }

    func testPassesTheMerchantEnvAndPartnerIdThrough() async {
        let partnerId = UUID().uuidString
        let lookups = LookupStub([.resolved(partnerId)])
        let factory = FactoryRecorder()
        let sdk = makeSdk(lookups: lookups, factory: factory)

        await sdk.initialize(merchantId: merchantId, env: .prod)

        let calls = await lookups.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.0, merchantId)
        XCTAssertEqual(calls.first?.1, .prod)
        XCTAssertEqual(factory.baseEnvs, [.prod])
        XCTAssertEqual(factory.devicePartnerIds, [partnerId])
    }

    func testReturnsNoHeaderWhenEveryProviderReturnsNil() async {
        let factory = FactoryRecorder()
        factory.base = [FakeProvider(slot: .session, value: ""), FakeProvider(slot: .purchase, value: nil)]
        let sdk = makeSdk(lookups: LookupStub([.resolved(nil)]), factory: factory)

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        let headers = await sdk.purchaseHeaders()

        XCTAssertEqual(headers, [:])
    }

    func testKeepsTheFirstNonNilTokenWhenTwoProvidersShareASlot() async {
        let session = UUID().uuidString
        let factory = FactoryRecorder()
        factory.base = [FakeProvider(slot: .session, value: session)]
        let sdk = makeSdk(lookups: LookupStub([.resolved(nil)]), factory: factory)
        sdk.register(FakeProvider(slot: .session, value: nil))
        sdk.register(FakeProvider(slot: .session, value: UUID().uuidString))

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        let headers = await sdk.purchaseHeaders()

        XCTAssertEqual(decoded(headers)?.sessionId, session)
    }

    func testIsIdempotentOnceTheMerchantConfigResolved() async {
        let lookups = LookupStub([.resolved(UUID().uuidString)])
        let factory = FactoryRecorder()
        let sdk = makeSdk(lookups: lookups, factory: factory)

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        await sdk.initialize(merchantId: merchantId, env: .sandbox)

        let calls = await lookups.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(factory.baseEnvs.count, 1)
        XCTAssertEqual(factory.devicePartnerIds.count, 1)
    }

    func testLatchesWhenTheMerchantHasNoDevicePartnerId() async {
        let lookups = LookupStub([.resolved(nil)])
        let factory = FactoryRecorder()
        let sdk = makeSdk(lookups: lookups, factory: factory)

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        await sdk.initialize(merchantId: merchantId, env: .sandbox)

        let calls = await lookups.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(factory.baseEnvs.count, 1)
        XCTAssertTrue(factory.devicePartnerIds.isEmpty)
    }

    func testRetriesAFailedLookupWithoutRebuildingTheOtherProviders() async {
        let partnerId = UUID().uuidString
        let lookups = LookupStub([.failed, .resolved(partnerId)])
        let factory = FactoryRecorder()
        let sdk = makeSdk(lookups: lookups, factory: factory)

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        await sdk.initialize(merchantId: merchantId, env: .sandbox)

        let calls = await lookups.calls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(factory.baseEnvs.count, 1)
        XCTAssertEqual(factory.devicePartnerIds, [partnerId])
    }

    func testConcurrentCallersShareOneInFlightBoot() async {
        let lookups = LookupStub([.failed], delayNanoseconds: 200_000_000)
        let factory = FactoryRecorder()
        let sdk = makeSdk(lookups: lookups, factory: factory)

        async let first: Void = sdk.initialize(merchantId: merchantId, env: .sandbox)
        async let second: Void = sdk.initialize(merchantId: merchantId, env: .sandbox)
        async let third: Void = sdk.initialize(merchantId: merchantId, env: .sandbox)
        _ = await (first, second, third)

        let calls = await lookups.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(factory.baseEnvs.count, 1)
    }

    func testPurchaseHeadersRetriesAFailedLookupInTheBackground() async {
        let partnerId = UUID().uuidString, device = UUID().uuidString
        let lookups = LookupStub([.failed, .resolved(partnerId)])
        let factory = FactoryRecorder()
        factory.device = FakeProvider(slot: .device, value: device)
        factory.base = [FakeProvider(slot: .session, value: UUID().uuidString)]
        let sdk = makeSdk(lookups: lookups, factory: factory)

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        let firstCharge = await sdk.purchaseHeaders()
        let secondCharge = await sdk.purchaseHeaders()

        let calls = await lookups.calls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls.last?.0, merchantId)
        XCTAssertNil(decoded(firstCharge)?.deviceId)
        XCTAssertEqual(decoded(secondCharge)?.deviceId, device)
        XCTAssertEqual(factory.devicePartnerIds, [partnerId])
        XCTAssertEqual(factory.baseEnvs.count, 1)
    }

    func testAChargeDoesNotWaitForABackgroundRetryLookup() async {
        let factory = FactoryRecorder()
        factory.base = [FakeProvider(slot: .session, value: UUID().uuidString)]
        let lookups = LookupStub([.failed])
        let slowRetry = LookupStub([.resolved(UUID().uuidString)], delayNanoseconds: 2_000_000_000)
        var retrying = false
        let sdk = CoinflowFraud(
            fetchPartnerId: { merchantId, env in
                await (retrying ? slowRetry : lookups).fetch(merchantId, env)
            },
            providerFactory: factory.factory,
            tokenTimeoutNanoseconds: Self.shortTimeoutNanoseconds
        )

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        retrying = true
        _ = await sdk.purchaseHeaders()
        let started = Date()
        _ = await sdk.purchaseHeaders()

        XCTAssertLessThan(Date().timeIntervalSince(started), 1)
        let initialCalls = await lookups.calls
        let retryCalls = await slowRetry.calls
        XCTAssertEqual(initialCalls.count, 1)
        XCTAssertEqual(retryCalls.count, 1)
    }

    func testPurchaseHeadersDoesNotLookUpBeforeInitialize() async {
        let lookups = LookupStub([])
        let sdk = makeSdk(lookups: lookups, factory: FactoryRecorder())

        let headers = await sdk.purchaseHeaders()

        let calls = await lookups.calls
        XCTAssertTrue(calls.isEmpty)
        XCTAssertEqual(headers, [:])
    }

    func testPurchaseHeadersWaitsForAnInFlightInitialize() async {
        let session = UUID().uuidString
        let factory = FactoryRecorder()
        factory.base = [FakeProvider(slot: .session, value: session)]
        let sdk = makeSdk(lookups: LookupStub([.resolved(nil)], delayNanoseconds: 200_000_000), factory: factory)

        let initializing = Task { await sdk.initialize(merchantId: merchantId, env: .sandbox) }
        await Task.yield()
        let headers = await sdk.purchaseHeaders()
        await initializing.value

        XCTAssertEqual(decoded(headers)?.sessionId, session)
    }

    func testInitializeDoesNotWaitForTheTokenWarmUp() async {
        let factory = FactoryRecorder()
        factory.base = [FakeProvider(slot: .session, value: UUID().uuidString, delayNanoseconds: 400_000_000)]
        let sdk = makeSdk(lookups: LookupStub([.resolved(nil)]), factory: factory)

        let started = Date()
        await sdk.initialize(merchantId: merchantId, env: .sandbox)

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.3)
    }

    func testForceKeepsRegisteredProviders() async {
        let purchase = UUID().uuidString
        let factory = FactoryRecorder()
        let sdk = makeSdk(lookups: LookupStub([.resolved(nil), .resolved(nil)]), factory: factory)
        sdk.register(FakeProvider(slot: .purchase, value: purchase))

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        await sdk.initialize(merchantId: UUID().uuidString, env: .prod, force: true)
        let headers = await sdk.purchaseHeaders()

        XCTAssertEqual(decoded(headers)?.purchaseToken, purchase)
        XCTAssertEqual(factory.baseEnvs, [.sandbox, .prod])
    }

    func testForceDiscardsAStaleBootStillAwaitingTheNetwork() async {
        let freshSession = UUID().uuidString
        let staleLookups = LookupStub([.resolved(UUID().uuidString)], delayNanoseconds: 300_000_000)
        let freshLookups = LookupStub([.resolved(nil)])
        let factory = FactoryRecorder()
        factory.device = FakeProvider(slot: .device, value: UUID().uuidString)
        var useFresh = false
        let sdk = CoinflowFraud(
            fetchPartnerId: { merchantId, env in
                await (useFresh ? freshLookups : staleLookups).fetch(merchantId, env)
            },
            providerFactory: factory.factory,
            tokenTimeoutNanoseconds: Self.shortTimeoutNanoseconds
        )

        let stale = Task { await sdk.initialize(merchantId: UUID().uuidString, env: .prod) }
        await Task.yield()
        useFresh = true
        factory.base = [FakeProvider(slot: .session, value: freshSession)]
        await sdk.initialize(merchantId: merchantId, env: .sandbox, force: true)
        await stale.value
        let headers = await sdk.purchaseHeaders()

        XCTAssertTrue(factory.devicePartnerIds.isEmpty)
        XCTAssertEqual(decoded(headers), DecodedProtectionHeader(deviceId: nil, sessionId: freshSession, purchaseToken: nil))
    }

    func testForceBeforeAPendingBootStartsDiscardsThatBoot() async {
        let stalePartnerId = UUID().uuidString
        let factory = FactoryRecorder()
        factory.device = FakeProvider(slot: .device, value: UUID().uuidString)
        let sdk = makeSdk(lookups: LookupStub([.resolved(nil), .resolved(stalePartnerId)]), factory: factory)
        let gate = Gate()
        var holdNextBoot = true
        sdk.bootWillStart = {
            guard holdNextBoot else { return }
            holdNextBoot = false
            await gate.wait()
        }

        let stale = Task { await sdk.initialize(merchantId: UUID().uuidString, env: .prod) }
        await gate.untilWaiting()
        await sdk.initialize(merchantId: merchantId, env: .sandbox, force: true)
        await gate.open()
        await stale.value

        XCTAssertEqual(factory.baseEnvs, [.sandbox])
        XCTAssertTrue(factory.devicePartnerIds.isEmpty)
    }

    func testBoundsAProviderThatIgnoresCancellation() async {
        let device = UUID().uuidString
        let factory = FactoryRecorder()
        factory.base = [HangingProvider(slot: .session)]
        factory.device = FakeProvider(slot: .device, value: device)
        let sdk = makeSdk(lookups: LookupStub([.resolved(UUID().uuidString)]), factory: factory)

        await sdk.initialize(merchantId: merchantId, env: .sandbox)
        let started = Date()
        let headers = await sdk.purchaseHeaders()

        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        XCTAssertEqual(decoded(headers), DecodedProtectionHeader(deviceId: device, sessionId: nil, purchaseToken: nil))
    }
}
