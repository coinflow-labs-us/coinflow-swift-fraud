# CoinflowFraud (iOS)

Coinflow fraud protection for iOS. Initialize it once, then attach the single opaque `x-device-id`
header it returns to your Coinflow API calls.

## Install (CocoaPods)

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks!

  pod 'CoinflowFraud', :git => 'https://github.com/coinflow-labs-us/coinflow-swift-fraud.git', :tag => 'v0.2.0'
end
```

Requires **Xcode 26 or later**: one of the bundled signal SDKs ships a binary built with Swift 6.3
against the iOS 26 SDK.

The Swift package (`Package.swift`) builds the core only, without any signal SDKs, and so produces no
tokens on its own. Use CocoaPods for the full SDK.

## Usage

```swift
import CoinflowFraud

// Once, early (app start or checkout). env is .prod or .sandbox.
await CoinflowFraud.shared.initialize(merchantId: merchantId, env: .prod)

// At charge time, attach the header to the request.
let headers = await CoinflowFraud.shared.purchaseHeaders()
// => ["x-device-id": "<opaque value>"], or [:] if no signal was available
```

`initialize` is idempotent and never throws. To switch merchant or env at runtime, call it again with
`force: true`. `purchaseHeaders()` waits for an in-flight `initialize` to build its providers, though a charge made
before the merchant config resolves may be missing the device signal. Every signal source is
time-bounded, so a slow source can't hold up a charge.

## Example app

`Example/` is a demo app that runs the SDK against a real merchant and shows the decoded header.

```bash
cd Example
pod install
open CoinflowFraudExample.xcworkspace
```
