
-- 将原来message表内的数据迁移到message_extra里

replace into message_extra (message_id,message_seq,channel_id,channel_type,readed,readed_count,unread_count,revoke,revoker,extra_version) select message_id,message_seq,channel_id,channel_type,readed,readed_count,unread_count,revoke,revoker,extra_version from message where message.message_id >0;


