# 贡献指南

感谢你对 Octo 的关注。本指南帮助你把第一个 Issue / Pull Request 顺利合入。

---

## 开始之前

1. **阅读 [README](./README.md)** 了解项目结构和构建方法
2. **检查现有 Issue**，避免重复劳动；如果没有相关 Issue，建议先开一个 Issue 讨论方向
3. **大改动先开 RFC Issue**：超过 ~200 行 / 涉及架构调整 / 改公共 API 的 PR，请先用 Issue 描述思路并对齐

---

## 开发流程

```bash
# 1. Fork 仓库并克隆到本地
git clone <your-fork> && cd octo-ios

# 2. 同步 upstream
git remote add upstream <upstream-url>
git fetch upstream

# 3. 从 develop 切出 feature/fix 分支
git checkout -b fix/some-bug upstream/develop

# 4. 修改 + 测试 + 提交（commit 规范见下）

# 5. push 到自己 fork 后开 PR，目标分支 develop
```

### 提交前自检

- [ ] 编译通过（Debug + Release 两种 configuration）
- [ ] 在真机上回归（部分 UI / 推送 / 后台行为模拟器无法复现）
- [ ] 改动覆盖到深浅色模式
- [ ] 没有引入新的 NSLog（如需调试，使用 `WKLog*` 宏）
- [ ] 没有把本地配置（AppKey / Team ID / 服务地址）误提交
- [ ] 没有 import 引入新的 GPL/LGPL 代码

---

## 代码规范

### 文件许可声明

新建源文件**必须**在头部加上：

```objc
// Copyright 2026 MININGLAMP Technology and the OCTO contributors
// SPDX-License-Identifier: Apache-2.0
```

Swift / C++ / Header 文件相同；Python / Shell 用 `#` 开头。

### 命名

- Objective-C 类前缀：`WK*`（开源前会迁移到 `OCTO*`，请关注 P7 阶段公告）
- Swift 公开类型：与所属模块语义一致，无前缀
- 资源、Asset Catalog 项命名使用 snake_case

### 风格

- Objective-C 4 空格缩进，无 tab
- Swift 使用 SwiftLint 默认规则（见 `.swiftlint.yml`，待补）
- 一个文件一个类；公开类必须配 `*.h` 注释

### 不要做的事

- 不要把日志写完整 token / 密码 / userInfo 字典 — 见 [P0 提交记录](https://github.com/) 关于敏感日志的清理
- 不要给 `NSObject` / `UIView` / `NSNotificationCenter` 这种基类做 swizzle，详见 [CLAUDE.md 中的 Swizzle/+load 白名单规范](./CLAUDE.md)
- 不要让任何线上分支保留 `NSAllowsArbitraryLoads = YES`（应改为按域名白名单）

---

## Commit 规范

参考 [Conventional Commits](https://www.conventionalcommits.org/)，模板：

```
<type>(<scope>): <subject>

<body>
```

`type` 取值：

| type | 含义 |
|---|---|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `chore` | 杂项（构建脚本、依赖更新、清理） |
| `docs` | 文档 |
| `refactor` | 重构（不改变外部行为） |
| `perf` | 性能优化 |
| `test` | 测试 |
| `build` | 构建系统 / CI |
| `revert` | 回滚某个 commit |

`scope` 常用：`chat` / `contacts` / `login` / `aisummary` / `imsdk` / `push` / `theme` 等。

示例（来自项目实际提交）：

```
fix(chat): 合并消息详情页超链接颜色统一 + 可点击
chore(aisummary): 移除 trigger 全文 prompt 日志 — 防敏感内容泄漏到设备日志
feat(chat): 多选区间快选 — "选到这里"浮层按钮
```

`subject` 控制在 50 字符内，必要时在 body 用 1-2 段补充触发场景、根因、复测方式。

---

## Pull Request 规范

### PR 标题

与 commit message 一致格式：`<type>(<scope>): <subject>`

### PR 描述模板

```markdown
## 变更内容
<改了什么 / 为什么改>

## 复测
- [ ] 编译通过（Debug / Release）
- [ ] 真机回归（机型 / 系统版本：xxx）
- [ ] 深浅色模式
- [ ] 关联 Issue：#NNN

## 截图 / 录屏（如涉及 UI）
```

### Review 流程

1. 自动 CI 必须全绿（Lint / 单元测试，待 CI 接入后启用）
2. 至少 1 名 Maintainer Approve
3. 合并方式：默认 **Squash and merge**，commit message 用 PR 标题

---

## 报告 Bug / 安全问题

### 普通 Bug

[开 Issue](https://github.com/) 时请提供：

- 复现步骤（含输入、点击路径）
- 期望行为 vs 实际行为
- 环境（机型 / iOS 版本 / App 版本 / 网络环境）
- 截图 / 录屏 / 日志（脱敏后）

### 安全漏洞（不要公开 Issue）

涉及敏感安全问题，请通过私下渠道联系（联系方式待发布前补充）。我们会在 30 天内回复。

---

## 行为准则

参与本项目即视为同意遵守 [Contributor Covenant](https://www.contributor-covenant.org/) 行为准则。简而言之：尊重他人、对事不对人。

---

## License

提交的所有代码默认在 [Apache License 2.0](./LICENSE) 下许可。提交即代表你拥有该代码的版权或已获得授权。
