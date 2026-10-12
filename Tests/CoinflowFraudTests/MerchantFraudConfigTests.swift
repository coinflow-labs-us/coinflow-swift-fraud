import XCTest
@testable import CoinflowFraud

final class MerchantFraudConfigTests: XCTestCase {
    private func json(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    func testReadsTheNestedPartnerId() {
        let partnerId = UUID().uuidString
        XCTAssertEqual(
            MerchantFraudConfig.partnerId(from: json([
                "nSureSettings": ["nSurePartnerId": partnerId],
                "nSurePartnerId": UUID().uuidString,
            ])),
            partnerId
        )
    }

    func testFallsBackToTheTopLevelPartnerIdWhenNestedIsMissingOrEmpty() {
        let partnerId = UUID().uuidString
        XCTAssertEqual(MerchantFraudConfig.partnerId(from: json(["nSurePartnerId": partnerId])), partnerId)
        XCTAssertEqual(
            MerchantFraudConfig.partnerId(from: json([
                "nSureSettings": ["nSurePartnerId": ""],
                "nSurePartnerId": partnerId,
            ])),
            partnerId
        )
    }

    func testReturnsNilWhenAbsentEmptyOrUnparseable() {
        XCTAssertNil(MerchantFraudConfig.partnerId(from: json([:])))
        XCTAssertNil(MerchantFraudConfig.partnerId(from: json(["nSurePartnerId": ""])))
        XCTAssertNil(MerchantFraudConfig.partnerId(from: Data("not json".utf8)))
    }

    func testPercentEncodesTheMerchantIdAsOnePathSegment() throws {
        let url = try XCTUnwrap(MerchantFraudConfig.merchantViewUrl(merchantId: "a/b?c#d", env: .sandbox))
        XCTAssertEqual(url.absoluteString, "https://api-sandbox.coinflow.cash/merchant/view/a%2Fb%3Fc%23d")
    }

    func testUsesTheProdApiForProd() throws {
        let merchantId = UUID().uuidString
        let url = try XCTUnwrap(MerchantFraudConfig.merchantViewUrl(merchantId: merchantId, env: .prod))
        XCTAssertEqual(url.absoluteString, "https://api.coinflow.cash/merchant/view/\(merchantId)")
    }

    func testTellsAMissingPartnerIdApartFromAFailedLookup() {
        let partnerId = UUID().uuidString
        XCTAssertEqual(
            MerchantFraudConfig.lookup(status: 200, data: json(["nSurePartnerId": partnerId])),
            .resolved(partnerId)
        )
        XCTAssertEqual(MerchantFraudConfig.lookup(status: 200, data: json([:])), .resolved(nil))
        XCTAssertEqual(MerchantFraudConfig.lookup(status: 404, data: Data()), .resolved(nil))
        XCTAssertEqual(MerchantFraudConfig.lookup(status: 503, data: Data()), .failed)
        XCTAssertEqual(MerchantFraudConfig.lookup(status: 200, data: Data("not json".utf8)), .resolved(nil))
    }

    func testRejectsAnEmptyMerchantId() {
        XCTAssertNil(MerchantFraudConfig.merchantViewUrl(merchantId: "", env: .prod))
    }
}
