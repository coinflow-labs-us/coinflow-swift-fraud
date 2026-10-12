import Foundation

/// The single opaque header that carries every fraud token: base64url(JSON {v, deviceId, sessionId,
/// purchaseToken}), the same wire format as the web / React Native / Flutter / Android SDKs.
public enum ProtectionHeader {
    public static let name = "x-device-id"

    static let payloadVersion = 1

    /// Returns nil when there is no token to send, so callers omit the header entirely. Empty tokens
    /// are sent as JSON null, so the backend sees one representation of "absent".
    static func encode(deviceId: String?, sessionId: String?, purchaseToken: String?) -> String? {
        let fields = [("deviceId", deviceId), ("sessionId", sessionId), ("purchaseToken", purchaseToken)]
            .map { ($0.0, nonEmpty($0.1)) }
        guard fields.contains(where: { $0.1 != nil }) else { return nil }

        // Written by hand in the cross-platform key order (JSON.stringify's), so the same tokens encode
        // to the same bytes as the other SDKs. Values still go through JSONSerialization for escaping.
        var json = "{\"v\":\(payloadVersion)"
        for (key, value) in fields {
            guard let encoded = jsonValue(value) else { return nil }
            json += ",\"\(key)\":\(encoded)"
        }
        json += "}"
        return base64UrlEncode(Data(json.utf8))
    }

    private static func jsonValue(_ value: String?) -> String? {
        guard let value else { return "null" }
        guard let data = try? JSONSerialization.data(
            withJSONObject: value,
            options: [.fragmentsAllowed, .withoutEscapingSlashes]
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func base64UrlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
