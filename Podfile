# Uncomment the next line to define a global platform for your project
 platform :ios, '14.0'
workspace 'OctoiOS.xcworkspace'

# ─────────────────────────────────────────────────────────────────────────────
# Podfile.lock 协作规范 (PR #32 review 反馈)
# ─────────────────────────────────────────────────────────────────────────────
# 仓库内的 Podfile.lock 反映 **OSS 默认环境** 解析图 (无 OctoConfig.xcconfig,
# 无本地 Bugly.framework)。clean clone 跑 pod install 应与该 lock 完全一致。
#
# 本地有私有配置 (OctoConfig.xcconfig 填了 OCTO_BUGLY_APP_ID_MAIN, 或仓库内
# 放了 Bugly.framework) 时, pod install 会解出含 Bugly 的依赖图并改写
# Podfile.lock —— **此时请不要 commit lock 的改动**, 它只在你本地有意义。
#
# 如需临时切回 OSS 视角验证 (例如想确认 lock 与公开仓库一致), 用 ENV 强制:
#     OCTO_HAS_PRIVATE_CONFIG=0 pod install
# 该 ENV 在 WuKongBase.podspec 里短路掉 Bugly 检测, 让解析图与 OSS 默认一致。
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Monkey-patch: 关掉 CocoaPods "transitive static binary" 检查
# ─────────────────────────────────────────────────────────────────────────────
# 启用 Bugly（腾讯静态 SDK）时这条检查会硬阻断 pod install:
#   [!] target has transitive dependencies that include statically linked binaries
# 这个检查在 use_frameworks!（动态）+ 静态 SDK 组合下永远报错，但实际链接
# 完全可行。社区标准做法是 monkey-patch 关掉，Tencent / Alibaba / Bytedance
# 系 SDK 都这么搞。我们用 static_framework = true 让 WuKongBase 把 Bugly
# 静态吸收进自身，主工程依然 use_frameworks! 动态化其他 Swift 库。
class Pod::Installer::Xcode::TargetValidator
  def verify_no_static_framework_transitive_dependencies; end
end

# ─────────────────────────────────────────────────────────────────────────────
# OctoConfig.xcconfig 解析
# 私有配置（Apple Team ID / Bugly AppKey / IM 服务器等）统一放在
# OctoConfig.xcconfig（gitignored），由本 Podfile 在 post_install 阶段：
#   1. 读出所需变量（如 APPLE_TEAM_ID）赋给 build_settings；
#   2. 把 #include? "../../../OctoConfig.xcconfig" 注入每个 Pods xcconfig，
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

    # ─────────────────────────────────────────────────────────────────────
    # Bugly 动态启用：source of truth 是 WuKongBase.podspec — 它根据
    # OctoConfig.xcconfig 决定是否声明 s.dependency 'Bugly'，或本地放
    # framework。这里直接看 installer 里 Bugly pod 是否进了 target，避免
    # Podfile 自己再 parse 一次配置文件造成判定分叉。
    # ─────────────────────────────────────────────────────────────────────
    bugly_installed_via_pod = installer.pod_targets.any? { |pt| pt.name == 'Bugly' }
    local_bugly_path = File.expand_path('Modules/WuKongBase/WuKongBase/Bugly.framework', __dir__)
    local_bugly_exists = File.exist?(local_bugly_path)
    bugly_enabled = bugly_installed_via_pod || local_bugly_exists
    bugly_source = if local_bugly_exists
                     'local framework'
                   elsif bugly_installed_via_pod
                     'pod Bugly ~> 2.6 (Tencent CDN)'
                   else
                     'n/a'
                   end
    puts "Bugly: #{bugly_enabled ? "ENABLED via #{bugly_source}" : 'DISABLED (未配置 OCTO_BUGLY_APP_ID_MAIN, 也未放 local framework)'}"

    bugly_consumer_targets = %w[WuKongBase]
    aggregate_user_targets = installer.aggregate_targets.map(&:user_targets).flatten.map(&:name)
    installer.pods_project.targets.each do |target|
        next unless bugly_consumer_targets.include?(target.name)
        target.build_configurations.each do |config|
            defs = Array(config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'])
            defs = ['$(inherited)'] if defs.empty?
            defs.reject! { |d| d == 'OCTO_ENABLE_BUGLY=1' }
            defs << 'OCTO_ENABLE_BUGLY=1' if bugly_enabled
            config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = defs
        end
    end

    # ─────────────────────────────────────────────────────────────────────
    # Bugly 静态库防重复链接 (2026-06)
    # Bugly 是腾讯发布的**静态** framework，CocoaPods 看到 s.dependency 'Bugly'
    # 后会**同时**把 -framework "Bugly" 自动写进:
    #   1) WuKongBase pod 自己的 xcconfig (Pods/Target Support Files/WuKongBase/)
    #   2) 主 App 的 aggregate xcconfig (Pods-OctoiOSBase-OctoiOS)
    # 二者都链同一份静态库 → 运行时 objc[] 报
    #   "Class Bugly is implemented in both WuKongBase.framework and Octo.debug.dylib"
    # 包体积也虚胖一份。
    # 策略: 只让主 App 链一份, WuKongBase 改用 -Wl,-undefined,dynamic_lookup
    # (在 WuKongBase.podspec 的 pod_target_xcconfig 里), runtime 由 Obj-C
    # flat namespace 自动指向主 App 那份。这里负责把 CocoaPods 自动写入的
    # `-framework "Bugly"` 从 WuKongBase 的 xcconfig 里物理擦掉, 否则
    # podspec 的 OTHER_LDFLAGS 设置会被 CocoaPods 自动行覆盖。
    # 幂等: 每次 pod install 重新生成, 不会累积。
    # ─────────────────────────────────────────────────────────────────────
    if bugly_enabled
        wukongbase_xcconfigs = Dir.glob(File.join(__dir__,
            'Pods/Target Support Files/WuKongBase/WuKongBase.*.xcconfig'))
        wukongbase_xcconfigs.each do |xcconfig_path|
            content = File.read(xcconfig_path)
            # 用空格兜底 (前后都可能是空格), 一次性把 -framework "Bugly" 抠掉
            new_content = content.gsub(/\s*-framework\s+"Bugly"/, '')
            if new_content != content
                File.write(xcconfig_path, new_content)
                puts "🧹 Stripped -framework \"Bugly\" from #{File.basename(xcconfig_path)} (防 duplicate class)"
            end
        end
    end
    # 主 App target (OctoiOS) 的 OCTO_ENABLE_BUGLY=1 宏：注入到 Pods 聚合
    # xcconfig（每次 pod install 重新生成），不再写主工程的 pbxproj —— 那样
    # 会让 pbxproj 永久带着这个宏，clean clone 没装 Bugly 就编译挂
    # (PR #125 round 5 review 🟡)
    aggregate_xcconfigs = Dir.glob(File.join(__dir__,
        'Pods/Target Support Files/Pods-OctoiOSBase-OctoiOS/*.xcconfig'))
    aggregate_xcconfigs.each do |xcconfig_path|
        content = File.read(xcconfig_path)
        # 先把可能残留的宏抹掉（无论开关状态，幂等）
        content = content.gsub(/\s+OCTO_ENABLE_BUGLY=1\b/, '')
        if bugly_enabled
            if content =~ /^GCC_PREPROCESSOR_DEFINITIONS\s*=\s*(.*)$/
                content = content.sub(/^GCC_PREPROCESSOR_DEFINITIONS\s*=\s*(.*)$/) do
                    "GCC_PREPROCESSOR_DEFINITIONS = #{$1.rstrip} OCTO_ENABLE_BUGLY=1"
                end
            else
                content += "\nGCC_PREPROCESSOR_DEFINITIONS = $(inherited) OCTO_ENABLE_BUGLY=1\n"
            end
        end
        File.write(xcconfig_path, content)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Bugly 主 App 强制 link (2026-06)
    # WuKongBase 用 -Wl,-undefined,dynamic_lookup 跳过 link-time 检查 (见
    # WuKongBase.podspec)，期望主 App 二进制里有 Bugly classes，runtime 由
    # Obj-C flat namespace 把 WuKongBase 那侧的悬空 _OBJC_CLASS_$_Bugly 等
    # 符号解到主 App。CocoaPods 默认给主 App aggregate xcconfig 加的
    # `-ObjC -framework "Bugly"` 在 Debug 模式靠 -ObjC 启发式把 ObjC class 拉
    # 进二进制能 work，但 Release archive 时 LTO + dead-code strip 可能漏掉
    # 静态 framework 的 class，TestFlight 包启动时 dyld 报
    # "symbol not found in flat namespace '_OBJC_CLASS_$_Bugly'" 直接 abort
    # (build 64 现网命中)。改用 -force_load 把 Bugly framework 整个 .o 强制
    # 吸进主 App 二进制，绕过 -ObjC 启发式，dead strip 触不到。
    #
    # 路径分两种 Bugly 集成方式：
    #   * pod 模式 (OCTO_BUGLY_APP_ID_MAIN 配了): $(PODS_ROOT)/Bugly/Bugly.framework/Bugly
    #   * local framework 模式 (用户手动放 .framework): $(SRCROOT)/Modules/WuKongBase/WuKongBase/Bugly.framework/Bugly
    #     主 App aggregate xcconfig 里 $(SRCROOT) = 项目根, 与 podspec 里
    #     File.expand_path('Modules/WuKongBase/...', __dir__) 一致.
    # 写错路径 -force_load 会让 ld 报 file not found, archive 直接挂.
    #
    # 注意 1: -force_load 和 -framework "Bugly" 同时存在会把 Bugly 静态库
    # load 两遍 → 420 duplicate symbol。所以一定要同步把 -framework "Bugly"
    # 抠掉，只留 -force_load 这一份。
    # 注意 2: 还要把主 App 的 STRIP_STYLE 从默认 "all" 改成 "debugging" ——
    # 否则 archive 阶段 strip 会把 Bugly classes 的 external symbol (例如
    # _OBJC_CLASS_$_Bugly) 一并 strip 掉, WuKongBase 在 dyld load 时通过
    # flat namespace 查找仍然落空, 跟修之前 (build 64) 同款 abort。
    # `debugging` 只 strip 调试符号, external symbols 保留 → dyld 能解到。
    # xcodebuild build 默认 DEPLOYMENT_POSTPROCESSING=NO 所以不 strip,
    # archive 默认开 strip → 必须显式覆盖。
    # 幂等: 用专门的 marker comment (不是字符串 match force_load_flag),
    # 这样以后改路径不会漏处理已 patched 的 xcconfig.
    # ─────────────────────────────────────────────────────────────────────
    if bugly_enabled
        bugly_binary_path = if bugly_installed_via_pod
                                '$(PODS_ROOT)/Bugly/Bugly.framework/Bugly'
                            else
                                # local framework 模式: __dir__ = 项目根, 用 $(SRCROOT)
                                # 主 App SRCROOT = .xcodeproj 同级 = 项目根
                                '$(SRCROOT)/Modules/WuKongBase/WuKongBase/Bugly.framework/Bugly'
                            end
        force_load_flag = "-force_load \"#{bugly_binary_path}\""
        bugly_marker = '// bugly-force-load-injected (Podfile post_install)'
        aggregate_xcconfigs.each do |xcconfig_path|
            content = File.read(xcconfig_path)
            already_patched = content.include?(bugly_marker)
            unless already_patched
                changed = false
                # 删掉 CocoaPods 自动写入的 -framework "Bugly"，否则跟 -force_load
                # 串联 link 会把 Bugly 静态库吸两遍, ld 报 duplicate symbol.
                if content =~ /\s*-framework\s+"Bugly"/
                    content = content.gsub(/\s*-framework\s+"Bugly"/, '')
                    changed = true
                end
                if content =~ /^OTHER_LDFLAGS\s*=\s*(.*)$/
                    content = content.sub(/^OTHER_LDFLAGS\s*=\s*(.*)$/) do
                        "OTHER_LDFLAGS = #{$1.rstrip} #{force_load_flag}"
                    end
                else
                    content += "\nOTHER_LDFLAGS = $(inherited) #{force_load_flag}\n"
                end
                # 强制保留 external symbols（含 _OBJC_CLASS_$_Bugly 等），
                # 否则 archive 时 STRIP_STYLE=all 会把 force_load 进来的符号 strip 掉。
                if content =~ /^STRIP_STYLE\s*=.*$/
                    content = content.sub(/^STRIP_STYLE\s*=.*$/, 'STRIP_STYLE = debugging')
                else
                    content += "\nSTRIP_STYLE = debugging\n"
                end
                # 写 marker 在文件末尾, 下次 pod install 通过它检测幂等.
                content += "\n#{bugly_marker} source=#{bugly_source}\n"
                File.write(xcconfig_path, content)
                puts "🔗 Patched #{File.basename(xcconfig_path)}: force_load=#{bugly_binary_path}, STRIP_STYLE=debugging (主 App 强制 link Bugly, source=#{bugly_source}, swapped_framework=#{changed})"
            end
        end
    end

    # 把 OctoConfig.xcconfig 软引用注入到每一个 Pods xcconfig。
    # 路径深度：xcconfig 位于 Pods/Target Support Files/<Pod>/<Pod>.<config>.xcconfig，
    # 距离仓库根 (OctoConfig.xcconfig) 需要回退 3 层。`#include?` 静默失败，
    # 路径写错时不会报错，但变量也不会注入 —— 历史上写成 `../../` 因此失效，
    # 主工程依然吃 pbxproj 里残留的硬编码 DEVELOPMENT_TEAM。
    octo_include_line = "#include? \"../../../OctoConfig.xcconfig\"\n"
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
    # ─────────────────────────────────────────────────────────────────────
    # SDWebImage 5.9.5 SDImageIOAnimatedCoder.createFrameAtIndex 缺 nil guard
    # (Bugly 现网 SIGABRT, 栈顶 -[SDAnimatedImagePlayer displayDidRefresh:]
    #  → animatedImageFrameAtIndex → createFrameAtIndex → UIKitCore
    #  NSInvalidArgumentException)：thumbnail 路径下
    #  CGImageCreateScaled(SDImageCoderHelper.m:310/315/318) 会因为
    #  vImageBuffer_InitWithCGImage 失败 / malloc 失败 / vImageScale_ARGB8888
    #  失败而返回 NULL，但 createFrameAtIndex 把它直接喂给
    #  [[UIImage alloc] initWithCGImage:NULL ...]，UIKit 抛
    #  NSInvalidArgumentException，CADisplayLink 回调里没人 catch → SIGABRT。
    #  上游 5.10+ 重构了这块；项目暂 pin 5.9.5，本地补一行 nil 早返回。
    #  幂等：用 marker 注释探测，已 patch 不重复注入。
    # ─────────────────────────────────────────────────────────────────────
    sd_coder_path = File.join(__dir__, 'Pods/SDWebImage/SDWebImage/Core/SDImageIOAnimatedCoder.m')
    sd_coder_marker = '// octo-nil-imageref-guard (Podfile post_install)'
    if File.exist?(sd_coder_path)
        sd_content = File.read(sd_coder_path)
        unless sd_content.include?(sd_coder_marker)
            # 锚点：紧跟 thumbnail post-process 收尾的两层 } 之后、平台分支之前
            anchor = "#if SD_UIKIT || SD_WATCH\n    UIImageOrientation imageOrientation = [SDImageCoderHelper imageOrientationFromEXIFOrientation:exifOrientation];"
            inject = "if (!imageRef) {\n        return nil;\n    } #{sd_coder_marker}\n    #if SD_UIKIT || SD_WATCH\n    UIImageOrientation imageOrientation = [SDImageCoderHelper imageOrientationFromEXIFOrientation:exifOrientation];"
            new_sd = sd_content.sub(anchor, inject)
            if new_sd != sd_content
                # CocoaPods 1.16+ 默认把 pod 源装成 0444 read-only, 直接 File.write 报 EACCES
                File.chmod(0644, sd_coder_path)
                File.write(sd_coder_path, new_sd)
                File.chmod(0444, sd_coder_path)
                puts "🛡️  Patched SDImageIOAnimatedCoder.m: nil-imageRef guard before initWithCGImage"
            else
                puts "⚠️  SDImageIOAnimatedCoder.m: anchor not found, nil-imageRef guard NOT applied (检查上游版本是否变了)"
            end
        end
    end

    installer.pods_project.save
end


abstract_target 'OctoiOSBase' do

#  pod 'lottie-ios', '~> 2.5.3'
  pod 'Socket.IO-Client-Swift'
  pod 'SSZipArchive', '~> 2.2.3'
  pod 'SocketRocket'
  pod 'Aspects'
  pod 'ReactiveObjC'

  target 'OctoiOS' do
    project 'OctoiOS.xcodeproj'
    
  use_frameworks!
  # ─────────────────────────────────────────────────────────────────────
  # 下面 3 个 pod 引用 tangtaoit (TangSengDaoDao 原作者) 的个人 GitHub fork。
  # 这些 fork 与上游主线有本仓库依赖的 patch（NOSD / WebP subspec / iOS 14
  # 兼容性 fix）, 切回官方上游会缺 patch 编译失败。
  #
  # 已知供应链风险（PR #121 round 4 review 🟡）:
  #   - tangtaoit 帐号若关停 / 仓库改名 → pod install 立即失败
  #   - HEAD-of-master 不锁定 → 上游强推可能改变行为
  #
  # 缓解：每个依赖 `:commit` 锁到具体 SHA, 屏蔽 HEAD 漂移。彻底解决方案
  # （fork 到 Mininglamp-OSS 组织 或 迁移上游官方版）放在 OSS release
  # 之后的 P9 工作, 进度跟踪 issue # TBD。
  # ─────────────────────────────────────────────────────────────────────
  pod 'YBImageBrowser/NOSD', :git => 'https://github.com/tangtaoit/YBImageBrowser.git', :commit => '9e888bf25f8774f9b084ba3d26d5794cb68aeb0c'
  pod 'YYImage/WebP',        :git => 'https://github.com/tangtaoit/YYImage.git',        :commit => 'be7dc29bbd79153ea03c5018ee2ab2512a16f3fd'
  pod 'AsyncDisplayKit',     :git => 'https://github.com/tangtaoit/AsyncDisplayKit.git', :commit => '3f2a0b8f5069ddefd53cf4796da22eec105c5c7c'
  # librlottie (MIT) — 透过 SDWebImageLottieCoder 间接依赖，rlottie 引擎是
  # WKLottieStickerCell / WKEmojiStickerCell 真正在用的 Lottie 渲染器。
  # 使用 CocoaPods 官方仓库版本（SDWebImage 维护，源自 Samsung 官方 rlottie，
  # 自 2020 年起授权为 MIT），避免走 tangtaoit 个人 fork 的供应链风险。
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


