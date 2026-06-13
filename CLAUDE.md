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

- **TelegramUtils** (`Sections/Common/TelegramUtils/`) ——
  2026-05 已整体物理删除（GPL v2，原 25 个子目录 / 270+ 文件）。替代方案：
  - 长按出菜单：`ContextGesture` / `ContextControllerSourceNode` /
    `ContextExtractedContentContainingNode` / `TapLongTapOrDoubleTapGestureRecognizer`
    → `Sections/Common/MessageGesture/` 下 Octo 自实现
    （`OctoContextGesture` / `OctoMessageGestureContainerNode` /
    `OctoMessageContentContainingNode` / `OctoTapLongTapOrDoubleTapRecognizer`）。
    行为目标对齐：beginDelay = 0.12s、左缘 8pt 让位给 interactivePop、
    `shouldRecognizeSimultaneouslyWith UIPanGestureRecognizer = false` 不抢
    tableview 的 pan。
  - 贴纸 shimmer：`StickerShimmerEffectNode`
    → `Sections/Common/Component/WKShimmerView`。
  - 其余 (Display / SwiftSignalKit / UIKitRuntimeUtils / ObjCRuntimeUtils /
    AppBundle / AnimatedCount* / AnimatedNav* / Markdown / Utils / Svg /
    YuvConversion / TelegramUIPreferences / Others / ManagedFile / GZip /
    ContextUI / ReactionSelectionNode / TextSelectionNode / RadialStatusNode /
    GradientBackground / MetalImageView / MediaResources / LegacyComponents /
    LiMaoMock / AnimationCompression / AnimatedStickerNode /
    TelegramAnimatedStickerNode)：深度审计后确认全部 0 外部消费方 +
    0 动态查找，是历史死代码，直接 git rm 移除。
  **任何新代码禁止 import 不存在的 TelegramUtils 符号**。

- **SoundTouch** (`Vendor/SoundTouch/`) ——
  2026-05 已物理删除（LGPL v2.1）。消费链
  (`CWVoiceChangePlayCell.mm` / `CWVoiceChangePlayView` / `CWChangeVoiceView` /
  `WKVoicePanel.m`) 早先已 stub 为 no-op，0 `#include "SoundTouch.h"` 残留。
  CW* 声纹录制/播放 UI 仍在用，只是变声 pitch shift 功能下线，
  **待用 `AVAudioUnitTimePitch` 重新实现变声**。

- **LegacyComponents** (`Vendor/LegacyComponents/`, POP 系列) ——
  2026-05 已物理删除。0 消费方，是历史遗留死代码。

## 调试工具的生命周期

仅为开发期排障使用的组件（检测器、日志增强、性能探针），必须：

- 文件头部注释写明「调试用途，上线前禁用」。
- 启动入口放在一个明确的函数里（避免散落在 `application:didFinishLaunching...:`），
  以便一键关闭。
- 发布分支合入前确认该启动调用已被条件编译或注释屏蔽。

参考：`WKANRWatchdog` (调试期完成使命, 2026-06 已整体物理删除)。
