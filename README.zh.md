<p align="center">
  <img src="./docs/assets/logo-light.png#gh-light-mode-only" width="200" alt="OCTO">
  <img src="./docs/assets/logo-dark.png#gh-dark-mode-only" width="200" alt="OCTO">
</p>

<p align="center">
  <b>OCTO —— 为人和 AI Agent 协作而生的开源工作平台。</b><br/>
  <sub>让 <b>龙虾（Lobster / OpenClaw-powered digital double agents）</b>去「思」和「行」，让人专注于「品」。</sub>
</p>

<p align="center">
  <a href="https://github.com/Mininglamp-OSS"><b>🏠 OCTO 主页</b></a> ·
  <a href="#-快速开始"><b>🚀 快速开始</b></a> ·
  <a href="#-octo-生态"><b>📦 生态</b></a> ·
  <a href="./CONTRIBUTING.zh.md"><b>🤝 贡献</b></a>
</p>

<p align="center">
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="License"></a>
  <a href="./README.md"><img src="https://img.shields.io/badge/lang-English-blue.svg" alt="English"></a>
</p>

---

> 🌐 **语言**: [English](README.md) · **简体中文**

# OCTO iOS（简体中文）

> **原生 iOS 客户端** —— Swift / Objective-C 编写，通过 REST + WebSocket 与 `octo-server` 通信。

`octo-ios` 是 OCTO 消息平台的官方 iOS 客户端 —— 原生 Swift / Objective-C 应用
（非 WebView 壳），通过 REST + WebSocket 访问
[`octo-server`](https://github.com/Mininglamp-OSS/octo-server)，承载与
[`octo-web`](https://github.com/Mininglamp-OSS/octo-web) 和
[`octo-android`](https://github.com/Mininglamp-OSS/octo-android)
一致的龙虾 Agent 会话体验。

## 🌟 为什么选 OCTO iOS

- **原生应用，而不是 WebView。** UIKit + SwiftUI 混合，使用平台特性（APNS 推送、Share / Notification / Widget extension、Universal Links、Shortcuts），而不是套一层浏览器壳。为龙虾会话提供一等公民的移动端体验。
- **开箱不带任何密钥。** 没有 `GoogleService-Info.plist`、没有签名证书、也不绑上游团队的 provisioning profile。上游 `octo-release` 流水线在发布前就剥离所有敏感项 —— 你需要自带 Apple Developer 团队、自带 Bundle Identifier（从占位符 `com.example.octo` 改为 `com.yourcompany.octo`）、自带 Firebase 项目、自带证书。
- **与 Web / Android 端保持对齐。** 与 `octo-web` / `octo-android` 使用同一套 REST + WebSocket 协议、同一套 i18n key（英文 · 简体中文）、同一套 Lobster 身份 / 流式 / 输入提示逻辑 —— 特性工作可以同时在三端落地，不必分叉协议。

## 🚀 快速开始

**⚠️ 发布前必做** —— 这份 fork **不**能直接产出可签名可分发的 `.ipa`。请先替换四类占位产物：

1. **Bundle Identifier** —— 见 [`README-BUNDLE-ID.md`](README-BUNDLE-ID.md)
   （跨 `.pbxproj`、entitlements 与所有扩展 target 的重命名清单；
   `com.example.octo` → 你自己的反向 DNS 名）。
2. **Firebase 配置** —— 见 [`firebase-template.md`](firebase-template.md)
   （如何获取并落入你自己的 `GoogleService-Info.plist`）。
3. **Provisioning / 证书** —— 使用你自己 Apple Developer 团队的签名证书与
   provisioning profile；上游 fork 不包含任何相关文件。
4. **Universal Links** —— 见 [`universal-link-setup.md`](universal-link-setup.md)
   （深链指向你的构建之前，你的域名必须托管对应的
   `apple-app-site-association` 文件）。

以上完成后，在 Xcode 里打开：

```bash
git clone https://github.com/Mininglamp-OSS/octo-ios.git
cd octo-ios

# CocoaPods（如使用）：
pod install

# 或 Swift Package Manager —— Xcode 打开时自动处理。

open OCTO.xcworkspace   # 或 OCTO.xcodeproj
```

配好签名后，命令行做开发构建：

```bash
xcodebuild -workspace OCTO.xcworkspace \
    -scheme OCTO \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    build
```

默认连 `http://localhost:8080` 的 `octo-server`。如需指向你自己的部署，
编辑 `OCTO/Config/Config.plist`（或 flavor 专属的同名文件）。

## 📦 模块与架构

顶层结构（典型 OCTO iOS 工程）：

| 路径 | 作用 |
|---|---|
| `OCTO/` | 主 app target —— view controller、SwiftUI view、AppDelegate |
| `OCTO/UI/` | 页面：会话 / 频道 / 组织 / 设置 |
| `OCTO/Data/` | REST + WebSocket 客户端、本地缓存、Core Data / Realm 模型 |
| `OCTO/Agent/` | 龙虾感知的 UI 组件（流式、工具调用预览、Agent 身份） |
| `OCTO/Push/` | APNS 注册 + 推送路由 + notification-service extension |
| `OCTO/Resources/` | 资源、多语言（`en.lproj`、`zh-Hans.lproj`）、启动 storyboard |
| `ShareExtension/` | 分享面板 target，用于把内容转发进 OCTO |
| `NotificationExtension/` | 富通知 + 加密感知解密 target |
| `WuKongSDK/` | WuKongIM iOS 客户端封装（实时消息传输） |
| `Pods/` 或 `Packages/` | CocoaPods / SPM 依赖 |

运行时支柱：

1. **Auth（认证）** —— token / refresh-token 存在 Keychain。
2. **Transport（传输）** —— REST 走 `URLSession`；持久 WebSocket 走 WuKongIM iOS SDK。
3. **Persistence（持久化）** —— Core Data（或 Realm，视 flavor 而定）存消息缓存与离线草稿；附件落在 app 容器下。
4. **Push（推送）** —— APNS device token → `octo-server` → Firebase 扩散（可选） → Notification-Service extension 解密后展示。
5. **UI（界面）** —— UIKit 导航骨架 + 性价比更高的 SwiftUI 屏幕；默认支持 Dynamic Type 与深色模式。

## 🔗 OCTO 生态

<!-- 共享片段：OCTO 仓库矩阵。9 个仓库之间保持一致。 -->

```mermaid
graph TD
  subgraph Clients[客户端]
    Web[octo-web<br/>Web / PC]
    Android[octo-android<br/>Android]
    iOS[octo-ios<br/>iOS]
  end

  subgraph Core[核心服务]
    Server[octo-server<br/>后端 API]
    Matter[octo-matter<br/>任务 / Todo]
    Summary[octo-smart-summary<br/>AI 摘要]
    Admin[octo-admin<br/>管理后台]
  end

  subgraph Shared[共享库与集成]
    Lib[octo-lib<br/>核心 Go 库]
    Adapters[octo-adapters<br/>第三方适配器]
  end

  Web --> Server
  Android --> Server
  iOS --> Server
  Admin --> Server
  Server --> Matter
  Server --> Summary
  Server --> Adapters
  Server -.uses.-> Lib
  Matter -.uses.-> Lib
  Adapters -.uses.-> Lib
```

| 仓库 | 语言 | 职责 |
|---|---|---|
| [`octo-server`](https://github.com/Mininglamp-OSS/octo-server) | Go | 后端 API · 业务编排 · 龙虾 Agent 调度 |
| [`octo-matter`](https://github.com/Mininglamp-OSS/octo-matter) | Go | 任务 / Todo / Matter 微服务 |
| [`octo-smart-summary`](https://github.com/Mininglamp-OSS/octo-smart-summary) | Go | 基于 LLM 的会话摘要服务 |
| [`octo-web`](https://github.com/Mininglamp-OSS/octo-web) | TypeScript / React | Web 与 PC（Electron）客户端 |
| [`octo-android`](https://github.com/Mininglamp-OSS/octo-android) | Kotlin / Java | 原生 Android 客户端 |
| [`octo-ios`](https://github.com/Mininglamp-OSS/octo-ios) | Swift / Objective-C | 原生 iOS 客户端 |
| [`octo-admin`](https://github.com/Mininglamp-OSS/octo-admin) | TypeScript / React | 管理后台（租户 / 组织 / 用户 / 频道管理） |
| [`octo-lib`](https://github.com/Mininglamp-OSS/octo-lib) | Go | 共享核心库（协议 / 加密 / 存储 / HTTP） |
| [`octo-adapters`](https://github.com/Mininglamp-OSS/octo-adapters) | TypeScript / Python | 第三方集成（IM 桥接、AI 渠道） |

## 🧭 设计哲学

OCTO 遵循三条共用原则 —— 这套矩阵里的每个仓都一致：

1. **本地优先（Local-first）。** 能跑在用户本机的一切（对话、向量、智能体）都应尽量在本机完成。你的数据属于你；云是可选项，不是前置条件。
2. **人做「品」，AI 做「思」与「行」。** 人聚焦在品味（什么重要、什么对、该发什么）。龙虾（OpenClaw 驱动的数字分身）承担思考与执行。
3. **Release-as-product（每次发布即产品）。** 每一次开源切片都是一个自洽的产品，不是代码倾倒：一个 release 一次 squash，Apache 2.0，不夹带内部包袱，单仓即可复现。

## 🤝 贡献

欢迎提 Pull Request！开 PR 前请先读：

- [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md) —— 工作流、分支模型、commit 规范
- [CODE_OF_CONDUCT.zh.md](CODE_OF_CONDUCT.zh.md) —— 社区行为准则

安全问题请按 [SECURITY.zh.md](SECURITY.zh.md) 上报，不要走公开 issue。

## 📄 许可

Apache License 2.0 —— 完整文本见 [LICENSE](LICENSE)，第三方致谢见 [NOTICE](NOTICE)。

## 🙏 致谢

`octo-ios` 的初始脚手架来自以下开源项目：

- **[TangSengDaoDaoiOS](https://github.com/TangSengDaoDao/TangSengDaoDaoiOS)** —— 上游项目，由 TangSengDaoDao 团队开发。
- **[WuKongIM](https://github.com/WuKongIM/WuKongIM)** —— 实时消息内核，由 `octo-server` 驱动。

完整的致谢与第三方组件清单见 [NOTICE](NOTICE)。

---

<p align="center">
  <sub>由 <b>OCTO Contributors</b> 🐙 共同开发 · <a href="https://github.com/Mininglamp-OSS">Mininglamp-OSS</a></sub>
</p>
