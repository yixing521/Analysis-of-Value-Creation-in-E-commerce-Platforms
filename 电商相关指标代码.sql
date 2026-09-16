create database ecommerce_test;

-- 数据预处理
-- 新增列
-- 新增date_time列, 数据类型是datetime
-- 新增data列(年-月-日), 数据类型是char
-- 增加新列date_time、dates
alter  table ecommerce_test.o_retailers_trade_user add column date_time datetime null;
update ecommerce_test.o_retailers_trade_user
set date_time=str_to_date(time,'%Y-%m-%d %H') ;
-- %H可以表示0-23;而%h表示0-12
alter table ecommerce_test.o_retailers_trade_user add column dates char(10) null;
update ecommerce_test.o_retailers_trade_user set dates=date(date_time);
desc ecommerce_test.o_retailers_trade_user;
select * from ecommerce_test.o_retailers_trade_user limit 5;

-- 处理重复值
-- 创建新表a，并插入不重复的条数据。
use ecommerce_test;
create table temp_trade like ecommerce_test.o_retailers_trade_user;
insert into temp_trade select distinct * from ecommerce_test.o_retailers_trade_user;

-- 指标体系建设
-- 一、用户指标体系
-- 1. 计算UV、PV指标
select
	dates,
	sum(
	if
	( behavior_type = 1, 1, 0 )) pv,
	count( distinct user_id ) uv,
	count(
	if
	( behavior_type = 1, user_id, null )) / count( distinct user_id ) 访问深度
from
	temp_trade
group by
	dates
order by
	dates;

-- 2.留存率
-- 查询活跃用户数,将查询出的活跃用户数保存到视图中
-- 活跃用户留存
create view active_user_view as
	SELECT
			t1.dates,
			count( DISTINCT t1.user_id ) 活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 1) 次日活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 2) 2日活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 3) 3日活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 4) 4日活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 5) 5日活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 6) 6日活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 7) 7日活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 15) 15日活跃用户数,
			sum(DATEDIFF(t2.dates,t1.dates) = 30) 30日活跃用户数
	FROM
			( SELECT user_id, dates FROM temp_trade GROUP BY user_id, dates ) t1
			LEFT JOIN ( SELECT user_id, dates FROM temp_trade GROUP BY user_id, dates ) t2 ON t1.user_id = t2.user_id
	WHERE
			t2.dates >= t1.dates
	GROUP BY
			t1.dates;

select * from active_user_view;

-- 留存率查询
select
		dates, 活跃用户数,
		CONCAT(round((次日活跃用户数 / 活跃用户数) * 100, 2), '%') 次日留存率,
		CONCAT(round((2日活跃用户数 / 活跃用户数) * 100, 2), '%') 2日留存率,
		CONCAT(round((3日活跃用户数 / 活跃用户数) * 100, 2), '%') 3日留存率,
		CONCAT(round((4日活跃用户数 / 活跃用户数) * 100, 2), '%') 4日留存率,
		CONCAT(round((5日活跃用户数 / 活跃用户数) * 100, 2), '%') 5日留存率,
		CONCAT(round((6日活跃用户数 / 活跃用户数) * 100, 2), '%') 6日留存率,
		CONCAT(round((7日活跃用户数 / 活跃用户数) * 100, 2), '%') 7日留存率,
		CONCAT(round((15日活跃用户数 / 活跃用户数) * 100, 2), '%') 15日留存率,
		CONCAT(round((30日活跃用户数 / 活跃用户数) * 100, 2), '%') 30日留存率
from active_user_view;

-- 3.RFM模型分析
-- R指标部分
-- 查询每个用户的最近一次购买的时间
with user_r as
(select user_id, max((dates)) rec_time
from temp_trade
where behavior_type = 2
group by user_id
order by rec_time desc )
select *from user_r;


-- 根据上述需求给每个用户的R指标进行分层
create view r as
with user_r as
(select user_id, max((dates)) rec_time
from temp_trade
where behavior_type = 2
group by user_id
order by rec_time desc )
select user_id,rec_time,
 case
     when datediff('2019-12-18',rec_time)<=2 then 5
     when datediff('2019-12-18',rec_time)<=4 then 4
     when datediff('2019-12-18',rec_time)<=6 then 3
     when datediff('2019-12-18',rec_time)<=8 then 2
     else 1
end r_val
from user_r;


-- F指标部分
-- 查询每个用户在2019-12-18之前的消费次数
select user_id,
       count(dates) f_num
from temp_trade
where behavior_type=2
group by user_id;

-- 给F指标进行分层
create view f as
with user_f as
    ( select user_id,
       count(dates) f_num
from temp_trade
where behavior_type=2
group by user_id
 )
select user_id,f_num,
       case
        when f_num<=2 then 1
        when f_num<=4 then 2
        when f_num<=6 then 3
        when f_num<=8 then 4
else 5
end f_val
from user_f;

-- 对应户进行价值分层
select r.user_id,r_val,f_val,
       case
           when r_val>( select avg(r_val) from r )and f_val>(select avg(f_val )from f )then '重要高价值客户'
           WHEN r_val < (select avg(r_val) from r) AND f_val > (SELECT avg(f_val) from f) THEN '重要唤回客户'
           WHEN r_val > (select avg(r_val) from r) AND f_val < (SELECT avg(f_val) from f) THEN '重要深耕客户'
           WHEN r_val < (select avg(r_val) from r) AND f_val < (SELECT avg(f_val) from f) THEN '重要挽回客户'

        end  用户分层

from r join f on r.user_id=f.user_id
order by r_val desc ,f_val desc;

-- 二、商品指标体系
-- 商品的点击量、收藏量、加购量、购买次数、购买转化率（该商品的所有用户中有购买转化的用户比）
select item_id,
    sum(behavior_type=1)点击量,
count(if(behavior_type=2,user_id,null)) 成交量,
sum(behavior_type=3)加购量,
sum(behavior_type=4)收藏量,
concat(round((count(if(behavior_type=2,user_id,null))/sum(distinct user_id)),2)*100,'%')购买转化率
    from temp_trade
group by item_id;

-- 对应品类的点击量、收藏量、加购量、购买次数、购买转化率(该商品品类的所有用户中有购买转化的用户比;)
SELECT
		item_category, sum(behavior_type = 1) 点击量,
		sum(behavior_type = 4) 收藏量,
		sum(behavior_type = 3) 加入购物车量,
		count(if(behavior_type = 2, user_id, null)) 成交量,
		concat(round(count(distinct if(behavior_type = 2, user_id, null)) / count(DISTINCT user_id), 2) * 100, '%') 购买转化率
FROM
		temp_trade
GROUP BY
		item_category;

-- 三、平台指标体系
-- 点击次数、收藏次数、加购物⻋次数、购买次数、购买转化(该平台当日的所有用户中有购买转化的用户比)
SELECT
		dates, sum(behavior_type = 1) 点击量,
		sum(behavior_type = 4) 收藏量,
		sum(behavior_type = 3) 加购量,
		sum(behavior_type = 2) 购买次数,
		concat(round((count(distinct if(behavior_type = 2, user_id, null)) / count(distinct user_id)) * 100, 2), '%') 购买转化率
FROM
		temp_trade
GROUP BY
		dates;

-- 行为路径分析
create view path_base_view as
with t as (
SELECT
		user_id, item_id,
		lag(behavior_type, 4) over(partition by user_id, item_id ORDER BY date_time) lag4,
		lag(behavior_type, 3) over(partition by user_id, item_id ORDER BY date_time) lag3,
		lag(behavior_type, 2) over(partition by user_id, item_id ORDER BY date_time) lag2,
		lag(behavior_type, 1) over(partition by user_id, item_id ORDER BY date_time) lag1,
		behavior_type,
		rank() over(partition by user_id, item_id ORDER BY date_time DESC) rk
FROM
		temp_trade
)
select * from t WHERE behavior_type = 2 AND rk = 1;

SELECT
		user_id, item_id,
		CONCAT(IFNULL(lag4, '空'),'-',IFNULL(lag3, '空'),'-',IFNULL(lag2, '空'),'-', IFNULL(lag1, '空'),'-', behavior_type) path
FROM
		path_base_view;


SELECT
		CONCAT(IFNULL(lag4, '空'),'-',IFNULL(lag3, '空'),'-',IFNULL(lag2, '空'),'-', IFNULL(lag1, '空'),'-', behavior_type) path,
		count(distinct user_id) user_count
FROM
		path_base_view
GROUP BY
		CONCAT(IFNULL(lag4, '空'),'-',IFNULL(lag3, '空'),'-',IFNULL(lag2, '空'),'-', IFNULL(lag1, '空'),'-', behavior_type);
