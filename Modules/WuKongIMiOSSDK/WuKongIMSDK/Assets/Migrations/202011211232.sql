
-- cmd表
create table cmd
(
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id   UNSIGNED BIG INT not null default 0,                              -- 消息ID
  message_seq  UNSIGNED BIG INT not null default 0,                              -- 消息序列号(非严格递增)
  client_msg_no VARCHAR(40)      not null default '',                             -- 客户端消息编号（去重用）
  timestamp    integer          NOT NULL default 0,                              -- 服务器消息时间戳(10位，到秒)
  cmd           VARCHAR(40)      not null default '',                            -- cmd命令
  param        text             not null default '',                             -- cmd参数
  is_deleted   smallint         not null default 0,                              -- 是否已删除 0.否 1.是
  created_at   timeStamp        not null DEFAULT (datetime('now', 'localtime')) -- 创建时间
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_client_msg_no_cmd ON cmd (client_msg_no);
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_id_cmd ON cmd (message_id);
