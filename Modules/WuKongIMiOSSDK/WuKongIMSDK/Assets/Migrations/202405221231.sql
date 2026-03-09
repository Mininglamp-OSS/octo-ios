
alter table `message_extra` add column is_pinned smallint not null default 0; -- 是否置顶


-- 消息扩展表
create table pinned_message
(
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id     UNSIGNED BIG INT not null default 0,                      -- 消息ID
    message_seq    UNSIGNED BIG INT not null default 0,                      -- 消息seq
    channel_id     VARCHAR(100)     not null default '',                     -- 频道ID
    channel_type   smallint         not null default 0,                      -- 频道类型
    version        bigint           not null default 0,                      -- 数据版本
    is_deleted     smallint         not null default 0                       -- 是否已删除
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pinned_message_id ON pinned_message(message_id);
CREATE INDEX IF NOT EXISTS idx_pinned_message_channel ON pinned_message (channel_id, channel_type);
