
alter table `robot` add column inline_on smallint not null default 0; -- 是否支持行内搜索

alter table `robot` add column placeholder VARCHAR(255) not null default ''; -- 如果支持行内搜索 则占位字符内容

alter table `robot` add column username VARCHAR(40) not null default ''; -- 机器人username
