create table contacts(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uid varchar(40) NOT NULL default '',  -- 用户唯一ID
    avatar varchar(255) NOT NULL default '', -- 用户头像
    name varchar(100)  NOT NULL default '', -- 用户姓名
    remark varchar(100) NOT NULL default '',  -- 备注
    version bigint     NOT NULL default 0,   -- 数据版本
    created_at varchanr(20) NOT NULL default '', -- 创建时间
    updated_at varchanr(20) NOT NULL default '', -- 更新时间
    is_deleted smallint NOT NULL default 0, -- 是否删除
    status smallint NOT NULL default 0, -- 联系人状态 0.正常 2.黑名单
    extra TEXT NOT NULL default ''  -- 扩展字段
);
