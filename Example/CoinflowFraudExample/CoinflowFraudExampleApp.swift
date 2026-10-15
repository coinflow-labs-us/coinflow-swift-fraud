import SwiftUI
import CoinflowFraud

@main
struct CoinflowFraudExampleApp: App {
    init() {
        Task { await CoinflowFraud.shared.initialize(merchantId: ExampleConfig.merchantId, env: ExampleConfig.env) }
    }

    var body: some Scene {
        WindowGroup {
            FraudDemoView()
        }
    }
}

// Set these as environment variables in the scheme (Product > Scheme > Edit Scheme > Run > Arguments).
enum ExampleConfig {
    private static let environment = ProcessInfo.processInfo.environment

    static let merchantId = environment["COINFLOW_MERCHANT_ID"] ?? "coinflow"
    static let env = CoinflowFraudEnv(rawValue: environment["COINFLOW_ENV"] ?? "sandbox") ?? .sandbox
    // Optional. When set, "Send request" POSTs here with the x-device-id header attached.
    static let chargeUrl = environment["COINFLOW_CHARGE_URL"].flatMap(URL.init(string:))
    // For scripted runs: collect once after launch and print the headers.
    static let autorun = environment["COINFLOW_FRAUD_AUTORUN"] == "1"
}
