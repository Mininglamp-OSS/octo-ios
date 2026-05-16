# Uncomment the next line to define a global platform for your project
 platform :ios, '14.0'
workspace 'TangSengDaoDaoiOS.xcworkspace'

# ─────────────────────────────────────────────────────────────────────────────
# OctoConfig.xcconfig 解析
# 私有配置（Apple Team ID / Bugly AppKey / IM 服务器等）统一放在
# OctoConfig.xcconfig（gitignored），由本 Podfile 在 post_install 阶段：
#   1. 读出所需变量（如 APPLE_TEAM_ID）赋给 build_settings；
#   2. 把 #include? "../../OctoConfig.xcconfig" 注入每个 Pods xcconfig，
#      让主工程通过 Pods 链路自动看到这些变量。
# 见 OctoConfig.xcconfig.template 了解如何配置。
# ─────────────────────────────────────────────────────────────────────────────

OCTO_CONFIG_FILE = File.expand_path('OctoConfig.xcconfig', __dir__)

def parse_octo_xcconfig(path)
    return {} unless File.exist?(path)
    vars = {}
    File.foreach(path) do |line|
        stripped = line.strip
        next if stripped.empty? || stripped.start_with?('//')
        if stripped =~ /^([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$/
            value = $2.strip.sub(%r{\s*//.*$}, '').strip
            vars[$1] = value
        end
    end
    vars
end

post_install do |installer|
    octo_config = parse_octo_xcconfig(OCTO_CONFIG_FILE)
    dev_team = octo_config['APPLE_TEAM_ID'].to_s
    dev_team = dev_team.empty? || dev_team == 'YOUR_TEAM_ID' ? '' : dev_team

    # 兼容回退：若 OctoConfig.xcconfig 缺失，沿用项目原本设置的 DEVELOPMENT_TEAM
    if dev_team.empty?
        project = installer.aggregate_targets[0].user_project
        project.targets.each do |target|
            target.build_configurations.each do |config|
                if dev_team.empty? && !config.build_settings['DEVELOPMENT_TEAM'].nil?
                    dev_team = config.build_settings['DEVELOPMENT_TEAM']
                end
            end
        end
    end

    # 把 OctoConfig.xcconfig 软引用注入到每一个 Pods xcconfig
    octo_include_line = "#include? \"../../OctoConfig.xcconfig\"\n"
    Dir.glob(File.join(__dir__, 'Pods/Target Support Files/**/*.xcconfig')).each do |xcconfig|
        contents = File.read(xcconfig)
        unless contents.include?('OctoConfig.xcconfig')
            File.write(xcconfig, octo_include_line + contents)
        end
    end

    # ─────────────────────────────────────────────────────────────────────
    # 把 OctoConfig.xcconfig 设为 ShareExtension / NotificationService /
    # NotificationContent 三个扩展的 baseConfigurationReference。这些扩展
    # 不在 Podfile 里，没有 Pods xcconfig 链路，必须直接绑定才能让
    # `$(APPLE_TEAM_ID)` 等变量在 codesign 阶段被替换。
    # 幂等：第一次 pod install 写入到 .xcodeproj，后续保持不变。
    # ─────────────────────────────────────────────────────────────────────
    user_project = installer.aggregate_targets[0].user_project
    octo_xcconfig_path = 'OctoConfig.xcconfig'
    octo_file_ref = user_project.files.find { |f| f.path == octo_xcconfig_path }
    unless octo_file_ref
        octo_file_ref = user_project.new_file(octo_xcconfig_path)
    end
    extension_target_names = %w[ShareExtension NotificationService NotificationContent]
    user_project.targets.each do |target|
        next unless extension_target_names.include?(target.name)
        target.build_configurations.each do |config|
            if config.base_configuration_reference.nil?
                config.base_configuration_reference = octo_file_ref
            end
        end
    end
    user_project.save

    # Fix bundle targets' 'Signing Certificate' to 'Sign to Run Locally'
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
              config.build_settings['DEVELOPMENT_TEAM'] = dev_team
            end
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
            config.build_settings['ENABLE_BITCODE'] = 'NO'
            config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
            # librlottie 0.2.1 (SDWebImage 官方 fork) 的 hmap 把 `config.h` 错误地
            # 映射到 `librlottie/config.h`（不存在）。关 hmap，并手动把所有 rlottie
            # 内部头文件目录加入 HEADER_SEARCH_PATHS，让 `<vrect.h>` 等 angled include
            # 能正常解析（这些文件本身就在同一目录下，需要 -I 找到它们）。
            if target.name == 'librlottie'
              config.build_settings['USE_HEADERMAP'] = 'NO'
              dirs = %w[
                generate
                rlottie/inc
                rlottie/src/vector
                rlottie/src/vector/freetype
                rlottie/src/vector/pixman
                rlottie/src/vector/stb
                rlottie/src/lottie
                rlottie/src/lottie/rapidjson
                rlottie/src/lottie/rapidjson/internal
                rlottie/src/lottie/rapidjson/error
                rlottie/src/binding/c
              ]
              config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
              dirs.each { |d| config.build_settings['HEADER_SEARCH_PATHS'] << "\"${PODS_TARGET_SRCROOT}/#{d}\"" }
            end
        end

    end

    # ============================================================
    # 为缺少隐私清单的第三方 SDK 注入 PrivacyInfo.xcprivacy
    # Apple 要求: https://developer.apple.com/support/third-party-SDK-requirements/
    # ============================================================
    pods_needing_privacy_manifest = [
        'AFNetworking',
        'FMDB',
        'MBProgressHUD',
        'SDWebImage',
        'Starscream',
        'Toast',
    ]

    privacy_manifest_content = <<-PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>35F9.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
    PLIST

    installer.pods_project.targets.each do |target|
        if pods_needing_privacy_manifest.include?(target.name)
            pod_dir = installer.sandbox.pod_dir(target.name)
            privacy_file = pod_dir + "PrivacyInfo.xcprivacy"
            unless privacy_file.exist?
                File.write(privacy_file, privacy_manifest_content)
                puts "✅ Injected PrivacyInfo.xcprivacy into #{target.name}"
            end
            # 将 PrivacyInfo.xcprivacy 添加到 target 的资源构建阶段
            resources_phase = target.build_phases.find { |phase| phase.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }
            if resources_phase.nil?
                resources_phase = target.new_resources_build_phase
            end
            file_ref = installer.pods_project.new_file(privacy_file.to_s)
            unless resources_phase.files_references.include?(file_ref)
                resources_phase.add_file_reference(file_ref)
            end
        end
    end
    installer.pods_project.save
end


abstract_target 'TangSengDaoDaoiOSBase' do

#  pod 'lottie-ios', '~> 2.5.3'
  pod 'Socket.IO-Client-Swift'
  pod 'SSZipArchive', '~> 2.2.3'
  pod 'SocketRocket'
  pod 'Aspects'
  pod 'ReactiveObjC'

  target 'OctoiOS' do
    project 'TangSengDaoDaoiOS.xcodeproj'
    
  use_frameworks!
  # TODO(P5/P7): 下面 4 个 pod 引用 tangtaoit 的个人 GitHub fork。
  # 正式发布前应迁移到 Mininglamp-OSS 组织下的 fork 或使用官方上游。
  pod 'YBImageBrowser/NOSD', :git=>'https://github.com/tangtaoit/YBImageBrowser.git'
  pod 'YYImage/WebP', :git => 'https://github.com/tangtaoit/YYImage.git'
  pod 'AsyncDisplayKit', :git => 'https://github.com/tangtaoit/AsyncDisplayKit.git'
  # librlottie (LGPL) — 透过 SDWebImageLottieCoder 间接依赖，rlottie 引擎是
  # WKLottieStickerCell / WKEmojiStickerCell 真正在用的 Lottie 渲染器。
  # 使用 CocoaPods 官方仓库版本（SDWebImage 维护，源自 Samsung 官方 rlottie），
  # 不再走 tangtaoit 个人 fork，规避供应链风险。
  pod 'librlottie', '~> 0.2.1'
  
  pod 'WuKongIMSDK',  :path => './Modules/WuKongIMiOSSDK'   ## WuKongBase 基础工具包  源码地址 https://github.com/WuKongIM/WuKongIMiOSSDK
#  pod 'WuKongIMSDK',  :path => '../../../wukongIM/iOS/WuKongIMiOSSDK'
#  pod  'WuKongIMSDK', '~> 1.0.2' ## 源码地址 https://github.com/WuKongIM/WuKongIMiOSSDK
  # pod 'Down', :git => 'https://github.com/johnxnguyen/Down.git', :tag => 'v0.11.0'  ## 已替换为 libcmark_gfm
  pod 'libcmark_gfm'  ## Markdown 渲染（纯 C 解析，无 WebKit 依赖）
  pod 'WuKongBase',  :path => './Modules/WuKongBase'   ## WuKongBase 基础工具包
  pod 'WuKongLogin', :path => './Modules/WuKongLogin'  ##  登录模块
  pod 'WuKongContacts', :path => './Modules/WuKongContacts'  ## 联系人模块
  pod 'WuKongDataSource', :path => './Modules/WuKongDataSource'  ## 数据源
# pod 'Bugly'  ## 通过 WuKongBase vendored_frameworks 手动集成

  # 性能监控（仅 Debug 模式）
  pod 'DoraemonKit/Core', '~> 3.1.2', :configurations => ['Debug']
  pod 'DoraemonKit/WithGPS', '~> 3.1.2', :configurations => ['Debug']

  end
  
end


