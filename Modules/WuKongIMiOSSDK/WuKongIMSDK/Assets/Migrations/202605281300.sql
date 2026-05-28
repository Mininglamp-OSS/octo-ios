-- WKUnreadStateDB: per-channel 已读进度持久化.
-- 替代之前 NSUserDefaults 方案. NSUserDefaults 的问题:
-- (1) 进程全局, 多账号在同一台设备登录会互相污染(本表跟随 WKDB 切库,
--     account A / account B 各自独立);
-- (2) iOS 延迟批量 flush, 用户 mark-read 后立刻 kill app 容易丢数据,
--     synchronize() 也不是 100% 可靠;
-- (3) 与 mergeConversations 的 inTransaction 之间无原子性,
--     这里改成 sqlite 表后可以与 conversation.unread_count 清零放在
--     同一个 transaction 里写, 解决一致性问题.
create table unread_state
(
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id         VARCHAR(100)     not null default '',
    channel_type       smallint         not null default 0,
    last_read_seq      bigint           not null default 0,    -- 用户在本设备读到的最高 message_seq
    last_local_read_at bigint           not null default 0     -- unix timestamp, 用于 60s 保护窗口
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_unread_state_channel ON unread_state(channel_id, channel_type);
