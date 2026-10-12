import Foundation

// `.resolved(nil)` means the merchant has no device partner id configured, which is final; `.failed`
// means the lookup itself didn't complete, so initialize may retry.
enum PartnerIdLookup: Equatable, Sendable {
    case resolved(String?)
    case failed
}

// The device provider's partner id is configured per merchant, so it is read from Coinflow's public
// merchant view at init. Fail-open: the device provider is simply skipped without one.
enum MerchantFraudConfig {
    // Short, because initialize waits on this before any provider is registered.
    private static let requestTimeout: TimeInterval = 5

    static func fetchPartnerId(
        merchantId: String,
        env: CoinflowFraudEnv,
        session: URLSession = .shared
    ) async -> PartnerIdLookup {
        guard let url = merchantViewUrl(merchantId: merchantId, env: env) else { return .resolved(nil) }

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        guard let (data, response) = try? await session.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode
        else { return .failed }
        return lookup(status: status, data: data)
    }

    // An unknown merchant (404) won't start existing on retry; other non-200s might be transient.
    static func lookup(status: Int, data: Data) -> PartnerIdLookup {
        if status == 404 { return .resolved(nil) }
        guard status == 200 else { return .failed }
        return .resolved(partnerId(from: data))
    }

    static func merchantViewUrl(merchantId: String, env: CoinflowFraudEnv) -> URL? {
        var segment = CharacterSet.urlPathAllowed
        segment.remove(charactersIn: "/")
        guard !merchantId.isEmpty,
              let encodedId = merchantId.addingPercentEncoding(withAllowedCharacters: segment)
        else { return nil }
        return URL(string: "\(apiBaseUrl(env: env))/merchant/view/\(encodedId)")
    }

    // Both response shapes exist across environments. An empty nested id falls back to the top-level
    // one, matching the web SDK.
    static func partnerId(from data: Data) -> String? {
        guard let config = try? JSONDecoder().decode(MerchantView.self, from: data) else { return nil }
        let nested = config.nSureSettings?.nSurePartnerId ?? ""
        if !nested.isEmpty { return nested }
        let topLevel = config.nSurePartnerId ?? ""
        return topLevel.isEmpty ? nil : topLevel
    }

    private static func apiBaseUrl(env: CoinflowFraudEnv) -> String {
        switch env {
        case .prod: return "https://api.coinflow.cash"
        case .sandbox: return "https://api-sandbox.coinflow.cash"
        }
    }

    private struct MerchantView: Decodable {
        let nSurePartnerId: String?
        let nSureSettings: Settings?

        struct Settings: Decodable {
            let nSurePartnerId: String?
        }
    }
}
