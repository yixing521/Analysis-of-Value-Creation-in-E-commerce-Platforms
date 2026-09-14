-- 数据预处理
-- 新增列
-- 1.新增date_time列, 数据类型是datetime
-- 2.新增dates列(年-月-日), 数据类型是char
-- 增加新列date_time、dates
alter table dian_shang_an_li_shu_ju add column date_time datetime null;
update dian_shang_an_li_shu_ju
set date_time =str_to_date(time,'%Y-%m-%d %H') ;
-- %H可以表示0-23;而%h表示0-12
alter table dian_shang_an_li_shu_ju add column dates char(10) null;
update dian_shang_an_li_shu_ju
set dates=date(date_time);
desc dian_shang_an_li_shu_ju;
select * from dian_shang_an_li_shu_ju limit 5;
-- 处理重复值
-- 创建新表插入非重复数据
create table d_s like dian_shang_an_li_shu_ju;
insert into  d_s select  distinct * from dian_shang_an_li_shu_ju;