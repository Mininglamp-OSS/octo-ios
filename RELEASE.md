# Octo iOS 发版指南

> 分支策略：GitFlow（`base=develop`） · 默认分支：`develop`

## TL;DR

**日常**：feature PR 合到 `develop`。
**发版**：`develop → main` release PR → merge commit → tag → Xcode Archive + Distribute。

> ⚠️ 本仓库目前无 CI workflow，正式包必须本地 Xcode 手动打包。

---

## 分支模型

```
功能开发 PR ─────→ develop      ← 所有 PR 目标（默认分支）
                         │
                         │ release cut (PR)
                         ↓
                       main          ← 生产基线
                         │
                         │ git tag v1.x.y
                         ↓
                    TestFlight / App Store
```

**硬约束**：
- ❌ 不要直接 push `main`
- ❌ release PR **不要 squash**（要 merge commit 保留 feature 历史）
- ❌ tag 不要打在 `develop`
- ❌ 不要用 Development 证书 Archive 发正式

---

## 标准发版流程（5 步）

### 1. 开 release PR（`develop → main`）

```bash
gh pr create \
  --base main --head develop \
  --title "release: v1.x.y" \
  --body "本次发版内容：
- ...（列 merged PR / 重要修复）"
```

### 2. Review & merge commit

- 至少 1 位 reviewer 过一遍
- **用 merge commit，不要 squash**

### 3. 打 tag

```bash
git checkout main
git pull origin main
git tag v1.x.y
git push origin v1.x.y
```

### 4. 构建正式 IPA（Xcode）

1. Xcode 打开项目，切到 `main` 分支（对齐 `v1.x.y` tag）
2. Scheme 选 **OctoiOS**，Build Configuration 选 **Release**，Target 选 **Any iOS Device**
3. **Product → Archive**
4. Archive 完成后在 Organizer 选 **Distribute App**
5. 选择分发方式：**App Store Connect**（上架 / TestFlight）或 **Ad Hoc**（内测）
6. 证书选 **Distribution**（不是 Development）
7. Provisioning Profile 对应 Distribution

### 5. 发布

- **内测**：TestFlight
- **上架**：App Store Connect 提交审核 → 正式版

---

## 发版后：拉回 develop（关键）

```bash
git checkout develop
git pull origin develop
git merge main
git push origin develop
```

---

## Hotfix 流程

1. 从 `main` 切 `hotfix/xxx`
2. 修复
3. 提 PR `hotfix → main` + `hotfix → develop`
4. merge 后打 patch tag（如 `v1.0.1`）
5. Xcode Archive + Distribute

---

## CI 现状

本仓库目前无 CI workflow（欢迎贡献）。日常验证依赖：

- Xcode 本地 build + 真机测试
- code review 人工把关

正式发版必须本地 Xcode 手动 Archive → Distribute。

---

## 常见坑

| 坑 | 后果 | 对策 |
|---|---|---|
| 直接 push main | main ↔ develop 分歧 | 必须走 PR |
| release PR squash | main 历史塌成单 commit | 用 merge commit |
| tag 打 develop | 商店版本 ≠ 代码库 | tag 只打 main |
| 发版后忘记回流 | 下次 release 冲突 | 立即 merge main → develop |
| 用 Development 证书 Archive | 不能上 TestFlight / App Store | 必须用 Distribution 证书 |
| scheme 用 Debug | 调试符号泄露，性能差 | Archive 用 Release scheme |
