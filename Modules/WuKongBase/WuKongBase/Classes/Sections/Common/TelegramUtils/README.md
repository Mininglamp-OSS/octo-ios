# TelegramUtils

> **⚠️ GPL v2 — 部分子目录仍在编译链中**

此目录包含派生自 [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS)
的代码，许可证 **GNU GPL v2**。

## 当前状态

### 仍在编译的子目录（active dependency）

被 `WKMessageCell` 等核心消息 cell 使用：

- `Display/` — `ContextControllerSourceNode` / `ContextExtractedContentContainingNode`
  / `TapLongTapOrDoubleTapGestureRecognizer` / `ContextGesture` 等基础节点和手势
- `Utils/`、`AppBundle/`、`SwiftSignalKit/`、`ObjCRuntimeUtils/`、`UIKitRuntimeUtils/`
  — Display 的支撑模块
- `Markdown/`、`GZip/`、`Svg/`、`ManagedFile/`、`AnimatedCountLabelNode/`、
  `AnimatedNavigationStripeNode/`、`TelegramUIPreferences/`、`Others/`、`YuvConversion/`

> 之前尝试用原生 UIKit 实现替代手势相关节点（`UILongPressGestureRecognizer` + `UITapGestureRecognizer`），
> 但与 `UINavigationController.interactivePopGestureRecognizer` 和 tableview 的
> 滚动手势会发生冲突，导致聊天页面右滑返回失效、tableview 滚动失效。
> Telegram 的 `ContextGesture` 是自定义 UIGestureRecognizer 子类，带 `beginDelay = 0.12`
> 和内部状态机，专门处理这些协作场景，难以用标准 UIKit 简单替代。

### 已排除的子目录（podspec exclude_files）

通过 `WuKongBase.podspec` 排除编译：

- `AnimatedStickerNode/`、`TelegramAnimatedStickerNode/`、`AnimationCompression/`
  —— 依赖已移除的 librlottie（LGPL）
- `ContextUI/` —— 上层 context 菜单 UI，被自定义 UIKit `showInlineMenuForCell` 替代
- `ReactionSelectionNode/`、`TextSelectionNode/`、`LiMaoMock/` —— 依赖上述已排除模块
- `RadialStatusNode/` —— 依赖 POP 动画引擎
- `ShimmerEffect/`、`GradientBackground/`、`MetalImageView/`、`MediaResources/`、
  `LegacyComponents/` —— 当前无外部消费方

## P5 已完成的原生替换

| 已替换 | 原 TelegramUtils 组件 | 替换为 |
|---|---|---|
| 长按菜单系统 | `ContextController` | 自定义 `showInlineMenuForCell` (`WKConversationContextImpl.m`) |
| 壁纸预览渲染 | `GradientBackgroundNode.generatePreview` | CoreGraphics `CGGradient` (`GenerateImageUtils.swift`) |
| 死代码 lottie sticker | `AnimatedStickerNode` (基于 librlottie) | 删除（消费方 `WKAnimatedStickerNode` / `WKMessageStickerCell` 未注册） |

## 不要做的事

- 不要新增任何 `#import` 引用本目录下的文件
  —— CLAUDE.md 中有相关规范
- 不要删除本目录或其中的 LICENSE 文件 —— GPL v2 归属义务要求

## 长期工作

完整剥离 Telegram 依赖需要重写 `ContextGesture` 等定制手势状态机，并替换 Display
里被使用的所有节点类型。属于长期重构工作，欢迎社区贡献。


