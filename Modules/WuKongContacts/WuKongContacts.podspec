#
# Be sure to run `pod lib lint WuKongContacts.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'WuKongContacts'
  s.version          = '0.1.0'
  s.summary          = 'Octo iOS contacts module — friends, groups, org structure and space management.'

  s.description      = <<-DESC
WuKongContacts provides the full contacts experience for the Octo iOS client:
contact list, group creation and management, organisation hierarchy browsing,
space (multi-tenant) switching, and real-name verification badge display.
                       DESC

  s.homepage         = 'https://github.com/Mininglamp-OSS/octo-ios'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.author           = { 'MININGLAMP Technology' => 'https://github.com/Mininglamp-OSS' }
  s.source           = { :git => 'https://github.com/Mininglamp-OSS/octo-ios', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '14.0'
  s.resource_bundles = {
    'WuKongContacts_images' => ['WuKongContacts/Assets/Images.xcassets'],
    'WuKongContacts_resources' => ['WuKongContacts/Assets/DB']
  }
  s.resources = ['WuKongContacts/Assets/Lang']
  
  s.source_files = 'WuKongContacts/Classes/**/*'
  s.dependency 'WuKongBase'
  s.dependency 'PromiseKit/CorePromise', '~> 6.0'
  s.dependency 'FMDB/SQLCipher', '~>2.7.5'
  s.dependency 'Masonry'
  s.dependency 'WuKongIMSDK'
end
