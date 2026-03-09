-- 消息扩展表
create table message_extra
(
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id    UNSIGNED BIG INT not null default 0,                             -- 消息ID
    message_seq    UNSIGNED BIG INT not null default 0,                             -- 消息seq
    channel_id    VARCHAR(100)      not null default '',                            -- 频道ID
    channel_type  smallint         not null default 0,                             -- 频道类型
    readed        integer          not null default 0,                             -- 消息是否已读
    readed_count  integer          not null default 0,                             -- 消息已读数量
    unread_count  integer          not null default 0,                             -- 消息未读数量
    revoke        smallint         not null default 0,                             -- 是否已撤回
    revoker       VARCHAR(40)      not null default '',                            -- 撤回者的uid
    content_edit  text             not null default '',                           -- 消息正文编辑
    edited_at     integer          not null default 0,                             -- 最后一次编辑时间
    upload_status   smallint         not null default 0,                           -- 上传状态 0.不需要上传 1.待上传 2.上传失败
    extra_version bigint           not null default 0                             -- 扩展版本编号
);
CREATE UNIQUE INDEX IF NOT EXISTS message_extra_idx ON message_extra(message_id);
CREATE INDEX IF NOT EXISTS idx_message_extra ON message_extra (channel_id, channel_type);

-- 提醒项表
create table reminders
(
    id    INTEGER   PRIMARY KEY AUTOINCREMENT,
    reminder_id   INTEGER       not null default 0,             -- 提醒事项在服务端的id
    message_id    UNSIGNED BIG INT not null default 0,                             -- 消息ID
    message_seq    UNSIGNED BIG INT not null default 0,                             -- 消息seq
    channel_id    VARCHAR(100)      not null default '',                            -- 频道ID
    channel_type  smallint         not null default 0,                             -- 频道类型
    `type`        integer          not null default 0,                        -- 提醒类型
    `text`          varchar(255)    not null default '',                        -- 提醒内容
    `data`          varchar(1000)   not null default '',                        -- 自定义数据
    is_locate       smallint        not null default 0 ,                        -- 是否需要定位
    version       bigint            NOT NULL default 0,
    done          smallint          not null default 0,                        -- 是否完成
    done_at      integer         not null default 0,                   --  done时间 (仅本地用)
    upload_status   smallint         not null default 0                        -- 上传状态 0.不需要上传 1.待上传 2.上传失败 （仅本地用）
);
CREATE INDEX IF NOT EXISTS idx_channel_reminders ON reminders (channel_id, channel_type);
CREATE UNIQUE INDEX IF NOT EXISTS uidx_reminder ON reminders(reminder_id);


-- 最新会话扩展表
create table conversation_extra
(
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id    VARCHAR(100)      not null default '',                            -- 频道ID
    channel_type  smallint         not null default 0,                             -- 频道类型
    browse_to     UNSIGNED BIG INT not null default 0,              --  预览位置 预览到的位置，与会话保持位置不同的是 预览到的位置是用户读到的最大的messageSeq。跟未读消息数量有关系
    keep_message_seq  UNSIGNED BIG INT not null default 0,          -- 保持位置的messageSeq
    keep_offset_y    INTEGER not null default 0,
    draft     varchar(1000)   not null default '',                  -- 草稿
    version   bigint    NOT NULL default 0              -- 数据版本
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_channel_conversation_extra ON conversation_extra (channel_id, channel_type);
