-- 好友请求
create table lim_friend_req(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uid varchar(40) NOT NULL default '',  -- 用户唯一ID
    avatar varchar(255) NOT NULL default '', -- 用户头像
    name  varchar(100)  NOT NULL default '', -- 用户姓名
    remark varchar(100) NOT NULL default '',  -- 备注
    token  varchar(40) NOT NULL default '',  -- 邀请凭证，防止随便添加好友
    status  smallint    NOT NULL default 0,   --  状态 0.等待确认 1.已确认
    readed  smallint    NOT NULL default 0,  -- 是否已读 0.未读 1.已读
    created_at         timeStamp        not null DEFAULT (datetime('now', 'localtime')), -- 创建时间
    updated_at         timeStamp        not null DEFAULT (datetime('now', 'localtime'))  -- 更新时间
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_lim_friend_req ON lim_friend_req (uid);
-- +migrate StatementBegin
CREATE TRIGGER lim_friend_req_updated_at
AFTER UPDATE
ON `lim_friend_req`
BEGIN
update `lim_friend_req` SET updated_at = datetime('now') WHERE id = NEW.id;
END;
-- +migrate StatementEnd
