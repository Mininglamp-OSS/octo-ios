-- WKUnreadAckQueue: 持久化的 mark-read 上报队列.
-- 用户在本设备清掉某会话未读 → 入队 → 异步 PUT coversation/clearUnread → 成功 dequeue.
-- 失败/网络抖动: 留在队列里, 下次 WKConnected 时 WKUnreadAckRunner 重试.
-- 这是 "子区 server 永远显示 1" bug 的根治方案.
create table unread_ack_queue
(
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id      VARCHAR(100)     not null default '',
    channel_type    smallint         not null default 0,
    last_read_seq   bigint           not null default 0,
    attempts        smallint         not null default 0,
    next_retry_at   bigint           not null default 0,
    last_attempt_at bigint           not null default 0,
    created_at      bigint           not null default 0
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_unread_ack_channel ON unread_ack_queue(channel_id, channel_type);
CREATE INDEX IF NOT EXISTS idx_unread_ack_retry ON unread_ack_queue(next_retry_at);
