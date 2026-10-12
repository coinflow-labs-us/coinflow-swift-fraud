# CoinflowFraud (iOS)

Coinflow fraud protection for iOS. Initialize it once, then attach the single opaque `x-device-id`
header it returns to your Coinflow API calls.

## Install (CocoaPods)

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks!

  pod 'CoinflowFraud', :git => 'https://github.com/coinflow-labs-us/coinflow-swift-fraud.git', :tag => 'v0.1.0'
  # One of the signal SDKs is distributed from its own repository rather than CocoaPods trunk.
  pod 'ForterSDK', :git => 'https://bitbucket.org/forter-mobile/forter-ios-sdk.git',
                   :commit => 'a58b18b1181580c19c00000c27638efd059d36eb' # tag 3.2.3
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
`force: true`. `purchaseHeaders()` waits for an in-flight `initialize`, and every signal source is
time-bounded, so a slow source can't hold up a charge.

## Example app

`Example/` is a demo app that runs the SDK against a real merchant and shows the decoded header.

```bash
cd Example
pod install
open CoinflowFraudExample.xcworkspace
```
