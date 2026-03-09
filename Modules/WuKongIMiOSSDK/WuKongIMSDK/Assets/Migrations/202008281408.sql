
alter table `channel` add column online smallint not null default 0; -- 是否在线 0.不在线 1.在线
alter table `channel` add column last_offline INTEGER not null default 0; -- 最后一次离线时间
