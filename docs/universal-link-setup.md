# Universal Links 配置指南

Octo iOS 用 Universal Links 处理外链点击直接打开 App（如分享卡片、邀请链接）。
本文档帮你接入自己的域名。

---

## 一、什么是 Universal Links

Universal Links 让 `https://your.domain/path` 这样的链接在用户点击时
**直接打开你的 App**（而非 Safari）。原理：

1. 你的服务器在固定路径 `/.well-known/apple-app-site-association` 放一个 JSON
2. iOS 启动后会读这个 JSON，看哪个 App 接管哪些路径
3. 满足配置的链接被点击时，iOS 跳过 Safari 直接传给 App

---

## 二、Octo iOS 当前用到的 Universal Links

主要用途：

| 场景 | 路径示例 |
|---|---|
| 群聊邀请链接 | `https://your.domain/invite/:code` |
| 分享卡片 | `https://your.domain/share/:id` |
| 文件预览深链 | `https://your.domain/file/:id` |

实名认证 / OIDC 登录回跳**不走 Universal Links**，走自定义 URL scheme
（详见 `OctoConfig.xcconfig.template` 中 `OCTO_URL_SCHEME` 章节）。

---

## 三、接入步骤

### Step 1: 准备 Apple Developer 配置

1. [developer.apple.com](https://developer.apple.com) 登录
2. 进入你的 App ID 配置
3. 勾选 **Associated Domains** capability
4. 重新下载 Provisioning Profile

### Step 2: 改 Xcode entitlements

打开 `Octo/Octo.entitlements`，把 placeholder
替换成你的真实域名：

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:your.domain.com</string>
    <!-- 测试用：applinks:your.domain.com?mode=developer -->
</array>
```

> 暂未支持通过 `OctoConfig.xcconfig` 变量替换 entitlements 内容（Apple
> 限制），需手动编辑。

### Step 3: 服务器端发布 apple-app-site-association

把以下 JSON 文件部署到 `https://your.domain.com/.well-known/apple-app-site-association`：

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["YOUR_TEAM_ID.com.example-app.octo"],
        "components": [
          {
            "/": "/invite/*",
            "comment": "群聊邀请链接"
          },
          {
            "/": "/share/*",
            "comment": "分享卡片"
          },
          {
            "/": "/file/*",
            "comment": "文件预览"
          }
        ]
      }
    ]
  }
}
```

**关键要求：**
- 必须 HTTPS 协议
- 必须返回 `Content-Type: application/json`
- 必须可被 Apple CDN 抓取（无认证、无重定向）
- `appIDs` = `YOUR_TEAM_ID.com.example-app.octo`（替换为你的 Team ID + Bundle ID）

### Step 4: 验证

iOS 14+ 用 Apple 的官方工具：

```
https://app-site-association.cdn-apple.com/a/v1/your.domain.com
```

返回你的 JSON 表示 Apple CDN 已抓取。

设备端调试：

```
xcrun simctl openurl booted https://your.domain.com/invite/abc123
```

Universal Link 应该跳进 App；如果跳了 Safari 说明配置不对。

---

## 四、常见问题

| 现象 | 原因 |
|---|---|
| 点击链接跳 Safari 而非 App | apple-app-site-association 抓不到 / appID 不匹配 |
| 安装第一次能打开，重启后不能 | iOS 14 起 Universal Links 缓存 1 小时，需等或重装 |
| 真机能开模拟器不能 | 模拟器 Universal Link 仅 14+ 支持，确认 iOS 版本 |
| `applinks:?mode=developer` 不生效 | iOS 16+ 才支持 developer 模式 |

---

## 五、相关文件

- `Octo/Octo.entitlements` — Associated Domains 配置
- `OctoConfig.xcconfig.template` — `OCTO_ASSOCIATED_DOMAIN` 占位（暂未生效）
- `Modules/WuKongBase/WuKongBase/Classes/WKApp.m` — `application:continueUserActivity:` 入口
