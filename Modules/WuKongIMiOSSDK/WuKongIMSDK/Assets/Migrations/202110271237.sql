
alter table `channel` add column be_deleted smallint not null default 0; -- 是否被删除
alter table `channel` add column be_blacklist smallint not null default 0; -- 是否被拉入黑名单

