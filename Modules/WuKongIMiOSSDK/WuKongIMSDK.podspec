#
# Be sure to run `pod lib lint WuKongIMSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'WuKongIMSDK'
  s.version          = '1.1.0'
  s.summary          = 'Octo IM protocol SDK for iOS — connection management, messaging and local storage.'

# This description is used to generate tags and improve search results.

  s.description      = <<-DESC
WuKongIMSDK is the IM protocol layer of the Octo iOS client.
It manages the persistent TCP connection to the Octo server, handles
message sending and receiving, local SQLite storage (FMDB), sequence
synchronisation, heartbeat and auto-reconnect logic.
                       DESC

  s.homepage         = 'https://github.com/Mininglamp-OSS/octo-ios'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'MININGLAMP Technology' => 'https://github.com/Mininglamp-OSS' }
  s.source           = { :git => "https://github.com/Mininglamp-OSS/octo-ios.git" }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  s.platform     = :ios, '14.0'
  s.requires_arc = true

  s.ios.deployment_target = '14.0'
  
  s.vendored_libraries = 'WuKongIMSDK/Classes/private/arm/lib/*.a'
  
  s.preserve_paths = 'WuKongIMSDK/Classes/private/arm/lib/*.a'
  s.libraries = 'opencore-amrnb', 'opencore-amrwb','vo-amrwbenc'

  s.source_files = 'WuKongIMSDK/Classes/**/*'
  s.public_header_files =  'WuKongIMSDK/Classes/**/*.h'
  s.private_header_files = 'WuKongIMSDK/Classes/private/**/*.h'
  s.frameworks = 'UIKit', 'MapKit', 'Security'
#  s.xcconfig = {
#      'ENABLE_BITCODE' => 'NO',
#      "OTHER_LDFLAGS" => "-ObjC"
#  }
  
  s.resource_bundles = {
    'WuKongIMSDK' => ['WuKongIMSDK/Assets/*.png','WuKongIMSDK/Assets/Migrations/*']
  }
  
  s.pod_target_xcconfig = {
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
      'DEFINES_MODULE' => 'YES'
  }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

  s.dependency 'CocoaAsyncSocket', '~> 7.6.5'
  s.dependency 'FMDB/SQLCipher', '~>2.7.5'
  s.dependency '25519', '~>2.0.2'
end
