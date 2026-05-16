#
# Be sure to run `pod lib lint WuKongDataSource.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'WuKongDataSource'
  s.version          = '0.1.0'
  s.summary          = 'Octo iOS data-source abstraction layer used across all modules.'

  s.description      = <<-DESC
WuKongDataSource defines the data-source protocols and base implementations
shared by WuKongBase, WuKongContacts and WuKongLogin. It decouples UI
components from concrete data-fetch strategies, making the modules easier
to unit-test and swap out in host apps.
                       DESC

  s.homepage         = 'https://github.com/Mininglamp-OSS/octo-ios'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'MININGLAMP Technology' => 'https://github.com/Mininglamp-OSS' }
  s.source           = { :git => 'https://github.com/Mininglamp-OSS/octo-ios', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '14.0'

  s.source_files = 'WuKongDataSource/Classes/**/*'
  s.resources = ['WuKongDataSource/Assets/Lang']
  # s.resource_bundles = {
  #   'WuKongDataSource' => ['WuKongDataSource/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.dependency 'WuKongBase'
  s.dependency 'WuKongIMSDK'
  
end
