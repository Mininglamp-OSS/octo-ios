#
# AdaptiveCards.podspec —— octo 本地 vendored 版
#
# 来源：microsoft/Teams-AdaptiveCards-Mobile iOS adaptivecards-ios 2.11.9
# 许可：MIT（源码本身；见同目录 LICENSE 与 UPSTREAM-README.md）
#   微软官方**预编译二进制包**受 Adaptive Cards Binary EULA 约束，但**源码本身**
#   由 MIT 许可（见 upstream README「NOTE: All of the source code, itself ...
#   continue to be governed by the open source MIT license」）。
#   我们以**源码形式**自行编译，故走 MIT，不消费 EULA 二进制 pod。
#
# 与 upstream podspec 的差异：
#   1. license 标 MIT（upstream 标 EULA，那是给二进制包的）。
#   2. **移除 UIProviders 子 spec** —— 去掉 MicrosoftFluentUI 依赖。
#      FluentUI 仅被 ACRBaseTarget.mm / ACRBadgeView.mm 用到，且被
#      `#if defined(ADAPTIVECARDS_USE_FLUENT_TOOLTIPS)` 包住；不定义该宏即编译掉。
#   3. 源码路径改为本仓库 vendored 布局（ios/ 与 cpp/ObjectModel/）。
#   4. name 保留 'AdaptiveCards'，使源码里 `#import <AdaptiveCards/X.h>` 正常解析。
#
Pod::Spec.new do |spec|
  spec.name             = 'AdaptiveCards'
  spec.version          = '2.11.9'
  spec.license          = { :type => 'MIT', :file => 'LICENSE' }
  spec.homepage         = 'https://adaptivecards.io'
  spec.authors          = { 'AdaptiveCards' => 'Joseph.Woo@microsoft.com' }
  spec.summary          = 'Adaptive Cards renderer (MIT source, vendored for octo InteractiveCard)'
  spec.source           = { :git => 'https://github.com/microsoft/AdaptiveCards-Mobile.git', :tag => 'iOS/adaptivecards-ios@2.11.9' }

  # 去掉 UIProviders（FluentUI）
  spec.default_subspecs = 'AdaptiveCardsCore', 'AdaptiveCardsPrivate', 'ObjectModel'

  spec.swift_versions = ['5.0']

  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'AdaptiveCards-Swift.h',
    'CLANG_ENABLE_MODULES' => 'YES'
  }

  spec.subspec 'AdaptiveCardsCore' do |sspec|
    sspec.source_files = 'ios/*.{h,m,mm,swift}'
    sspec.resource_bundles = {'AdaptiveCards' => ['ios/Resources/**/*']}
    sspec.dependency 'AdaptiveCards/AdaptiveCardsPrivate'
    sspec.dependency 'AdaptiveCards/ObjectModel'
    sspec.dependency 'AdaptiveCards/SwiftBridge'
    # [octo] 不依赖 SVGKit —— ACRSVGImageView 已 stub（见该文件头注释）。
    # SVGKit 与本仓库 librlottie 的 rapidjson 头存在 header-map 冲突，且 octo 卡片无需 SVG。
  end

  spec.subspec 'ObjectModel' do |sspec|
    sspec.source_files = 'cpp/ObjectModel/**/*.{h,cpp}'
    sspec.header_mappings_dir = 'cpp/ObjectModel/'
    sspec.private_header_files = 'cpp/ObjectModel/**/*.{h}'
    sspec.xcconfig = {
      'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
      'CLANG_CXX_LIBRARY' => 'libc++'
    }
  end

  spec.subspec 'AdaptiveCardsPrivate' do |sspec|
    sspec.source_files = 'ios/PrivateHeaders/**/*.{h,m,mm}'
    sspec.header_mappings_dir = 'ios/PrivateHeaders/'
    sspec.private_header_files = 'ios/PrivateHeaders/*.h'
  end

  spec.subspec 'SwiftBridge' do |sb|
    sb.source_files = 'ios/SwiftAdaptiveCards/**/*.{swift,h}'
  end

  spec.platform   = :ios, '14'
  spec.frameworks = 'AVFoundation', 'AVKit', 'CoreGraphics', 'QuartzCore', 'UIKit'
  spec.exclude_files = 'ios/include/**/*'
end
