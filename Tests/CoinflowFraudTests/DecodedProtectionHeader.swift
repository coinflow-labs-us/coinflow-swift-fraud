import Foundation

// Test-side decoder, independent of the SDK (which only encodes). Mirrors the server's checks: base64url,
// a JSON object, v == 1.
struct DecodedProtectionHeader: Equatable {
    let deviceId: String?
    let sessionId: String?
    let purchaseToken: String?

    init(deviceId: String?, sessionId: String?, purchaseToken: String?) {
        self.deviceId = deviceId
        self.sessionId = sessionId
        self.purchaseToken = purchaseToken
    }

    init?(_ header: String?) {
        guard let header, let json = Self.json(header), (json["v"] as? Int) == 1 else { return nil }
        deviceId = json["deviceId"] as? String
        sessionId = json["sessionId"] as? String
        purchaseToken = json["purchaseToken"] as? String
    }

    static func json(_ header: String) -> [String: Any]? {
        guard !header.isEmpty else { return nil }
        var base64 = header.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
