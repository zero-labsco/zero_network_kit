#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint zero_network_kit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'zero_network_kit'
  s.version          = '1.0.3'
  s.summary          = 'Flutter network diagnostics: ping, DNS, speed test, port scan and quality score.'
  s.description      = <<-DESC
A Flutter plugin for network diagnostics: connectivity check, ping, DNS
resolution, speed test, port scanning, quality scoring and micro-benchmarks.
                       DESC
  s.homepage         = 'https://github.com/zero-labsco/zero_network_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AmisKwok' => 'amiskwok@zerolabsco.com' }

  s.source           = { :path => '.' }
  s.source_files = 'zero_network_kit/Sources/zero_network_kit/**/*.swift'
  s.resource_bundles = { 'zero_network_kit_privacy' => ['zero_network_kit/Sources/zero_network_kit/PrivacyInfo.xcprivacy'] }

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
