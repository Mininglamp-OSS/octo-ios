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
  s.summary          = 'A short description of WuKongContacts.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/tangtaoit/WuKongContacts'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tangtaoit' => 'tt@wukong.ai' }
  s.source           = { :git => 'https://github.com/tangtaoit/WuKongContacts.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'
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
