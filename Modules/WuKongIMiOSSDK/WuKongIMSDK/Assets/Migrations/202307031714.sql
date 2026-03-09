
-- 流式数据表
create table stream
(
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id    VARCHAR(100)      not null default '',                           -- 频道ID
    channel_type  smallint         not null default 0,                             -- 频道类型
    client_msg_no VARCHAR(80)      not null default '',                            -- 客户端消息编号
    stream_no    VARCHAR(80)      not null default '',                             -- 流编号
    stream_seq   UNSIGNED BIG INT not null default 0,                              -- 流序号
    content      text             not null default ''                             -- 流正文
);
CREATE UNIQUE INDEX IF NOT EXISTS uidx_stream ON stream (channel_id,channel_type,stream_no,stream_seq);
CREATE INDEX IF NOT EXISTS idx_stream_channel ON stream (channel_id,channel_type);
CREATE INDEX IF NOT EXISTS idx_stream_streamno ON stream (stream_no);


alter table `message` add column stream_no VARCHAR(80) not null default ''; -- 流式编号
