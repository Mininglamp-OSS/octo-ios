-- 机器人表
create table robot
(
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    robot_id   VARCHAR(40)      not null default '',     -- 机器人id（也是uid）
    version       bigint       NOT NULL default 0,       -- 版本号
    status      INTEGER          NOT NULL default 1,     -- 机器人状态 0.禁用 1.启用
    menus        text           NOT NULL default ''      -- 菜单json
);
CREATE UNIQUE INDEX IF NOT EXISTS robot_idx ON robot(robot_id);

alter table `channel` add column robot smallint not null default 0; -- 是否是机器人
alter table `channel_member` add column robot smallint not null default 0; -- 是否是机器人

