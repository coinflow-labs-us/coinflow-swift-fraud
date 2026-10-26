Pod::Spec.new do |s|
  s.name             = 'CoinflowFraud'
  s.version          = File.read(File.join(__dir__, 'VERSION')).strip
  s.summary          = 'Coinflow fraud protection for iOS.'
  s.description      = 'Collects Coinflow fraud-protection signals and returns them as one opaque x-device-id header to attach to Coinflow API calls.'
  s.homepage         = 'https://coinflow.cash'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'Coinflow' => 'support@coinflow.cash' }
  # Published like the Swift SDK: clone-libraries mirrors this directory and tags v<VERSION>.
  s.source           = { :git => 'https://github.com/coinflow-labs-us/coinflow-swift-fraud.git', :tag => "v#{s.version}" }
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'

  # Each signal source is its own subspec so its adapter compiles in (Providers.swift, #if canImport)
  # only when its SDK is a dependency. The defaults include all of them.
  s.default_subspecs = 'Session', 'Device', 'Purchase'

  s.subspec 'Core' do |core|
    core.source_files = 'Sources/CoinflowFraud/**/*.swift'
  end

  s.subspec 'Session' do |session|
    session.dependency 'CoinflowFraud/Core'
    session.dependency 'VerisoulSDK', '~> 0.4.71'
  end

  s.subspec 'Device' do |device|
    device.dependency 'CoinflowFraud/Core'
    device.dependency 'nSure', '>= 1.3.17', '< 1.5'
  end

  # Bundled (Vendor/, version 3.2.3) with the vendor's approval, since it isn't on CocoaPods trunk.
  s.subspec 'Purchase' do |purchase|
    purchase.dependency 'CoinflowFraud/Core'
    purchase.vendored_frameworks = 'Vendor/ForterSDK.xcframework', 'Vendor/FTRAuth.xcframework',
                                   'Vendor/FTRCommon.xcframework'
    purchase.frameworks = 'CFNetwork', 'SystemConfiguration', 'CoreTelephony', 'UIKit'
  end
end
