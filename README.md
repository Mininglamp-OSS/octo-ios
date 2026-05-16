# Octo iOS

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Platform iOS 14.0+](https://img.shields.io/badge/Platform-iOS%2014.0%2B-lightgrey.svg)]()
[![Language Objective-C / Swift](https://img.shields.io/badge/Lang-ObjC%20%2F%20Swift-orange.svg)]()

> 基于 [WuKongIM](https://github.com/WuKongIM/WuKongIM) 协议的开源即时通讯客户端（iOS）。

Octo 是一个可独立部署的 IM 应用基线。包含一对一聊天、群聊、多空间（Space）、AI 助手集成、自定义消息类型扩展等核心能力，适合作为企业内部 IM 自建、技术调研、二次开发的起点。配套后端见 [Mininglamp-OSS/octo-server](https://github.com/Mininglamp-OSS/octo-server)。

---

## 截图

| 会话列表 | 通讯录 | 个人中心 |
|---|---|---|
| ![会话列表](docs/screenshots/01-conversation-list.png) | ![通讯录](docs/screenshots/02-contacts.png) | ![个人中心](docs/screenshots/03-profile.png) |

---

## 特性

**核心通讯**
- 一对一聊天 / 群聊 / 频道
- 多空间（Space）切换、子区（Topic）讨论
- 消息漫游、阅读回执、撤回、转发、合并转发、全文搜索
- 端到端通知：APNs + 本地通知 + 离线推送 + 子区精准提醒

**消息类型**
- 文本（含 Markdown / 实名认证徽章 / @SpaceName 跨空间昵称）
- 图片 / 文件 / 短视频 / 语音 / 位置
- 表情、贴纸（含 Lottie）
- 卡片消息（自定义内容类型可扩展）
- 阅后即焚

**集成能力**
- AI 助手：一键群聊总结、AI Bot 对话、自定义提示词
- 联系人、组织架构、实名认证体系
- WebView Bridge（JS ↔ Native 双向调用）
- 第三方分享扩展（系统分享菜单接入）

**适配**
- 深浅色主题、动态字体、无障碍
- iPhone / iPad

---

## 开始

### 环境要求

| 项 | 版本 |
|---|---|
| macOS | 14.0+ |
| Xcode | 15.0+ |
| iOS Deployment Target | 14.0+ |
| CocoaPods | 1.14+ |
| Ruby | 3.0+（CocoaPods 依赖） |

### 快速运行

```bash
# 1. 克隆
git clone <repo-url> octo-ios && cd octo-ios

# 2. 配置（必须）
cp OctoConfig.xcconfig.template OctoConfig.xcconfig
# 编辑 OctoConfig.xcconfig，至少填入：
#   APPLE_TEAM_ID         — Apple 开发者 Team ID
#   OCTO_IM_DEFAULT_HOST  — 你部署的 octo-server 地址（host，不含协议）

# 3. 安装依赖
pod install

# 4. 打开工作区
open OctoiOS.xcworkspace

# 5. 在 Xcode 选择 OctoiOS scheme + 模拟器/真机，⌘R
```

### 配置项详解

所有运行时敏感配置都收口到根目录的 `OctoConfig.xcconfig`（gitignored）。
模板见 [`OctoConfig.xcconfig.template`](OctoConfig.xcconfig.template)，主要字段：

| 字段 | 必填 | 说明 |
|---|---|---|
| `APPLE_TEAM_ID` | ✅ | 自动签名所需 |
| `OCTO_IM_DEFAULT_HOST` | ✅ | IM 网关 host |
| `OCTO_IM_DEFAULT_LABEL` |  | 服务器显示名 |
| `OCTO_URL_SCHEME` |  | 深链 URL scheme（默认 `octo`） |
| `OCTO_ASSOCIATED_DOMAIN` |  | Universal Link 域名 |
| `OCTO_BUGLY_APP_ID_MAIN` |  | 腾讯 Bugly 崩溃统计（可选，详见下方） |
| `OCTO_BUGLY_APP_ID_SDK` |  | 同上，SDK 通道 |

### 可选集成

#### Bugly 崩溃统计（默认禁用）

Bugly 是腾讯闭源 SDK，开源版默认不附带 framework。需要时：

1. 在 https://bugly.qq.com 注册并下载 iOS SDK
2. 把 `Bugly.framework` 放到 `Modules/WuKongBase/WuKongBase/Bugly.framework/`
3. `OctoConfig.xcconfig` 填入 `OCTO_BUGLY_APP_ID_MAIN`
4. 重新 `pod install` —— 自动启用编译

`pod install` 会输出 `Bugly: ENABLED / DISABLED` 状态。

#### Universal Links

见 [`docs/universal-link-setup.md`](docs/universal-link-setup.md)。

---

## 项目结构

```
.
├── Octo/                       # 主 App target（AppDelegate / 装配）
├── ShareExtension/             # 系统分享扩展
├── NotificationService/        # 推送通知服务扩展
├── NotificationContent/        # 通知内容扩展
├── Modules/                    # 业务模块（CocoaPods local pods）
│   ├── WuKongIMiOSSDK/         # IM 协议 SDK（连接管理、消息收发、本地 DB）
│   ├── WuKongBase/             # 基础组件（聊天 UI、会话列表、通用工具）
│   ├── WuKongLogin/            # 登录、第三方登录、注册
│   ├── WuKongContacts/         # 联系人、群组、空间
│   └── WuKongDataSource/       # 数据源抽象层
├── Vendor/                     # 第三方组件
├── docs/                       # 文档与截图
├── OctoConfig.xcconfig.template # 配置模板（实际配置 gitignored）
├── Podfile
├── LICENSE                     # Apache 2.0
├── NOTICE                      # 第三方组件归属
├── README.md
└── CONTRIBUTING.md
```

> `WuKong*` 命名沿用上游 [WuKongIM](https://github.com/WuKongIM)（MIT 协议）。模块仍以 MIT 发布，没有重命名。

---

## 架构概述

```
┌──────────────────────────────────────────────────────┐
│                     Octo (App)                       │
│           AppDelegate / 推送注册 / 模块装配           │
└────────────────────────┬─────────────────────────────┘
                         │
        ┌────────────────┼─────────────────┐
        ▼                ▼                 ▼
   ┌──────────┐    ┌────────────┐    ┌─────────────┐
   │WuKongBase│◀──▶│WuKongLogin │    │WuKongContacts│
   │ 聊天 UI  │    │ 登录/注册  │    │ 通讯录/群组 │
   │ 会话列表 │    └────────────┘    └─────────────┘
   │ 通用工具 │
   └─────┬────┘
         │
         ▼
   ┌──────────────────┐
   │ WuKongIMiOSSDK   │  ←→  octo-server 网关
   │ 消息收发 / 同步  │      （CocoaAsyncSocket 长连接）
   │ 本地 SQLite      │
   └──────────────────┘
```

- **协议层 `WuKongIMiOSSDK`**：连接管理、心跳、消息序列化、本地 SQLite（FMDB / SQLCipher）
- **业务层 `WuKongBase`**：消息 cell 体系、聊天页、会话列表、通用 UI 组件，依赖 AsyncDisplayKit
- **横切层 `WuKongLogin / Contacts / DataSource`**：分别处理鉴权、联系人、数据源抽象
- **应用层 `Octo`**：AppDelegate、推送注册、Tab 装配

---

## 贡献

我们欢迎 Issue 与 PR。在提交前请阅读：
- [CONTRIBUTING.md](CONTRIBUTING.md) — 开发流程、commit 规范、PR 模板
- [CLAUDE.md](CLAUDE.md) — 工程规范（swizzle 白名单、调试工具生命周期等）

---

## License

Octo iOS 主要代码以 [Apache License 2.0](LICENSE) 发布。

仓库中包含的部分上游开源代码遵循其各自原始协议，详见 [NOTICE](NOTICE)：
- `Modules/WuKong*` 系列模块基于 [WuKongIM iOS SDK](https://github.com/WuKongIM/WuKongIMiOSSDK) (MIT)
- `Modules/WuKongBase/.../TelegramUtils/` 含来自 [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS) 的部分显示层代码 (GPL v2)，目前作为消息 cell 的依赖。详见 [TelegramUtils/README.md](Modules/WuKongBase/WuKongBase/Classes/Sections/Common/TelegramUtils/README.md)。

如需将本项目用于商业闭源场景，请评估 GPL v2 部分对你的影响，必要时替换 TelegramUtils 相关组件。

---

## 致谢

- [WuKongIM](https://github.com/WuKongIM/WuKongIM) — IM 协议与服务端
- [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS) — 显示层组件参考
- 所有 [Podfile](Podfile) 中列出的开源依赖
