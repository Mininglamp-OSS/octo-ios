#
# Be sure to run `pod lib lint WuKongLogin.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'WuKongLogin'
  s.version          = '0.1.0'
  s.summary          = 'Octo iOS login module — account registration, sign-in, and third-party auth.'

  s.description      = <<-DESC
WuKongLogin handles all authentication flows for the Octo iOS client:
phone/email registration and sign-in, Apple Sign-In, and OIDC-based
single sign-on. Designed to be drop-in replaceable for custom auth backends.
                       DESC

  s.homepage         = 'https://github.com/Mininglamp-OSS/octo-ios'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'MININGLAMP Technology' => 'https://github.com/Mininglamp-OSS' }
  s.source           = { :git => 'https://github.com/Mininglamp-OSS/octo-ios', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '14.0'

  s.source_files = 'WuKongLogin/Classes/**/*'
  
  s.resource_bundles = {
    'WuKongLogin_images' => ['WuKongLogin/Assets/Images.xcassets']
  }
  s.private_header_files = 'WuKongLogin/Classes/Vendor/*.h'
  
  s.resources = ['WuKongLogin/Assets/Lang']
  
  # s.resource_bundles = {
  #   'WuKongLogin' => ['WuKongLogin/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.dependency 'WuKongBase'
  s.dependency 'PromiseKit/CorePromise', '~> 6.0'
  s.dependency 'Masonry'
  s.dependency 'SDWebImage','~> 5.9.1'
end
