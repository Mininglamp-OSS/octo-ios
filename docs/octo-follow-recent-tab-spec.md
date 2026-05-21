# 关注 / 最近 双 tab 改版 — iOS 实施 spec

对齐 octo-web PR #27 (`feat(sidebar): rework follow tab on /v2/sidebar/sync + manual sort`)，
**但只移植适合移动端的部分**——见 §0 的"对齐 / 不对齐"清单。

状态：草案，待评审后分阶段落地。
日期：2026-05-20。

---

## 0. 目标 / 产品模型

把消息 tab 顶部的"群聊 / 私聊" filter 改成"关注 / 最近"：

- **关注 tab** = 现有"群聊+分组"视图扩展：分组里既能放群也能放 DM，子区仍嵌在父群下（保持现有"群下挂子区"的折叠展开形态）。隐藏默认分组。
- **最近 tab** = 全平铺时间序：DM、群、子区**各自独立成行**混排，按 `timestamp` 倒序。3 天内无活动的群从列表和未读里都过滤。

> 接口/数据模型/CAS/默认分组隐藏 等工程细节按 web PR #27 来；产品交互按上面这套移动端模型来。

### 与 web 严格对齐的部分（接口、数据模型、产品规则）

- 全部 API 路径与 payload（`/sidebar/sync` + `follow/{dm,channel,thread,sort}` + `categories/*`）
- `target_type` 取值（1=DM / 2=Group / 5=Thread）、`SidebarItem` 字段
- `followedKeys` 作为关注状态唯一可信源（不依赖 IM cache 推断）
- `follow_version` CAS 锚点 + 写后 reload 收敛
- 3 天不活跃群在最近 tab 不显示也不计未读
- 关注 tab 隐藏默认分组（后端 `is_default=true` + 客户端虚拟 fallback default）
- 关注 tab 不显示置顶（手工序替代）
- 子区关注与父群关注独立判定（`followThread` 后端 cascade follow 父群，`unfollowThread` 不动父群）
- 从外部入口（通知、搜索、联系人）打开会话时，强切到「最近」tab
- `follow_sort` 的客户端兜底重排（后端响应排序混入了 pinned，必须按 `follow_sort` 在每个 category 内再排一次）

### 与 web 的产品差异（移动端取舍）

- **最近 tab 子区扁平化**：web 在最近 tab 也是 IM cache 模式（其实 web 现状是 group/DM 分 tab，PR 后变 follow/recent，最近 tab 是按会话时间序的，子区也是独立行）。iOS 与 web 一致，但要明确区分：旧 iOS 私聊 tab 不显示子区，最近 tab 是新行为。
- **关注 tab 子区嵌在父群下**：web PR 把已关注子区栈式渲染在父群下方（`ConversationListGrouped/index.tsx:500-524`），与 iOS 现有"群下挂子区"形态一致。两端表现一致。

### 不照搬 web 的部分（移动端用自己的方式）

| Web 做法 | iOS 做法 | 理由 |
|---|---|---|
| 列表内 inline drag（6px 长按即拖） | **不做 inline drag**；关注 tab 长按菜单提供"管理排序" → 进入独立排序页（仿现有 `WKCategoryReorderVC`） | 手机上长按已经用来弹菜单了；inline drag 滑动冲突、误触多。独立排序页是 iOS 通用范式 |
| 排序的 CAS 乐观更新 + 冲突重试 + finally reload | **一次性提交**：进入排序页 → 本地调整 → 退出时一次 PUT，失败弹错并保持本地序，下次重进时 reload | 没有 inline drag 就没有"快速连续拖动"的 race。`follow_version` 还是要带，冲突就提示"被其它设备改过，已重新加载" |
| `useFollowSidebar` Context Provider | 单例 `WKFollowedKeysStore` + 通知/KVO | iOS 没有 React Context，singleton 是惯例 |
| 三级菜单（添加到关注 → 分组列表 → 新建分组） + hover bug 修复 | **两级 actionSheet**：默认目的地记忆，长按菜单出"添加到 XX 分组"+"添加到其它分组…" | iOS 没有 hover，三级 sheet 反人类。默认目的地大幅降低点击数 |
| `localStorage["wk_sidebar_active_tab"]` 字符串持久化 | 复用现有 `WKConversationTabIndex` int key 做映射迁移 | 跨端不会共享存储，无收益 |
| 关闭聊天窗口（关闭多 tab 之一） | iOS 没这个概念 → 直接不存在该菜单项 | 移动端单一会话页面 |
| 删除分组的确认 modal | `UIAlertController` + 「删除该分组下所有关注会被取消」二次确认 | 平台一致性 |
| **不加下拉刷新** | 会话列表本来就是 IM 长链路自动 push 更新，从不需要用户手动刷；sidebar 数据靠 app 切回前台 + 进入消息 tab 时自动 reload 兜底，配合后端 CMD push（如已发） | iOS 现状无手动刷新操作；加 MJRefresh 与现有体验不一致 |
| `device_uuid` 必填 | 用现有 `[WKApp deviceID]` | iOS 原生有，直接用 |

### 二期再评估的部分

- 滑动手势加"取消关注"快捷（现有 `SwipeTableCell` 返回空数组，等产品确认价值）
- 关注 tab 是否需要桶内 inline drag（如果用户反馈排序页太重再补）
- 把"管理排序"做成可拖父群带子区的强排序，还是仅排父群

---

## 1. 接口对齐

### 1.1 路径前缀

Web 走 `/v1/...` 靠 nginx rewrite 到 `/v2/{follow,sidebar}/*`。**iOS 沿用 `/v1/` 路径**（与现有 `WKCategoryService` 一致）。上线前向后端确认 iOS 是否同样走该网关；若直连后端，则改为 `/v2/...`。该决策只影响 service 内的字符串常量，业务无感。

### 1.2 新增 service

| 类名 | 文件 | 职责 |
|---|---|---|
| `WKSidebarService` | `Sections/ConversationList/Sidebar/WKSidebarService.{h,m}` | `POST /v1/sidebar/sync` |
| `WKFollowService` | `Sections/ConversationList/Sidebar/WKFollowService.{h,m}` | follow DM/channel/thread 全部增删 + `PUT /v1/follow/sort` |

`WKCategoryService` 现有方法（list/create/rename/delete/sort + `moveGroup:toCategoryId:`）**保持不动**，关注 tab 直接复用。

### 1.3 请求/响应

`POST /v1/sidebar/sync`：
```
请求：{ tab: "follow"|"recent", version: int, last_msg_seqs: string,
        msg_count: 1, device_uuid: string }
响应：{ items: SidebarItem[], version: int, follow_version: int }
```

`SidebarItem`（iOS 用 `WKSidebarItemEntity`）：
```
target_type    int    1=DM, 2=Group, 5=Thread
target_id      string peer_uid / group_no / thread_channel_id
channel_type   int    映射到 WKChannelType
channel_id     string
timestamp      int64
unread         int
is_pinned      bool
is_followed    bool   关注 tab 总是 true
category_id    string?
category_sort  int?
follow_sort    int?
parent_channel_id string? 仅 thread
```

其它路由（请求体见 web `FollowService.ts`）：

- `POST /v1/follow/dm` `{ peer_uid, category_id? }` —— 关注 DM 或跨分组移动（覆盖语义）
- `DELETE /v1/follow/dm?peer_uid=`
- `POST /v1/follow/channel/{unfollow,refollow}` `{ group_no }`
- `POST /v1/follow/thread` `{ thread_channel_id }` —— 后端自动 cascade follow 父群
- `DELETE /v1/follow/thread?thread_channel_id=`
- `PUT /v1/follow/sort` `{ items: [{target_type,target_id,sort}], version }`
  - 失败：HTTP 400 + msg 含 `"version conflict"`，iOS 按字符串识别后弹"被其它设备改过，已重新加载"，再 reload。

---

## 2. 数据层改造

### 2.1 关注状态唯一可信源

`WKFollowedKeysStore`（单例）：

- 内部 `NSSet<NSString *> *followedKeys`，键 `@"{target_type}::{target_id}"`
- 每次 `sidebar/sync` 后整体替换；每次写成功后 reload。
- 暴露同步 API：`- (BOOL)isFollowedWithType:(WKChannelType)t targetId:(NSString *)tid;`
- **禁止**根据 `WKChannelInfo.follow`（好友状态）、cell 缓存、IM cache 推断关注状态。

### 2.2 follow_version 持有

挂在 `WKFollowedKeysStore`：

- `@property (atomic) NSInteger followVersion;`
- 写请求（目前只有排序）携带；冲突时 reload 后不重试，提示用户即可（移动端没有连续高频写，不需要 web 那套重试）。

### 2.3 cascade 写后必 reload

`deleteCategory:` / `moveGroup:toCategoryId:` 完成后必须 `bumpVersion + reloadSidebar`。最近 tab 的 follow/unfollow 写操作完成后也要 reload，否则切回关注 tab 状态不一致。

### 2.4 桶内按 follow_sort 重排

`/sidebar/sync` 返回顺序混入了 pinned，**iOS 必须忽略响应数组顺序**，在 VM 里按 `category_id` 分桶、桶内按 `follow_sort ASC`（空值 `NSIntegerMax` 兜底）重排。

---

## 3. VC / VM 改造

### 3.1 Filter enum 重命名

```objc
typedef NS_ENUM(NSInteger, WKConversationFilterType) {
    WKConversationFilterFollow = 0,
    WKConversationFilterRecent = 1,
};
```

旧值 `Group=0 / Private=1` 直接替换。`WKConversationTabIndex` UserDefaults 启动时一次性迁移（0→Follow, 1→Recent）。

### 3.2 `WKConversationTabView`

文件保留，仅改文案 / 内部命名 / 未读 setter 名（`setFollowUnreadCount:` / `setRecentUnreadCount:`）。胶囊动画 / 滑动手势 / mention 红点全部保留。

### 3.3 数据装配

**关注 tab**（"保持现有分组群聊视图 + 把 DM 也允许塞进分组"）：
- 并行拉取 `WKCategoryService listCategories:` + `WKSidebarService sync:(tab=follow)`
- 渲染顺序：按 category 分桶（section header 复用 `WKCategorySectionCell`），桶内按 `follow_sort ASC`（空值 `NSIntegerMax` 兜底）混排群和 DM
- 子区**沿用现状**：嵌在父群下，靠 `WKConversationGroupThreadCell` 折叠/展开（VM 现有 `isThreadExpanded:` 状态保留）—— 这是产品要求"保持目前分组的基础"
- **隐藏 `is_default` 分组**（含后端 `is_default=true` 和客户端虚拟 fallback default）
- 父群已关注但子区不在 `followedKeys` → 即使 IM cache 有也不显示（避免取消子区关注后还残留）

**最近 tab**（"全平铺、时间序、子区独立成行"）：
- 数据源：IM cache 全量（`WK_PERSON` + `WK_GROUP` + `WK_COMMUNITY_TOPIC`）
- **子区不再嵌套**，每个子区是独立 cell，与 DM/群同级按 `timestamp` 倒序混排
  - 复用 `WKConversationGroupThreadOnlyCell`（现有 thread-only 变体，本来就为此场景设计）或新增一个"扁平子区 cell"，标题展示 `「父群名」/ 子区名` 让用户能识别
  - VM 装配 `WKConversationDisplayItem` 时不再走"群下挂子区"路径，子区作为顶层 item 加入
- **子区头像 = 父群头像 + 右下角 hash 角标**（移动端直观识别"是子区 + 属于哪个群"）：
  - 主体：父群头像（通过 `parent_channel_id` 查 `WKChannelInfo`，URL 走 `+[WKAvatarUtil getGroupAvatar:cacheKey:]`，cacheKey 用父群 `avatarCacheKey`）
  - 角标：现有 `+[WKConversationGroupThreadCell channelHashIconWithSize:color:]` 生成的 hash 图标，叠在右下角，尺寸约父头像的 0.45（足够显眼但不挡脸）；底色用 cell 背景同色画一圈描边，避免与父头像粘连
  - 实现方式：建议新建 `WKThreadAvatarView`（`UIImageView` + 子 `UIImageView` 叠加），子区 cell 用，避免每次都 draw 复合图
- **父群头像更新时子区头像同步刷新**：
  - 现有链路：`WKSystemMessageHandler.m:317-319` 收到 `WKCMDGroupAvatarUpdate` 后清 `SDImageCache` 对应 URL —— 子区头像复用同一 URL 同一 cacheKey，**自然会失效**
  - 但当前 SDImageCache 清除不会主动触发 `reloadData`。需要在 `WKSystemMessageHandler` 处理 `groupAvatarUpdate` 时额外 post 一个 `kWKGroupAvatarUpdatedNotification`（携带 `group_no`），`WKConversationListVC` 监听后对最近 tab 里 `parent_channel_id == group_no` 的子区 cell 触发 `reloadRowsAtIndexPaths:` 或直接 `[cell setNeedsLayout]`
  - 同样的通知 vlist 也用得到：父群本身 cell 也需要刷新（虽然现有代码可能已经在 `channelUpdate` 路径处理了，需顺带检查一遍是否两条路径有重复）
- **3 天群过滤**：`now - timestamp*1000 >= 3 * 86400_000` 的 `WK_GROUP` 不显示也不计未读（DM/thread 不过滤）。Web 验证过的产品规则，移动端列表更短更值得
- 不分组、不显示 category section header
- 进入此 tab 仍需 `WKFollowedKeysStore` 已加载（长按菜单要判断 取消关注/添加到关注）


### 3.4 未读徽标

- 关注 tab 徽标 = 关注集合内未读总和
- 最近 tab 徽标 = 全部未读 - 3 天前的群未读
- 计算放进 VM 或 store，避免散落

---

## 4. 移动端交互

### 4.1 关注 tab 长按菜单

复用 `showConversationMenuForModel:atPoint:`：

| 操作 | DM | 群 | 子区 |
|---|---|---|---|
| 取消关注 | ✓ | ✓ | ✓ |
| 移到分组（二级 sheet） | ✓ | ✓ | ✗ |
| 通知开关 | ✓ | ✓ | ✓ |
| 删除会话 | ✓ | ✓ | ✓ |
| 管理排序（进排序页） | 仅出现在第一个被长按 cell 的菜单底部，进入后排序全 tab | | |
| 置顶 / 关闭聊天 | **隐藏** | **隐藏** | **隐藏** |

### 4.2 最近 tab 长按菜单

新增逻辑：

```
key = "{target_type}::{target_id}"
if followedKeysStore.isFollowed(key):
    item = "取消关注" → 调对应 unfollow*
else:
    # 默认目的地：上次成功 follow 用的 category_id（NSUserDefaults 记忆）
    item1 = "添加到关注（XX 分组）" → 直接调 followDM / refollow+move / followThread
    item2 = "添加到其它分组…" → 弹二级 sheet 选分组（含 + 新建分组）
    # 首次使用（无记忆）→ 只显示 "添加到关注…" 走二级 sheet
    # 子区 + 父群已关注 → 直接 followThread（后端 cascade），不弹分组选择
```

### 4.3 分组 section header 长按

复用现有 `showSectionManagePopup:`：新建群聊 / 重命名 / 排序分组 / 删除分组。删除分组用 `UIAlertController` 二次确认提示「该分组下所有关注会被取消」。默认分组只保留上移/下移（关注 tab 里默认分组已隐藏，本菜单仅在群聊 tab 残留期生效；改版后只在关注 tab 出现）。

### 4.4 排序

**关注 tab 不做 inline drag**。增加独立 `WKFollowReorderVC`：

- 入口：关注 tab 长按 cell 菜单底部「管理排序」
- 实现仿现有 `WKCategoryReorderVC`：列表展示所有非默认分组 + 桶内 item，每行右侧拖动 handle，UITableView edit mode
- 只允许桶内重排，跨分组移动通过「移到分组」菜单完成
- 退出时一次性 `PUT /v1/follow/sort`，items 按当前可见顺序、`sort = idx`，携带 `follow_version`
- 拖动父群时自动连带其下已关注子区（提交 payload 时父群条目后紧接子区，对齐 web 行为）
- 提交失败弹 toast 并保留本地序，下次进入重新拉取

> 这套牺牲了"乐观即时反馈"，换来移动端不需要实现 CAS 重试。代价小，价值大。

### 4.5 外部入口强切「最近」tab

对齐 web `EndpointCommon.tsx` 的 `fromSidebarList` 语义：

- 在 `WKApp` 内会话打开入口（通知 deeplink、联系人 tap、全局搜索、机器人商店等）传递 `from` 来源
- 入口判断：来自侧栏列表 → 不切；其它来源 → 当前在关注 tab 且 channel 不在 `followedKeys` → 强切最近 tab
- 实现：定义 `kWKSwitchSidebarTabNotification`（带 `tab` 字段），各入口 post，VC 监听后切换并持久化

### 4.6 自动 reload sidebar（替代下拉刷新）

会话列表本身靠 WuKongIM 长链路自动 push，**不加 MJRefresh**（与 app 现有体验一致：用户从不需要手动刷）。

`sidebar/sync` 带来的"IM 没有"的数据（`category_id` / `follow_sort` / `followedKeys` / `follow_version`），本机写后已经 reload。**跨端延迟**两路收敛：

**主路径——IM CMD push**：

iOS 已有现成的 CMD 推送基础设施（`WKCMDManager addDelegate:` + `WKSystemMessageHandler.handleCMD:param:` 交换机，已订阅 `channelUpdate` / `memberUpdate` / `conversationDeleted` 等 15+ 个 CMD）。本期接入一个新 CMD 分支：

- CMD 名（待与后端确认，建议 `follow_changed` 或 `sidebar_changed`），param 至少包含新的 `follow_version`
- 在 `WKSystemMessageHandler.m:413` 附近加 `else if` 分支：收到后调 `[WKFollowedKeysStore reload]`
- 关键确认项：**后端 fanout 必须覆盖同 uid 的其它设备**，否则跨端延迟问题没解（仅 Space 内成员 fanout 不够，因为用户自己的多设备登录才是主要场景）
- **当前 web / iOS 客户端都没接该 CMD**（grep 验证），需要确认后端是否已发。若后端尚未发，请后端补；若已发但用了别的名字，按实际名字接

**兜底路径——前台 reload**：

不论 CMD push 是否到位，都保留以下时机的自动 reload（debounce ≥ 30s）：

- App 从后台切回前台（`UIApplicationDidBecomeActiveNotification`）
- 从其它 tab 切回消息 tab

CMD 是 best-effort（弱网/断连场景可能丢），前台 reload 是确定性兜底，两者并存。

### 4.7 滑动手势

现有 `SwipeTableCell` 返回空数组，本期不动；二期再评估是否加左滑"取消关注"。

---

## 5. 子区特殊规则（务必对齐）

1. **isFollowed 只看 sidebar**：`WKFollowedKeysStore` 是唯一来源
2. **followThread 自带 cascade**：iOS 只发 `POST /v1/follow/thread`，不要客户端主动 follow 父群
3. **unfollowThread 不动父群**
4. **关注 tab 渲染过滤**：父群已关注但子区不在 `followedKeys` → 不显示
5. **最近 tab 子区菜单**：
   - sidebar 列出 → "取消关注"
   - 未列出 + 父群已关注 → "添加到关注"（直接 `followThread`）
   - 未列出 + 父群未关注 → 二级菜单选分组（`refollow` + `moveGroup` + `followThread` 链式）

---

## 6. 实施阶段

| 阶段 | 内容 | 验收点 |
|---|---|---|
| **P0** | `WKSidebarItemEntity`、`WKSidebarService`、`WKFollowService`、`WKFollowedKeysStore`。单测覆盖反序列化、桶内重排、版本冲突识别 | 单测全过 |
| **P1** | `WKConversationFilterType` 重命名 + UserDefaults 迁移 + `WKConversationTabView` 文案替换 | 真机看到"关注/最近"两个 tab，旧用户设置正确迁移 |
| **P2** | 关注 tab 数据装配换 sidebar/sync + 分组渲染 + follow_sort 重排 + 子区栈式显示 + 默认分组隐藏；3 天群过滤接最近 tab | 关注 tab 列表 & 计数与 web 一致 |
| **P3** | 长按菜单按 tab 差异化 + 二级"移到分组"/"添加到分组" sheet + 默认目的地记忆 + 外部入口强切最近 tab + 分组 CRUD 后 reload | 菜单行为对齐 web PR #27（除界面交互） |
| **P4** | `WKFollowReorderVC` 排序页 + 一次性提交 + 冲突提示 + 父群带子区 | 排序提交后刷新顺序保持 |
| **P5** | 子区全量规则 + 边角 case（cascade unfollow、删分组、跨分组移群）+ Bugly 抓栈 + 灰度 | 7 天灰度无异常 |

---

## 7. 实现期工程默认值（不需事先确认，遇到再调）

- **URL 前缀**：默认 `/v1/...`（与现有 `WKCategoryService` 一致）。如真机联调发现 nginx 没为 iOS 做 v1→v2 rewrite，改 service 内常量到 `/v2/...` 即可，业务无感
- **`device_uuid`**：直接传 `[WKApp deviceID]`，后端校验报错再调
- **`follow_sort` 后端兜底**：iOS 客户端做和 web 一致的桶内重排，后端将来统一了两端一起去
- **CMD push**：iOS 已有 `WKCMDManager addDelegate:` + `WKSystemMessageHandler.handleCMD:param:` 交换机。本期不主动接 follow 相关 CMD（grep 验证两端都没订阅），若后端实际已发，在 `WKSystemMessageHandler.m:413` 加一个 `else if` 分支调 `[WKFollowedKeysStore reload]` 即可，5 行代码

---

## 8. 参考

- octo-web PR #27：https://github.com/Mininglamp-OSS/octo-web/pull/27（commit `e5995082`）
- 主要 web 文件：
  - `packages/dmworkbase/src/Service/{Follow,Sidebar,Category}Service.ts`
  - `packages/dmworkbase/src/Hooks/useFollowSidebar.ts`
  - `packages/dmworkbase/src/Components/{ChatConversationList,ConversationListGrouped}/index.tsx`
- iOS 主要触点：
  - `Modules/WuKongBase/.../ConversationList/WKConversationListVC.m`
  - `Modules/WuKongBase/.../ConversationList/WKConversationListVM.{h,m}`
  - `Modules/WuKongBase/.../ConversationList/WKConversationTabView.{h,m}`
  - `Modules/WuKongBase/.../ConversationList/Category/{WKCategoryService,WKCategoryReorderVC}.{h,m}`
  - `Modules/WuKongBase/.../Services/Base/WKAPIClient.{h,m}`
