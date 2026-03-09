alter table `message_extra` add column readed_at integer not null default ''; -- 已读时间
alter table `message` add column flame smallint not null default 0; -- 是否开启阅后即焚
alter table `message` add column flame_second integer not null default 0; -- 阅后即焚秒数

alter table `message` add column viewed smallint not null default 0;    -- 是否已查看 0.未查看 1.已查看 （这个字段跟已读的区别在于是真正的查看了消息内容，比如图片消息 已读是列表滑动到图片消息位置就算已读，viewed是表示点开图片才算已查看，语音消息类似）
alter table `message` add column viewed_at integer not null default 0;  -- 查看时间戳

alter table `channel` add column flame smallint not null default 0; -- 是否开启阅后即焚
alter table `channel` add column flame_second integer not null default 0; -- 阅后即焚秒数

CREATE UNIQUE INDEX IF NOT EXISTS uidx_channel_member_uid ON channel_member (channel_id, channel_type,member_uid);

CREATE  INDEX IF NOT EXISTS idx_channel_member_version ON channel_member (channel_id, channel_type,version); -- 成员表增加索引
