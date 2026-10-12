import XCTest
@testable import CoinflowFraud

final class ProtectionHeaderTests: XCTestCase {
    private func randomToken() -> String { UUID().uuidString }

    func testHeaderNameMatchesContract() {
        XCTAssertEqual(ProtectionHeader.name, "x-device-id")
    }

    func testRoundTripsAllThreeTokens() {
        let deviceId = randomToken(), sessionId = randomToken(), purchaseToken = randomToken()

        let header = ProtectionHeader.encode(deviceId: deviceId, sessionId: sessionId, purchaseToken: purchaseToken)

        XCTAssertEqual(
            DecodedProtectionHeader(header),
            DecodedProtectionHeader(deviceId: deviceId, sessionId: sessionId, purchaseToken: purchaseToken)
        )
    }

    // Shared cross-platform golden vector: the TS / Dart / Kotlin encoders emit these exact bytes for these
    // tokens, and the API decodes them. Byte equality keeps the encoders from silently diverging.
    func testEncodesTheSharedGoldenVectorByteForByte() {
        XCTAssertEqual(
            ProtectionHeader.encode(deviceId: "dev", sessionId: "sess", purchaseToken: "purch"),
            "eyJ2IjoxLCJkZXZpY2VJZCI6ImRldiIsInNlc3Npb25JZCI6InNlc3MiLCJwdXJjaGFzZVRva2VuIjoicHVyY2gifQ"
        )
    }

    func testEncodesEveryKeyWithNullForAbsentOrEmptyTokens() throws {
        let sessionId = randomToken()
        let header = try XCTUnwrap(ProtectionHeader.encode(deviceId: nil, sessionId: sessionId, purchaseToken: ""))
        let json = try XCTUnwrap(DecodedProtectionHeader.json(header))

        XCTAssertEqual(Set(json.keys), ["v", "deviceId", "sessionId", "purchaseToken"])
        XCTAssertEqual(json["v"] as? Int, 1)
        XCTAssertTrue(json["deviceId"] is NSNull)
        XCTAssertEqual(json["sessionId"] as? String, sessionId)
        XCTAssertTrue(json["purchaseToken"] is NSNull)
    }

    func testUrlSafeAlphabetNoPadding() throws {
        let header = try XCTUnwrap(ProtectionHeader.encode(
            deviceId: String(repeating: randomToken(), count: 3), sessionId: nil, purchaseToken: nil
        ))
        XCTAssertNil(header.range(of: "[^A-Za-z0-9_-]", options: .regularExpression))
    }

    func testSafelyEncodesCommasQuotesSlashesAndControlChars() {
        let deviceId = "\(randomToken()),\(randomToken())/x"
        let sessionId = "has\"quote\n\\\(randomToken())"

        let header = ProtectionHeader.encode(deviceId: deviceId, sessionId: sessionId, purchaseToken: nil)

        XCTAssertEqual(
            DecodedProtectionHeader(header),
            DecodedProtectionHeader(deviceId: deviceId, sessionId: sessionId, purchaseToken: nil)
        )
    }

    func testReturnsNilWhenNoTokenOrOnlyEmptyTokens() {
        XCTAssertNil(ProtectionHeader.encode(deviceId: nil, sessionId: nil, purchaseToken: nil))
        XCTAssertNil(ProtectionHeader.encode(deviceId: "", sessionId: "", purchaseToken: nil))
    }
}
