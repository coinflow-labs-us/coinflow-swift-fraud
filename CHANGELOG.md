# Changelog

## 0.2.1

- The device signal SDK accepts versions 1.3.17 through 1.4.x instead of 1.4.1 through 1.4.x, so an
  app that already ships a conflicting fingerprinting framework can pin an older compatible version in
  its Podfile. Apps that don't pin it still resolve the latest version.

## 0.2.0

- The purchase signal SDK is bundled in the `CoinflowFraud` pod, so apps add only `pod 'CoinflowFraud'`.
- A non-forced `initialize` with a different merchant or env is ignored and logged; pass `force: true`
  to switch.
- `purchaseHeaders()` waits only for the providers to be built, not for the merchant lookup.

## 0.1.0

- Initial release of the Coinflow fraud-protection SDK for iOS.
- `CoinflowFraud.shared.initialize(merchantId:env:)` + `purchaseHeaders()`.
- Emits a single opaque `x-device-id` header (versioned base64url JSON), decoded server-side.
- Signal sources ship as CocoaPods subspecs; no provider is named on the public API.
