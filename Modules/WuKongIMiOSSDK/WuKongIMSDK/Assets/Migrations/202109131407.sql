-- 回应表
create table reactions
(
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id   UNSIGNED BIG INT not null default 0,                              -- 消息ID
    channel_id   VARCHAR(100)      not null default '',                             -- 频道ID
    channel_type smallint         not null default 0,                              -- 频道类型
    version       bigint       NOT NULL default 0,                             -- 版本号
    uid         VARCHAR(40)      not null default '',                             -- 回应人的uid
    emoji       VARCHAR(40)      not null default '',                            -- 回应的表情
    created_at  VARCHAR(20)       not null default '',             -- 回应时间
    is_deleted   smallint         not null default 0                              -- 是否已删除 0.否 1.是
);
CREATE UNIQUE INDEX IF NOT EXISTS reactions_idx ON reactions(message_id,uid);

