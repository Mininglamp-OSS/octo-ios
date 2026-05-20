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
  # 排除许可证不兼容的代码：当前无遗留。
  # 历史记录：
  # - SoundTouch (LGPL v2.1) — 2026-05 物理移除，消费链已先 stub 为 no-op
  #   (CWVoiceChangePlayCell.mm 等)，变声功能待用 AVAudioUnitTimePitch 重写。
  # - TelegramUtils (GPL v2) — 2026-05 整体物理移除，cell 端长按出菜单由
  #   Sections/Common/MessageGesture/ 下的 Octo 自实现接管，
  #   StickerShimmerEffectNode 由 Sections/Common/Component/WKShimmerView 替代。
  # - LegacyComponents (POP, Apache 2.0 实际许可) — 2026-05 物理移除，
  #   0 消费方，是历史遗留死代码。
  s.exclude_files = []
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
  # Bugly 崩溃上报（腾讯闭源 SDK）—— 双路径自动启用：
  #   1) 优先：本地 Bugly.framework（用户自己控制版本时）
  #      仓库默认不附带（避免在公开 repo 分发闭源二进制）
  #   2) 否则：若 OctoConfig.xcconfig 里填了 OCTO_BUGLY_APP_ID_MAIN，
  #      自动从 CocoaPods 拉 Tencent 官方 pod 'Bugly' (~> 2.6)，
  #      pod install 自动从 Tencent CDN 下载，无需手动放 .framework。
  #   3) 都未满足：DISABLED，不增加 app 体积，不影响其他功能。
  # Podfile post_install 同样的 AppId 判定来设置 OCTO_ENABLE_BUGLY=1 宏。
  #
  # 注意 WuKongBase 故意**不**用 static_framework — 否则 Bugly 符号解析压力
  # 会下放给 WuKongDataSource / WuKongLogin / WuKongContacts 这些下游 pod，
  # 它们都得加 -framework Bugly。dynamic + Podfile 的 monkey-patch 压住
  # CocoaPods 的"transitive static"误报，是最简洁的方案。
  local_bugly_path = File.expand_path('WuKongBase/Bugly.framework', __dir__)
  bugly_will_be_used = false
  if File.exist?(local_bugly_path)
    s.vendored_frameworks = 'WuKongBase/Bugly.framework'
    bugly_will_be_used = true
  else
    octo_config_path = File.expand_path('../../OctoConfig.xcconfig', __dir__)
    if File.exist?(octo_config_path)
      bugly_app_id = ''
      File.foreach(octo_config_path) do |line|
        if line.strip =~ /^OCTO_BUGLY_APP_ID_MAIN\s*=\s*(.+)$/
          bugly_app_id = $1.strip.sub(%r{\s*//.*$}, '').strip
          break
        end
      end
      if !bugly_app_id.empty? && bugly_app_id != 'YOUR_BUGLY_APP_ID'
        s.dependency 'Bugly', '~> 2.6'
        bugly_will_be_used = true
      end
    end
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
  # 🎉/🎊 表情礼花动画 — 引入 2 个 MIT 候选，运行时由 WKConfettiView
  # 内的 Backend 枚举决定用哪个；选定后可移除另一个。
  # (SAConfettiView 评估过但其 pod 2016 年版本是 Swift 2/3 代码，在新 Swift
  # 下编译不过 — 已淘汰。)
  s.dependency 'SPConfetti', '~> 1.4'             # MIT, ivanvorobei
  s.dependency 'SwiftConfettiView', '~> 2.0'      # MIT, ugurethemaydin (含 burst/depth)
  # Bugly 启用时（s.dependency 'Bugly' 或本地 vendored_frameworks），WuKongBase
  # 自身也必须 link Bugly 才能解析 _OBJC_CLASS_$_Bugly 等符号；CocoaPods 对
  # static_framework + 跨 pod 依赖的自动 link 不到位，这里显式加。
  bugly_ldflag = bugly_will_be_used ? ' -framework "Bugly"' : ''
  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '$(inherited)',
    'OTHER_LDFLAGS' => '$(inherited)' + bugly_ldflag
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
