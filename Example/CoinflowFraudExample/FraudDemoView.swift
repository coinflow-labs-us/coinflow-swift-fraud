import SwiftUI
import CoinflowFraud

struct FraudDemoView: View {
    // Gives initialize, started at launch, time to start the signal SDKs.
    private static let autorunDelay: Duration = .seconds(5)

    @State private var headers: [String: String]?
    @State private var response: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coinflow Fraud Example").font(.title2).bold()
                Text("merchant \(ExampleConfig.merchantId) · env \(ExampleConfig.env.rawValue)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button {
                    Task { await buildHeaders() }
                } label: {
                    Text(busy ? "Collecting…" : "Get x-device-id header").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(busy)

                if let chargeUrl = ExampleConfig.chargeUrl {
                    Button {
                        Task { await send(to: chargeUrl) }
                    } label: {
                        Text("Send request").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(busy)
                }

                if let headers {
                    section(ProtectionHeader.name, headers[ProtectionHeader.name] ?? "(empty — no signal was available)")
                    section("Request headers", Self.json(headers))
                }

                if let response {
                    section("Response", response)
                }
            }
            .padding()
        }
        .task {
            guard ExampleConfig.autorun else { return }
            try? await Task.sleep(for: Self.autorunDelay)
            let headers = await requestHeaders()
            self.headers = headers
            print("COINFLOW_FRAUD_RESULT", Self.json(headers))
        }
    }

    private func requestHeaders() async -> [String: String] {
        let fraudHeaders = await CoinflowFraud.shared.purchaseHeaders()
        return ["Content-Type": "application/json"].merging(fraudHeaders) { _, fraud in fraud }
    }

    private func buildHeaders() async {
        busy = true
        defer { busy = false }
        headers = await requestHeaders()
        response = nil
    }

    private func send(to url: URL) async {
        busy = true
        defer { busy = false }

        let headers = await requestHeaders()
        self.headers = headers

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            let status = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
            response = "\(status)\n\(String(decoding: data, as: UTF8.self))"
        } catch {
            response = error.localizedDescription
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ value: String) -> some View {
        Text(title.uppercased()).font(.caption).bold().foregroundColor(.secondary).padding(.top, 8)
        Text(value)
            .font(.system(.footnote, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private static func json(_ headers: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: headers,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
