-- 频道表
create table channel
(
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_id     varchar(100)  NOT NULL default '',                             -- 频道ID
  channel_type   smallint     NOT NULL default 0,                              -- 频道类型
  follow         smallint     NOT NULL default 0,                              -- 是否已关注 0.未关注（陌生人） 1.已关注（好友）
  name           varchar(100) NOT NULL default '',                             -- 频道名称
  notice         varchar(400) NOT NULL default '',                           -- 频道公告
  logo           varchar(255) NOT NULL default '',                             -- 频道logo
  remark         varchar(100) NOT NULL default '',                             -- 频道备注名
  stick          smallint     NOT NULL default 0,                              -- 是否置顶 0.否 1.是
  mute           smallint     NOT NULL default 0,                              -- 是否免打扰 0.否 1.是
  show_nick      smallint     NOT NULL default 0,                              -- 是否显示昵称
  save           smallint     NOT NULL default 0,                              -- 是否保存
  extra          text         not null default '',                             -- 扩展数据
  created_at     timeStamp    not null DEFAULT (datetime('now', 'localtime')), -- 创建时间
  updated_at     timeStamp    not null DEFAULT (datetime('now', 'localtime'))  -- 更新时间
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_channel ON channel (channel_id, channel_type);

-- +migrate StatementBegin
CREATE TRIGGER channel_updated_at
  AFTER UPDATE
  ON `channel`
  BEGIN
    update `channel` SET updated_at = datetime('now') WHERE id = NEW.id;
  END;
-- +migrate StatementEnd


-- 频道成员表
create table channel_member
(
  id            INTEGER      PRIMARY KEY AUTOINCREMENT,
  channel_id    varchar(100)  NOT NULL default '',                             -- 频道ID
  channel_type  smallint     NOT NULL default 0,                              -- 频道类型
  member_uid    varchar(40)  NOT NULL default '',                             -- 成员UID
  member_name   varchar(100) NOT NULL default '',                             -- 成员名称
  member_avatar varchar(100) NOT NULL default '',                             -- 成员头像
  member_remark varchar(100) NOT NULL default '',                             -- 成员备注
  version       bigint       NOT NULL default 0,                             -- 版本号
  role          INTEGER      NOT NULL default 0,                             -- 成员角色
  status        smallint     NOT NULL default 0,                             -- 成员状态
  extra         text         not null default '',                             -- 扩展数据
  created_at    varchar(40)  NOT NULL default '', -- 创建时间
  updated_at    varchar(40)  NOT NULL default '',  -- 更新时间
  is_deleted    smallint     NOT NULL default 0                               -- 是否已删除 0.否 1.是
);
CREATE INDEX IF NOT EXISTS idx_channel_member ON channel_member (channel_id, channel_type);



-- 消息表
create table message
(
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id   UNSIGNED BIG INT not null default 0,                              -- 消息ID
  message_seq  UNSIGNED BIG INT not null default 0,                              -- 消息序列号(非严格递增)
  order_seq    UNSIGNED BIG INT not null default 0,                              -- 消息排序号（消息越新序号越大）
  timestamp    integer          NOT NULL default 0,                              -- 服务器消息时间戳(10位，到秒)
  from_uid     VARCHAR(40)      not null default '',                             -- 发送者uid
  to_uid       VARCHAR(40)      not null default '',                             -- 接收者uid
  channel_id   VARCHAR(100)      not null default '',                             -- 频道ID
  channel_type smallint         not null default 0,                              -- 频道类型
  content_type integer          NOT NULL default 0,                              -- 消息正文类型
  content      text             not null default '',                             -- 消息正文
  status       integer          not null default 0,                              -- 消息状态
  readed    smallint            not null default 0,                             --  消息是否已读 0.未读 1.已读
  voice_readed smallint         not null default 0,                             --  语音是否已读 0.未读 1.已读
  extra        text             not null default '',                             -- 扩展数据
  revoke       smallint          not null default 0,                            -- 消息是否被撤回 0.否 1.是
  is_deleted   smallint         not null default 0,                              -- 是否已删除 0.否 1.是
  created_at   timeStamp        not null DEFAULT (datetime('now', 'localtime')), -- 创建时间
  updated_at   timeStamp        not null DEFAULT (datetime('now', 'localtime'))  -- 更新时间
);
CREATE INDEX IF NOT EXISTS idx_message ON message (channel_id, channel_type);
CREATE INDEX IF NOT EXISTS idx_order_seq ON message (order_seq);
CREATE INDEX IF NOT EXISTS idx_content_type ON message (content_type);
CREATE INDEX IF NOT EXISTS idx_message_id ON message (message_id);

-- +migrate StatementBegin
CREATE TRIGGER message_updated_at
  AFTER UPDATE
  ON `message`
  BEGIN
    update `message` SET updated_at = datetime('now') WHERE id = NEW.id;
  END;
-- +migrate StatementEnd

-- 最近会话
create table conversation
(
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_id         VARCHAR(100)      not null default '',                             -- 频道ID
  channel_type       smallint         not null default 0,                              -- 频道类型
  avatar             VARCHAR(255)     not null default '',                            -- 最近会话的头像
  last_client_msg_no VARCHAR(40)      not null default '',                    -- 最后一条消息client_msg_no
  last_msg_timestamp integer          not null default 0,                              -- 最后一条消息时间戳
  unread_count       integer          not null default 0,                              -- 消息未读数量
  browse_to          INTEGER          not null default 0,                              -- 已预览至的message_seq
  reminders          text             not null default '',                              -- 提醒集合 类似 [{type:1,text:@"有人@我",data:{}}]
  extra              text             not null default '',                             -- 扩展数据
  created_at         timeStamp        not null DEFAULT (datetime('now', 'localtime')), -- 创建时间
  updated_at         timeStamp        not null DEFAULT (datetime('now', 'localtime'))  -- 更新时间
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_conversation ON conversation (channel_id, channel_type);

-- +migrate StatementBegin
CREATE TRIGGER conversation_updated_at
  AFTER UPDATE
  ON `conversation`
  BEGIN
    update `conversation` SET updated_at = datetime('now') WHERE id = NEW.id;
  END;
-- +migrate StatementEnd



-- 附件表
create table attachment
(
id                 INTEGER PRIMARY KEY AUTOINCREMENT,
channel_id         VARCHAR(40)      not null default '',                             -- 频道ID
channel_type       smallint         not null default 0,                              -- 频道类型
client_seq         VARCHAR(40)      not null default '',                             -- 消息seq
localPath          VARCHAR(255)     not null default '',                             -- 本地url
remoteUrl          VARCHAR(255)     not null default '',                             -- 远程url
extra              text             not null default '',                             -- 扩展数据
created_at         timeStamp        not null DEFAULT (datetime('now', 'localtime')), -- 创建时间
updated_at         timeStamp        not null DEFAULT (datetime('now', 'localtime'))  -- 更新时间
);

-- +migrate StatementBegin
CREATE TRIGGER attachment_updated_at
AFTER UPDATE
ON `attachment`
BEGIN
update `attachment` SET updated_at = datetime('now') WHERE id = NEW.id;
END;
-- +migrate StatementEnd
