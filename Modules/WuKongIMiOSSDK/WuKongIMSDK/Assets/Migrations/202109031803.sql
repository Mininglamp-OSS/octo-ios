-- 身份表
create table identities
(
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  address          text  NOT NULL default '',                  -- 身份地址
  registration_id  INTEGER     NOT NULL default 0,             -- 身份注册ID
  public_key     text         NOT NULL,                        -- 公钥
  private_key    text         NOT NULL,                        -- 私钥
  next_prekey_id  BIG INT NOT NULL default 0,                  -- 密钥ID
  `timestamp`     REAL      NOT NULL default 0                 -- 密钥生成时间
);
CREATE UNIQUE INDEX IF NOT EXISTS identities_index_id ON identities(address);


create table prekeys(
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    pre_key_id     INTEGER NOT NULL default 0,
    record         text         NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS prekeys_index_id ON prekeys(pre_key_id);


create table ratchet_sender_keys(
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id        text  NOT NULL default '',
    sender_id       text  NOT NULL default '',
    status          text  NOT NULL default ''
);
CREATE UNIQUE INDEX IF NOT EXISTS ratchet_sender_keys_index_id ON ratchet_sender_keys(group_id,sender_id);


create table sender_keys(
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id        text  NOT NULL default '',
    sender_id       text  NOT NULL default '',
    record         text         NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS sender_keys_index_id ON sender_keys(group_id,sender_id);


create table sessions(
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    address text  NOT NULL default '',
    device  INTEGER  NOT NULL default 0,
    record         text         NOT NULL,
    `timestamp`     REAL      NOT NULL default 0
);


create table signed_prekeys(
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    pre_key_id     INTEGER NOT NULL default 0,
    record         text         NOT NULL,
    `timestamp`     REAL      NOT NULL default 0
);
