alter table `conversation` add column last_message_seq UNSIGNED BIG INT not null default 0; -- 最后一条消息的message_seq
