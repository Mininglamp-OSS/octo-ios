#
# Be sure to run `pod lib lint WuKongBase.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'WuKongBase'
  s.version          = '0.1.0'
  s.summary          = 'A short description of WuKongBase.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/tangtaoit/WuKongBase'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tangtaoit' => 'tt@wukong.ai' }
  s.source           = { :git => 'https://github.com/tangtaoit/WuKongBase.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '14.0'
  s.platform     = :ios, '14.0'
  
  s.resource_bundles = {
    'WuKongBase_images' => ['WuKongBase/Assets/Images.xcassets'],
    'WuKongBase_resources' => ['WuKongBase/Assets/DB','WuKongBase/Assets/emoji','WuKongBase/Assets/Other']
  }
 
 s.resources = ['WuKongBase/Assets/Lang']

  
 
  s.private_header_files = 'WuKongBase/Classes/Vendor/**/*'
  s.source_files = 'WuKongBase/Classes/**/*'
  # 排除许可证不兼容或已替换的代码：
  # - SoundTouch (LGPL v2.1) — 已用 no-op stub 替换变声功能
  # - TelegramUtils 中依赖 librlottie 的子目录（AnimatedStickerNode 等）—
  #   外部消费方已删除
  # - TelegramUtils/Display/Source/{ContextGesture, ContextControllerSourceNode,
  #   TapLongTapOrDoubleTapGestureRecognizer, ContextContentSourceNode}.swift
  #   已物理删除并由 Sections/Common/MessageGesture/ 下的 Octo 自实现替代；
  #   exclude_files 留作护栏，防止后续 git revert 回来又被编进二进制。
  # TelegramUtils 其余文件保留在编译链内（cells 不再依赖它们的 GPL 实现，但
  # NavigationBar 等内部链路仍在用）。完整剥离是 P5 长期工作。
  s.exclude_files = [
    'WuKongBase/Classes/Vendor/SoundTouch/**/*',
    'WuKongBase/Classes/Vendor/LegacyComponents/**/*',
    # TelegramUtils 排除：依赖已断链子目录（librlottie / ContextUI / POP / 其他）
    'WuKongBase/Classes/Sections/Common/TelegramUtils/AnimatedStickerNode/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/TelegramAnimatedStickerNode/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/AnimationCompression/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/LiMaoMock/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/ReactionSelectionNode/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/ContextUI/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/TextSelectionNode/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/LegacyComponents/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/RadialStatusNode/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/ShimmerEffect/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/GradientBackground/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/MetalImageView/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/MediaResources/**/*',
    # PR-A: 实测无外部消费方 + 无 Display 内部消费，可立即下线（GPL 体积持续瘦身）
    'WuKongBase/Classes/Sections/Common/TelegramUtils/Utils/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/Svg/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/YuvConversion/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/TelegramUIPreferences/**/*',
    # PR-B: 预飞 grep 0 内部下游，build 验证型一并下线
    # (ObjCRuntimeUtils 被 UIKitRuntimeUtils 6 个文件用，留到 PR-C 跟 UIKitRuntimeUtils
    # 一起处理；强行 exclude 会编译挂)
    'WuKongBase/Classes/Sections/Common/TelegramUtils/Others/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/ManagedFile/**/*',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/GZip/**/*',
    # 护栏：上述 4 个 GPL 文件已删除，留 exclude 防止误恢复
    'WuKongBase/Classes/Sections/Common/TelegramUtils/Display/Source/ContextGesture.swift',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/Display/Source/ContextControllerSourceNode.swift',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/Display/Source/TapLongTapOrDoubleTapGestureRecognizer.swift',
    'WuKongBase/Classes/Sections/Common/TelegramUtils/Display/Source/ContextContentSourceNode.swift',
    # ContextContentContainerNode 只被 ContextUI 消费（已 exclude），随之排除
    'WuKongBase/Classes/Sections/Common/TelegramUtils/Display/Source/ContextContentContainerNode.swift',
    # 保留编译：Display 其余文件 + 它依赖的支撑模块
    # SwiftSignalKit / AppBundle / Utils / ObjCRuntimeUtils / UIKitRuntimeUtils / Markdown
    # / GZip / Svg / ManagedFile / AnimatedCountLabelNode / AnimatedNavigationStripeNode
    # / TelegramUIPreferences / Others / YuvConversion
  ]
#  s.preserve_paths = 'ios/arm/*.{a}'
#   s.vendored_frameworks  = 'ios/WuKongIMSDK.framework'
  
   
  # s.ios.resource   = 'ios/WuKongIMSDK.framework/Versions/A/Resources/WuKongIMSDK.bundle'
  
#  s.static_framework = true
#  s.dependency 'WuKongIMSDK', '~> 0.1.19'

#  s.pod_target_xcconfig = {
#    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
#     'DEFINES_MODULE' => 'YES',
#     'ENABLE_BITCODE' => 'YES',
#     'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES'
#  }
#   s.xcconfig = { "OTHER_LDFLAGS" => "-ObjC" }
#  s.vendored_libraries = 'WuKongBase/WuKongIMSDK-Framework/ios/*.{a}'
#  s.resource  = 'WuKongBase/WuKongIMSDK-Framework/ios/WuKongIMSDK.framework/Versions/A/Resources/WuKongIMSDK.bundle'
  # Bugly.framework 是腾讯闭源 SDK，开源版默认不附带（避免分发闭源二进制 + 减小仓库体积）。
  # 仅当用户把 Bugly.framework 放回 WuKongBase/Bugly.framework/ 时，自动加入编译。
  # Podfile 会检测同样条件并设置 OCTO_ENABLE_BUGLY=1 预处理宏。
  if File.exist?(File.expand_path('WuKongBase/Bugly.framework', __dir__))
    s.vendored_frameworks = 'WuKongBase/Bugly.framework'
  end
#  s.libraries = 'opencore-amrnb', 'opencore-amrwb','vo-amrwbenc', 'sqlite3', 'stdc++','xml2'
  s.libraries = 'c++','stdc++'
#  s.dependency 'FLEX'
  s.dependency 'WuKongIMSDK'
  s.dependency 'CocoaLumberjack','~> 3.0'
  s.dependency 'PromiseKit/CorePromise', '~> 6.0'
  s.dependency 'AFNetworking', '~> 4.0'
  s.dependency 'Toast','~> 4.0'
  s.dependency 'MBProgressHUD', '~> 1.1.0'
  s.dependency 'DGActivityIndicatorView', '~> 2.1.1'
  s.dependency 'M80AttributedLabel', '~> 1.9.9'
  s.dependency 'YBImageBrowser/NOSD','~> 3.0'
  s.dependency 'YYImage/WebP','~> 1.0.4'
  s.dependency 'TZImagePickerController', '~>3.6.4'
#  s.dependency 'MenuItemKit', '~> 4.0.0'
  s.dependency 'LBXScan/LBXNative', '~> 2.5'
  s.dependency 'LBXScan/LBXZXing', '~> 2.5'
  s.dependency 'LBXScan/UI', '~> 2.5'
  s.dependency 'MJRefresh','~> 3.0'
#  s.dependency 'WKJavaScriptBridge', '~> 1.0.0'
  s.dependency 'CocoaAsyncSocket', '~> 7.6.5'
  s.dependency 'TOCropViewController', '~> 2.5.3'
  s.dependency 'SDWebImage','~> 5.9.1'
  s.dependency 'SDWebImageWebPCoder','~> 0.6.1'
#  s.dependency 'FMDB', '2.5'
  s.dependency 'FMDB/SQLCipher', '~>2.7.5'
  s.dependency 'lottie-ios', '~> 2.5.3'
  s.dependency 'SDWebImageLottieCoder','~> 0.1.0'
  s.dependency 'GZIP','~> 1.3.0'
  s.dependency 'ZLPhotoBrowser', '4.5.5'
  s.dependency 'ZLImageEditor', '1.1.7'
  s.dependency 'ActionSheetPicker-3.0'
#  s.dependency 'VIMediaCache', '~> 0.4'
  s.dependency 'AsyncDisplayKit', '~> 1.0'
  s.dependency 'FPSCounter', '~> 4.1'
  # librlottie (LGPL) 已在 P5 移除 — 消费方 WKAnimatedStickerNode/WKMessageStickerCell 均为死代码
  s.dependency 'libcmark_gfm'
  s.dependency 'iosMath', '~> 0.9'  # LaTeX 数学公式渲染（纯 OC + CoreText，无 WebView）
  s.dependency 'RiveRuntime', '~> 6.11'
  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '$(inherited)'
  }
  
#  s.dependency 'SVGKit'
  
  
  # s.resource_bundles = {
  #   'WuKongBase' => ['WuKongBase/Assets/*.png']
  # }
 
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
#  s.xcconfig = { 'LIBRARY_SEARCH_PATHS' => '/Users/tt/work/projects/mos/WuKongIMDemo/Modules/WuKongBase/ios/arm',"OTHER_LDFLAGS" => "-ObjC" }
  s.frameworks = 'UIKit', 'MapKit', 'AVFoundation', 'Speech', 'SafariServices'
  # s.dependency 'AFNetworking', '~> 2.3'
  
  
  
end
