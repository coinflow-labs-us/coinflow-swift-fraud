import SwiftUI
import CoinflowFraud

// Runs the SDK against a real merchant and decodes the header to show which signals surfaced.
// Each "Get Device Id" re-initializes with the current inputs. Launch with COINFLOW_FRAUD_AUTORUN=1
// to collect once on appear and print the decoded payload, for scripted runs.
struct FraudDemoView: View {
    @State private var merchantId = ProcessInfo.processInfo.environment["COINFLOW_MERCHANT_ID"] ?? "coinflow"
    @State private var env: CoinflowFraudEnv =
        CoinflowFraudEnv(rawValue: ProcessInfo.processInfo.environment["COINFLOW_ENV"] ?? "sandbox") ?? .sandbox

    @State private var header: String?
    @State private var payload: DecodedHeader?
    @State private var busy = false
    @State private var ran = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coinflow Fraud SDK").font(.title2).bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("Merchant ID").font(.caption).foregroundColor(.secondary)
                TextField("merchant id", text: $merchantId)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            Picker("Env", selection: $env) {
                Text("sandbox").tag(CoinflowFraudEnv.sandbox)
                Text("prod").tag(CoinflowFraudEnv.prod)
            }
            .pickerStyle(.segmented)

            Button(busy ? "Collecting…" : "Get Device Id") {
                Task { await run() }
            }
            .disabled(busy)
            .buttonStyle(.borderedProminent)

            if ran {
                Text(ProtectionHeader.name).font(.caption).bold()
                Text(header ?? "(none — no signal was available)")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)

                HStack {
                    pill("Device", payload?.deviceId != nil)
                    pill("Session", payload?.sessionId != nil)
                    pill("Purchase", payload?.purchaseToken != nil)
                }

                if let payload {
                    Text("Decoded payload").font(.caption).bold()
                    VStack(alignment: .leading, spacing: 4) {
                        row("deviceId", payload.deviceId)
                        row("sessionId", payload.sessionId)
                        row("purchaseToken", payload.purchaseToken)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Spacer()
        }
        .padding()
        .task {
            guard ProcessInfo.processInfo.environment["COINFLOW_FRAUD_AUTORUN"] == "1" else { return }
            await run()
            print("COINFLOW_FRAUD_RESULT", payload.map { "\($0)" } ?? "none")
        }
    }

    private func run() async {
        busy = true
        defer { busy = false }

        await CoinflowFraud.shared.initialize(merchantId: merchantId, env: env, force: true)
        header = await CoinflowFraud.shared.purchaseHeaders()[ProtectionHeader.name]
        payload = DecodedHeader(header)
        ran = true
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label).font(.caption2).foregroundColor(.secondary).frame(width: 100, alignment: .leading)
            Text(value ?? "null")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(value == nil ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func pill(_ label: String, _ on: Bool) -> some View {
        Text("\(on ? "●" : "○") \(label)")
            .font(.caption2)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(on ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
            .foregroundColor(on ? .green : .gray)
            .clipShape(Capsule())
    }
}

// The SDK keeps decoding internal (merchants never need it), so the demo reads the header itself.
private struct DecodedHeader: CustomStringConvertible {
    let deviceId: String?
    let sessionId: String?
    let purchaseToken: String?

    init?(_ header: String?) {
        guard var base64 = header?
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        else { return nil }
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        deviceId = json["deviceId"] as? String
        sessionId = json["sessionId"] as? String
        purchaseToken = json["purchaseToken"] as? String
    }

    var description: String {
        "deviceId=\(deviceId ?? "null") sessionId=\(sessionId ?? "null") purchaseToken=\(purchaseToken ?? "null")"
    }
}
