#
# OctoContext —— 上下文 tab 模块
#
# 承载"智能总结"等基于 IM 上下文的 AI 能力。与 WuKongContacts(已弃用,本 tab
# 早期挂的就是它) 同级,但前缀改为 Octo* 以与新模块命名风格对齐。
#

Pod::Spec.new do |s|
  s.name             = 'OctoContext'
  s.version          = '0.1.0'
  s.summary          = 'Octo 上下文 tab —— 智能总结等基于 IM 上下文的 AI 能力'
  s.description      = <<-DESC
                        Octo 上下文 tab 模块。包含智能总结(SummaryList / Create /
                        Detail / Edit / Confirm 等)和未来其他基于 IM 上下文的 AI
                        能力。后端契约对齐 octo-web/packages/dmworksummary。
                       DESC
  s.homepage         = 'https://github.com/MININGLAMP-Technology/octo-ios'
  s.license          = { :type => 'Apache-2.0' }
  s.author           = { 'octo' => 'octo@mininglamp.com' }
  s.source           = { :git => 'https://github.com/MININGLAMP-Technology/octo-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.0'
  s.resource_bundles = {
    'OctoContext_images' => ['OctoContext/Assets/Images.xcassets']
  }
  s.resources = ['OctoContext/Assets/Lang']

  s.source_files = 'OctoContext/Classes/**/*'
  s.dependency 'WuKongBase'
  s.dependency 'Masonry'
  s.dependency 'WuKongIMSDK'
  s.dependency 'AFNetworking'
  s.dependency 'SDWebImage'
  s.dependency 'MJRefresh'
end
