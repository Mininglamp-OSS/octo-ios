-- 通讯录好友
create table contacts_friend(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name varchar(100)  NOT NULL default '', -- 姓名
    phone varchar(30)  NOT NULL default '' -- 手机号
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_phone ON contacts_friend (phone);
