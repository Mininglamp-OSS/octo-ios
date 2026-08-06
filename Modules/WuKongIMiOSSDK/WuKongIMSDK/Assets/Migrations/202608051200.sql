-- 会话 ↔ 空间归属表 (conversation_space)
--
-- 背景: 群聊消息不带 space_id, 客户端原先无法判断一条 conversation 属于哪个空间,
-- 于是冷启动 / 切空间时用 `deleteAllConversation + 全量 sync` 来保证
-- "DB 里只有当前空间的会话" —— 等于把本地缓存整个丢掉, 断网时列表全空。
--
-- 这张表把"归属"变成可持久化的数据: DB 可以同时保留多个空间的会话,
-- 读路径 (getConversationList / max_version / sync_key) 按当前空间作用域过滤即可,
-- 不再需要清库。
--
-- 为什么是多对多 (space_id + channel 联合唯一, 而不是 conversation 上加一列 space_id):
-- 外部群 —— 我以 external member 身份加入别的空间的群 (WKSpaceFilter 里
-- member.source_space_id == currentSpaceId 就 Keep) —— 会同时在两个空间可见,
-- 单值列会判错。
--
-- 写入方 (全部是"已经知道空间归属"的既有判定点, 见 WKConversationSpaceDB 注释):
--   1. conversation/sync?space_id=X 的响应 (version=0 全量 → replace, 含 tombstone;
--      增量 → add)
--   2. WKConversationListVC.filterConversationsBySpace 判定通过的实时会话更新
--   3. 显式白名单: 建群/进群 (addGroupToWhitelist) 与后台核验 (verifyAndAddGroupsToList)
create table conversation_space
(
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    space_id     VARCHAR(100) not null default '',
    channel_id   VARCHAR(100) not null default '',
    channel_type smallint     not null default 0,
    synced_at    bigint       not null default 0    -- unix timestamp, 最后一次确认归属的时间
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_conv_space ON conversation_space(space_id, channel_id, channel_type);
CREATE INDEX IF NOT EXISTS idx_conv_space_channel ON conversation_space(channel_id, channel_type);
