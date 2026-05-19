# 工程规范 (AI / 代码评审共同遵守)

## Swizzle / +load 白名单

新增 `+load`、`+initialize` 中的行为修改（`method_exchangeImplementations`、
`class_replaceMethod`、`swizzleInstanceMethodOfClass:` 等），以及对 `NSObject`、
`NSNotificationCenter`、UIKit 基类方法的 swizzle，必须满足：

1. PR 描述声明理由 + 直接消费方（类/方法名）。
2. 提供可关闭开关（宏或启动参数），并在实现文件头部注释"回退到原实现的路径"。
3. 消费方若在 ≥30 天内无任何调用者，swizzle 必须同步移除 —— 不允许"为了将来用"而常驻。
4. 对 `NSNotificationCenter postNotificationName:` 这类高频路径的 swizzle 默认禁止；
   若有刚需，需把 handler 逻辑限定在特定通知名前缀上，且在 Bugly 抓栈归因上做好验证。

已知历史包袱（不要再往里加东西，优先逐步迁出）:

- `Modules/WuKongBase/WuKongBase/Classes/Sections/Common/TelegramUtils/` ——
  **GPL v2 代码**。Display / Utils / AppBundle / GZip / Svg / Markdown 等基础
  子目录仍在编译链中。原本作为消息 cell 长按出菜单核心的
  `ContextGesture` / `ContextControllerSourceNode` /
  `ContextExtractedContentContainingNode` / `TapLongTapOrDoubleTapGestureRecognizer`
  四个文件**已被 Octo 自实现替代**，源码位于
  `Modules/WuKongBase/WuKongBase/Classes/Sections/Common/MessageGesture/`
  （`OctoContextGesture` / `OctoMessageGestureContainerNode` /
  `OctoMessageContentContainingNode` / `OctoTapLongTapOrDoubleTapRecognizer`）。
  cell 通过 `OctoMessageGestureContainerNode` 挂载手势，行为目标对齐：
  beginDelay = 0.12s、左缘 8pt 让位给 interactivePop、
  `shouldRecognizeSimultaneouslyWith UIPanGestureRecognizer = false` 不抢
  tableview 的 pan。老 4 个 GPL 文件已 `git rm`，podspec `exclude_files`
  留护栏防止误恢复。已通过 `WuKongBase.podspec exclude_files` 排除明确不需要的
  子目录（AnimatedStickerNode / ContextUI / ReactionSelectionNode /
  TextSelectionNode / RadialStatusNode / ShimmerEffect / GradientBackground /
  MetalImageView / MediaResources / LegacyComponents / LiMaoMock /
  AnimationCompression / TelegramAnimatedStickerNode）。
  **任何新代码禁止 import TelegramUtils 下的符号**。完整剥离是长期工作。

- `Modules/WuKongBase/WuKongBase/Classes/Vendor/SoundTouch/` ——
  **LGPL v2.1，已在 P5 从编译链中排除**（podspec `exclude_files`）。
  `CWVoiceChangePlayCell` 变声功能已降级为无变调直播，待用 `AVAudioUnitTimePitch` 替换。

## 调试工具的生命周期

仅为开发期排障使用的组件（检测器、日志增强、性能探针），必须：

- 文件头部注释写明「调试用途，上线前禁用」。
- 启动入口放在一个明确的函数里（避免散落在 `application:didFinishLaunching...:`），
  以便一键关闭。
- 发布分支合入前确认该启动调用已被条件编译或注释屏蔽。

参考：`WKANRWatchdog` (已在 `WKApp.m` 中关闭启动调用)。
