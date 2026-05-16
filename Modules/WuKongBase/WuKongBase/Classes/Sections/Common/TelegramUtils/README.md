# TelegramUtils

> **⚠️ GPL v2 — License incompatibility under active resolution**

This directory contains display-layer utilities derived from
[Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS),
which is licensed under **GNU GPL v2**.

## Why it exists

The Octo iOS client's message-cell rendering (context menus, animated
stickers, gradient backgrounds, shimmer effects, image browser status
indicators) was built on top of Telegram's `AsyncDisplayKit`-based
node system. These are the components currently in use:

| Component | Used by |
|---|---|
| `ContextUI` / `ContextExtractedContentContainingNode` | `WKMessageCell` (long-press context menu) |
| `RadialStatusNode` | `WKImageBrowser` (loading indicator) |
| `GradientBackgroundNode` | `WKSpaceGateVC` (gradient background) |
| `ShimmerEffect` | `WKStickerImageView` |
| `AnimatedStickerNode` (TelegramAnimatedStickerNode) | `WKMessageStickerCell` (removed P5) |

## Replacement plan

Tracked as **P5-long-term** in the open-source roadmap.

Replacements:
- `ContextUI` → `UIContextMenuInteraction` (iOS 13+)
- `RadialStatusNode` → `UIActivityIndicatorView` or custom CALayer
- `GradientBackgroundNode` → `CAGradientLayer`
- `ShimmerEffect` → `CAGradientLayer` animation

Contributions for any of the above are very welcome — see
[CONTRIBUTING.md](../../../../../../../../../../../CONTRIBUTING.md).

## Do NOT add new dependencies

New code **must not** import from this directory.
See `CLAUDE.md` (repository root) for the enforcement rule.
