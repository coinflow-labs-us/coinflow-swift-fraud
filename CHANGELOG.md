# Changelog

## 0.1.0

- Initial release of the Coinflow fraud-protection SDK for iOS.
- `CoinflowFraud.shared.initialize(merchantId:env:)` + `purchaseHeaders()`.
- Emits a single opaque `x-device-id` header (versioned base64url JSON), decoded server-side.
- Signal sources ship as CocoaPods subspecs; no provider is named on the public API.
