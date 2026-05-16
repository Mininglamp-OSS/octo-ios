# 贡献 OCTO iOS（简体中文）

感谢你有兴趣贡献 OCTO iOS！🐙 我们欢迎任何规模的贡献。

> 🌐 **语言**: [English](CONTRIBUTING.md) · **简体中文**

## 开始之前

1. **Fork** 仓库，并从 `main` 切出你的分支
2. **安装依赖** —— 见 [README](README.zh.md#-快速开始)（`pod install`、`OctoConfig.xcconfig`）
3. **进行修改** —— 遵循既有代码风格，注意下方的约束
4. **真机回归** —— 涉及推送、手势、聊天 UI 的改动必须真机测试，模拟器会掩盖回归
5. **更新文档** —— 行为变化时同步 README / 模块 README
6. **提交 PR** —— 说明改了什么、为什么改，关联相关 issue

## 开发流程

- 所有修改通过 Pull Request 合入 `develop`（release PR 走 `main`，详见 [RELEASE.md](RELEASE.md)）
- PR 需至少 1 位 maintainer approve
- `develop → main` 的 release PR 用 **merge commit**（保留 feature 历史）；feature PR 合入 `develop` 用 **squash merge**
- 当前无 CI（欢迎贡献）。在 CI 到位前，请在本地完成构建 + 冒烟测试后再申请 review

## 提交 PR 前的自检

- [ ] **Debug + Release** 两种 configuration 都能编译
- [ ] 涉及推送、后台、手势、聊天 UI 的改动做了**真机回归**
- [ ] **深色和浅色**模式都验过
- [ ] 没有新增 `NSLog` 打印 token / 密码 / 完整 HTTP headers / APNs `userInfo`（如需调试请用 `WKLog*` 宏）
- [ ] 没有误提交本地配置（AppKey、Team ID、服务器地址 —— 全部应放在 gitignored 的 `OctoConfig.xcconfig`）
- [ ] 没有新增 `import` GPL / LGPL 代码（见下方"许可证边界"）

## Commit 规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```
feat(chat): 增加按会话自定义 Lobster Prompt
fix(contacts): 切换空间时联系人重复修复
docs: 完善 Universal Links 配置说明
chore(deps): SDWebImage 升级到 5.10
```

`scope` 可选但建议加 —— 常见 scope: `chat` / `contacts` / `login` /
`imsdk` / `push` / `aisummary` / `space` / `theme`。

## PR 描述

- 说明**改了什么**、**为什么改**
- 关联 Issue（如 `Fixes #123`）
- UI 变化请附截图 / 录屏（深浅色如有差异都附）
- **PR 描述请用英文** —— 方便全球社区阅读历史

## 代码风格

- **Objective-C**：4 空格缩进，无 tab。一个文件一个类。公开 API 在 `*.h` 写注释。
- **Swift**：SwiftFormat / SwiftLint 默认规则（配置待补，在那之前请参考周围代码风格）
- **类前缀**：`WK*` 是 `WuKong*` 模块的历史前缀（沿用上游 WuKongIM SDK，遵循 MIT 协议保留 —— 见 [LICENSE](LICENSE) 说明）。主 App `Octo/` target 里的新顶层类可使用其他合适的前缀
- **资源命名**：snake_case

## 许可证边界

本仓库包含多种许可证的代码，请勿混淆边界：

- **主 App**（`Octo/` 及扩展）和我们新写的代码 → **Apache 2.0**
- **`WuKong*` 模块** → **MIT**（上游 WuKongIM SDK）。**不要修改其许可证或删除原始署名**
- **`WuKongBase/.../TelegramUtils/`** 中部分代码 → **GPL v2**。新代码**禁止** `#import` 此目录下的符号。
  详见 [`TelegramUtils/README.md`](Modules/WuKongBase/WuKongBase/Classes/Sections/Common/TelegramUtils/README.md)。

工程层面更多约束见 [CLAUDE.md](CLAUDE.md)（swizzle 白名单、调试工具生命周期等）。

## 报告 Bug

用 GitHub Issue 的 **Bug Report** 模板（如已配置），或自行包含：

- 期望行为 vs 实际行为
- 复现步骤（聊天相关请说明：1v1 / 群、消息类型等前提）
- 环境：iOS 版本、机型、App 构建号
- 日志 / 截图 / 录屏（脱敏后）

**安全敏感问题**请按 [SECURITY.zh.md](SECURITY.zh.md) 上报，**不要**走公开 issue。

## 功能建议

用 GitHub Issue 的 **Feature Request** 模板。说明使用场景以及现有功能为何不够用。
较大功能（≥ ~200 行 / 改公共 API / 影响架构）请先开 **RFC issue** 对齐方向，
再花时间实现。

## License

提交贡献即视为你同意：主 App 新代码以本项目的
[Apache License 2.0](LICENSE) 发布；对 MIT / GPL 部分的修改则遵循对应上游许可证。

## 有问题？

- 开 [GitHub Discussion](https://github.com/orgs/Mininglamp-OSS/discussions)
- 浏览 [OCTO 主页](https://github.com/Mininglamp-OSS) 看完整生态

感谢你一起让 OCTO iOS 变得更好！🚀
