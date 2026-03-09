
alter table `message` add column expire bigint not null default 0; -- 消息过期时长
alter table `message` add column expire_at bigint not null default 0; -- 消息过期时间