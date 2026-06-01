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
    # 从 podspec 所在目录向上找 OctoConfig.xcconfig — 比固定 '../../' 更健壮，
    # 兼容非标准 :path => 用法 (PR #125 round 5 review 🟡)
    octo_config_path = nil
    dir = __dir__
    loop do
      candidate = File.join(dir, 'OctoConfig.xcconfig')
      if File.exist?(candidate)
        octo_config_path = candidate
        break
      end
      parent = File.expand_path('..', dir)
      break if parent == dir   # 到根了
      dir = parent
    end
    if octo_config_path
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
  # 🎉/🎊 表情礼花动画 — 仅 SwiftConfettiView 一项；保留它主要是为了复用
  # pod 自带的 confetti.mp3 资产（爆裂声），粒子系统是 WKConfettiView 自写
  # CAEmitterLayer，不走该库的粒子实现。
  s.dependency 'SwiftConfettiView', '~> 2.0'      # MIT, ugurethemaydin
  # Bugly 静态 framework 链接策略（修复 objc duplicate class 警告 — 2026-06）
  #
  # 历史问题：Bugly 是腾讯发布的**静态** framework。CocoaPods 看到
  # `s.dependency 'Bugly'` 后，会同时给：
  #   1) WuKongBase pod 的 xcconfig 自动加 `-framework "Bugly"`
  #   2) 主 App 的 aggregate xcconfig 也加 `-framework "Bugly"`（传递依赖）
  # 结果：Bugly 的 class 被静态吸进 WuKongBase.framework 和主二进制两处，
  # 启动时 dyld 报 "Class Bugly is implemented in both ..."，包体积也虚胖一份。
  #
  # 修复：让 Bugly 只在主 App 链接一份，WuKongBase 只享用 header、不参与 link。
  #   a) 这里 pod_target_xcconfig 的 OTHER_LDFLAGS 用 `-Wl,-undefined,dynamic_lookup`
  #      允许 link WuKongBase.framework 时让 _OBJC_CLASS_$_Bugly 等符号悬空，
  #      运行时由 Obj-C runtime 的 flat namespace 自动把它指到主 App 的那份。
  #   b) Podfile 的 post_install 负责把 CocoaPods 自动写入到
  #      Pods/Target Support Files/WuKongBase/WuKongBase.{debug,release}.xcconfig
  #      里的 `-framework "Bugly"` 擦掉，否则 a) 设置依然会被 CocoaPods 覆盖。
  # 两处必须同步改，缺一不可。
  s.pod_target_xcconfig = {
    'SWIFT_INCLUDE_PATHS' => '$(inherited)',
    'OTHER_LDFLAGS' => '$(inherited)' + (bugly_will_be_used ? ' -Wl,-undefined,dynamic_lookup' : '')
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
