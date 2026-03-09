
alter table `channel` add column forbidden smallint not null default 0; -- 是否禁言 0.否 1.是

alter table `channel` add column invite smallint not null default 0; -- 群聊邀请确认 0.否 1.是
