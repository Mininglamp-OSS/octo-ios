alter table `channel` add column parent_channel_id VARCHAR(40) not null default ''; -- 父类频道ID
alter table `channel` add column parent_channel_type smallint not null default 0; -- 父类频道类型


alter table `conversation` add column parent_channel_id VARCHAR(40) not null default ''; -- 父类频道ID
alter table `conversation` add column parent_channel_type smallint not null default 0; -- 父类频道类型

alter table `message` add column parent_channel_id VARCHAR(40) not null default ''; -- 父类频道ID
alter table `message` add column parent_channel_type smallint not null default 0; -- 父类频道类型

