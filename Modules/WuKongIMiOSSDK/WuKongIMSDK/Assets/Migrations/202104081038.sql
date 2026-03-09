
alter table `message` add column `revoker` varchar(40) not null default ''; -- 撤回消息的人的uid
alter table `message` add column `extra_version` integer not null default 0; -- 扩展消息的版本号
alter table `message` add column `unread_count` integer not null default 0; -- 未读数量
alter table `message` add column `readed_count` integer not null default 0; -- 已读数量

alter table `message` add column `setting` integer not null default 0; -- 消息设置

alter table `channel` add column `receipt` smallint not null default 0; -- 回执开关
