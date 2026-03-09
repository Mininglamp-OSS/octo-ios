alter table `channel` add column status smallint not null default 0; -- 频道状态 0.正常 2.被拉入黑明单

alter table `conversation` add column is_deleted smallint not null default 0; -- 是否已删除 0.未删除 1.已删除
