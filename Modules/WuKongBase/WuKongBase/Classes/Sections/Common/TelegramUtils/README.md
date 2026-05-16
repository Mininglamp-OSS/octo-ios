# TelegramUtils

> **⚠️ GPL v2 — 已从编译链整体排除（P5 完成）**

这个目录包含派生自 [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS)
的显示层工具代码，许可证为 **GNU GPL v2**。

## 当前状态

✅ **本目录已通过 WuKongBase.podspec 的 `exclude_files` 从编译链中完全排除**。
保留源文件仅为维持 GPL v2 归属声明（满足 §4(b)(d) 修改记录要求）。

P5 阶段完成了所有外部消费组件的原生替换：

| 原 TelegramUtils 组件 | 替换为 | 位置 |
|---|---|---|
| `ContextExtractedContentContainingNode` | `WKContentContainerNode` | `Sections/Messages/` |
| `ContextControllerSourceNode` | `WKGestureContainerNode` | `Sections/Messages/` |
| `RadialStatusNode` | `WKRadialProgressView` | `Sections/Common/Component/` |
| `StickerShimmerEffectNode` | `WKShimmerView` | `Sections/Common/Component/` |
| `GradientBackgroundNode.generatePreview` | CoreGraphics CGGradient | `GenerateImageUtils.swift` |
| `AnimatedStickerNode` (librlottie) | 已删除（消费方为死代码） | — |
| `ContextController` (长按菜单) | 自定义 UIKit 实现 `showInlineMenuForCell` | `WKConversationContextImpl.m` |

## 不要做的事

- **不要新增任何 `#import` 引用本目录下的文件** —— CLAUDE.md 中有相关规范
- 不要删除本目录或里面的 LICENSE 文件 —— 这是 GPL v2 归属义务要求
- 如果发现项目里有任何残留对本目录符号的引用，意味着 podspec exclude_files
  没生效或者编译会失败，应立刻报告

## 已删除/排除的相关项

- `librlottie` pod 依赖（LGPL）— 仅 `AnimatedStickerNode/` 使用，随排除
- Facebook POP（BSD+Patents）— 仅 `RadialStatusNode/` 使用，随排除
- nanosvg（zlib）— 仅 `Svg/` 使用，随排除

