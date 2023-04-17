-- clean table data
select distinct order_id,customer_id,pizza_id,
case when exclusions ='null' or exclusions ='' then null
	else exclusions
	end as exclusions,
case when extras ='null' or extras='' then null
	else extras
	end as extras,order_time
INTO table customer_orders1 -- create temp clean table
from customer_orders;

--claen tabledata
select order_id,runner_id,
case when pickup_time='null' then null
	else pickup_time
	end as pickup_time,
case when distance= 'null' then null
	when distance like '%km' then trim('km' from distance)
	else distance end as distance,
case when duration like '%mins' then trim('mins' from duration)
	when duration like '%minute' then trim('minute' from duration)
	when duration like '%minutes' then trim('minutes' from duration)
	when duration ='null' then null
	else duration end as duration,
case when cancellation='null' or cancellation='' then null
	else cancellation end as cancellation
into table if not exists runner_orders1	
from runner_orders;	

alter table runner_orders1
alter column distance type double precision
using distance::double precision;

alter table runner_orders1
alter column duration type INT
using duration::integer;

alter table runner_orders1
alter column pickup_time type timestamp
using pickup_time::timestamp without time zone;

select * from runner_orders1; --clean table
select * from customer_orders1;--clean table


--How many pizzas were ordered?
select count(order_id) as no_of_order from customer_orders1;


--How many unique customer orders were made?
select count(distinct(order_id)) as unique_cus from customer_orders1;


--How many successful orders were delivered by each runner?
select ro.runner_id,count(distinct co.order_id)
from customer_orders1 as co
join runner_orders1 ro on co.order_id=ro.order_id
where ro.cancellation is null
group by ro.runner_id
order by 1;


--How many of each type of pizza was delivered?
select pn.pizza_name,count(co.pizza_id) delivered 
from customer_orders1 co
join pizza_names pn on pn.pizza_id=co.pizza_id
join runner_orders1 ro on ro.order_id=co.order_ID
WHERE ro.cancellation is null
group by co.pizza_id,pn.pizza_name
order by 1;


--How many Vegetarian and Meatlovers were ordered by each customer?
select distinct(co.customer_id),pn.pizza_name,count(co.pizza_id) as ordered
from customer_orders1 co
join pizza_names pn on pn.pizza_id=co.pizza_id
group by co.customer_id,pn.pizza_name
order by 1;


--What was the maximum number of pizzas delivered in a single order?
select distinct co.order_id,count(co.pizza_id)
from customer_orders1 co
join runner_orders1 ro on co.order_id=ro.order_id
where ro.cancellation is null
group by co.order_id
order by 2 desc;


--For each customer, how many delivered pizzas had at least 1 change, 
--and how many had no changes?
select co.customer_id,
	sum(case when co.exclusions is null and co.extras is null then 1
		else 0 end) no_change,
	sum(case when co.exclusions is not null or co.extras is not null then 1
	   else 0 end) one_change
from customer_orders1 co
join runner_orders1 ro on ro.order_id=co.order_id
where ro.cancellation is null
group by co.customer_id
order by 1;


--How many pizzas were delivered that had both exclusions and extras?
select co.order_id,co.customer_id,count(pizza_id) both_exlc_extr
from customer_orders1 co
join runner_orders1 ro on ro.order_id=co.order_id
where co.exclusions is not null and co.extras is not null and ro.cancellation is null
group by co.order_id,co.customer_id;


-- What was the total volume of pizzas ordered for each hour of the day?
select date_part('hour',order_time)as hours,
count(order_id) ordered
from customer_orders1 co
group by hours
order by 2 desc;


--What was the volume of orders for each day of the week?
select to_char(order_time, 'Day') as week,count(order_id) ordered
from customer_orders1 co
group by week
order by 2 desc;


--B Runner and Customer Experience

--How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select count(runner_id) signup,
date_trunc('week',registration_date)+interval '4day' week_start
from runners
group by week_start


--What was the average time in minutes it took for each runner to 
--arrive at the Pizza Runner HQ to pickup the order?
select runner_id,
avg(date_part('minute',pickup_time-order_time))::numeric(3,1) avg_time_min
from runner_orders1 ro
join customer_orders1 co on co.order_id=ro.order_id
where cancellation is null
group by runner_id
order by 2


--Is there any relationship between the number of pizzas and 
--how long the order takes to prepare?
select rel_tab.no_pizza_prepare,avg(rel_tab.max_time)::numeric(3,1) avg_time_to_prepare
from(select ro.order_id,count(co.pizza_id) no_pizza_prepare,
	max(date_part('minute',ro.pickup_time-co.order_time))::numeric(3,1) as max_time
	from customer_orders1 co
	join runner_orders1 ro on ro.order_id=co.order_id
	where ro.cancellation is null
	group by ro.order_id) as rel_tab
group by rel_tab.no_pizza_prepare	
order by 1


--What was the average distance traveled for each customer?
select co.customer_id,avg(ro.distance)::numeric(3,1) avg_dist
from customer_orders1 co
join runner_orders1 ro on ro.order_id=co.order_id
where ro.cancellation is null
group by co.customer_id
order by 2 desc;


--What was the difference between the longest and shortest delivery times for all orders?
select (max(duration)-min(duration)) time_diff
from runner_orders1 ro
where cancellation is null


-- what was the average speed for each runner for each delivery and do you notice any trend for these values?
select runner_id,order_id,
	(avg(distance/duration)*60)::numeric(3,1) as speed_KMH
	from runner_orders1 ro
	where cancellation is null
	group by runner_id,order_id;


-- What is the successful delivery percentage for each runner?
select runner_id,(tb.success/tb.total_order::float)*100||('%') delv_rate
from (select runner_id,count(order_id) total_order,
	sum(case when cancellation is null then 1
	else 0 end) as success
	from runner_orders1
	group by runner_id) tb
order by 1


--C. Ingredient Optimisation

-- transform/normalized the table value
select pizza_id,
unnest(string_to_array(toppings,','))::int as toppings
into table pizza_recipes1
from pizza_recipes;
select * from pizza_recipes1;


--What are the mostly common or std ingredients for each pizza?
select topping_name,
count(pizza_id) as pizzas
from pizza_recipes1 r
join pizza_toppings t on t.topping_id=r.toppings
group by topping_name
having count(pizza_id)>=2

--What are the standard ingredients for each pizza?
select n.pizza_name,array_to_string(array_agg(t.topping_name),',') as std_topping
from pizza_names n
join pizza_recipes1 r on r.pizza_id=n.pizza_id
join pizza_toppings t on t.topping_id=r.toppings
group by n.pizza_name


--What was the most commonly added extra?
select extra,pizza_count,topping_name 
from(select
	unnest(string_to_array(extras,','))::int as extra,
	count(pizza_id) as pizza_count
	from customer_orders1
	group by extra) as tp
join pizza_toppings t on t.topping_id=tp.extra
order by 2 desc
limit 1


--What was the most common exclusion?
select exclusion,pizza_count,topping_name 
from(select
	unnest(string_to_array(exclusions,','))::int as exclusion,
	count(pizza_id) as pizza_count
	from customer_orders1
	group by exclusion) as tp
join pizza_toppings t on t.topping_id=tp.exclusion
order by 2 desc
limit 1


--Generate an order item for each record in the customers_orders table in the 
--format of one of the following:
--Meat Lovers
--Meat Lovers - Exclude Beef
--Meat Lovers - Extra Bacon
--Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
with ext as (select tp.order_id,tp.pizza_id,tp.extras,
			array_to_string(array_agg(distinct topping_name),',') as ex_top
			from(select order_id,pizza_id,extras,
				unnest(string_to_array(extras,','))::int as extra
				from customer_orders1) as tp
			join pizza_toppings t on t.topping_id=tp.extra
			group by tp.order_id,tp.pizza_id,tp.extras),

	exl as(select tp.order_id,tp.pizza_id,tp.exclusions,
			array_to_string(array_agg(distinct topping_name),',') as excl_top
			from(select order_id,pizza_id,exclusions,
				unnest(string_to_array(exclusions,','))::int as exclusion
				from customer_orders1 co) as tp
			join pizza_toppings t on t.topping_id=tp.exclusion
			group by tp.order_id,tp.pizza_id,tp.exclusions)
select co.order_id,
--,co.pizza_id,n.pizza_name,
--co.extras,co.exclusions
concat(n.pizza_name,'-Extra '||ex_top,' ','-Exclusion '||excl_top)
from customer_orders1 co
left join ext on ext.order_id=co.order_id and ext.pizza_id=co.pizza_id and ext.extras=co.extras 
left join exl on exl.order_id=co.order_id and exl.pizza_id=co.pizza_id and exl.exclusions=co.exclusions
join pizza_names n on n.pizza_id=co.pizza_id


-- Generate an alphabetically ordered comma separated ingredient list for each pizza order 
--from the customer_orders table and add a 2x in front of any relevant ingredients
with ext as (select tp.order_id,tp.pizza_id,tp.extras,t.topping_id,t.topping_name
			from(select order_id,pizza_id,extras,
						unnest(string_to_array(extras,','))::int as extra
				from customer_orders1) as tp
			join pizza_toppings t on t.topping_id=tp.extra
			group by tp.order_id,tp.pizza_id,tp.extras,t.topping_id,t.topping_name),

	exl as(select tp.order_id,tp.pizza_id,tp.exclusions,t.topping_id,t.topping_name
			from(select order_id,pizza_id,exclusions,
				unnest(string_to_array(exclusions,','))::int as excl
				from customer_orders1) as tp
			join pizza_toppings t on t.topping_id=tp.excl
			group by tp.order_id,tp.pizza_id,tp.exclusions,t.topping_id,t.topping_name),
			
	ord as (select co.order_id,co.pizza_id,
			   t.topping_id,t.topping_name
		   from customer_orders1 co
		   join pizza_recipes1 r on r.pizza_id=co.pizza_id
		   join pizza_toppings t on t.topping_id=r.toppings),
		   
	ord_with_ex_el as (select o.order_id,o.pizza_id,
							o.topping_id,o.topping_name 
		    			from ord o
						left join exl on exl.order_id=o.order_id and exl.pizza_id=o.pizza_id and
						exl.topping_id=o.topping_id
						where exl.topping_id is null
					union all
						select order_id,pizza_id,
								topping_id,topping_name
						from ext),--select * from ord_with_ex_el	
	
	final as (select o.order_id,n.pizza_name,
			case when count(topping_id)>1 then count(topping_id)||'x'|| topping_name
			else topping_name end
			from ord_with_ex_el o
			join pizza_names n on n.pizza_id=o.pizza_id
			group by o.order_id,o.pizza_id,o.topping_name,n.pizza_name
			order by 1,2,3)--select * from final
	select order_id,
	concat(pizza_name,':- ',STRING_AGG(topping_name,','))
	from final
	group by order_id,pizza_name;


--What is the total quantity of each ingredient used in all delivered pizzas 
--sorted by most frequent first?
with ext as (select tp.order_id,tp.pizza_id,tp.extras,t.topping_id,t.topping_name
			from(select order_id,pizza_id,extras,
				unnest(string_to_array(extras,','))::int as extra
				from customer_orders1) as tp
			join pizza_toppings t on t.topping_id=tp.extra
			group by tp.order_id,tp.pizza_id,tp.extras,t.topping_id,t.topping_name),

	exl as(select tp.order_id,tp.pizza_id,tp.exclusions,t.topping_id,t.topping_name
			from(select order_id,pizza_id,exclusions,
				unnest(string_to_array(exclusions,','))::int as excl
				from customer_orders1) as tp
			join pizza_toppings t on t.topping_id=tp.excl
			group by tp.order_id,tp.pizza_id,tp.exclusions,t.topping_id,t.topping_name),
			
	ord as (select co.order_id,co.pizza_id,
			t.topping_id,t.topping_name
		   from customer_orders1 co
		   join pizza_recipes1 r on r.pizza_id=co.pizza_id
		   join pizza_toppings t on t.topping_id=r.toppings),
		   
	ord_with_ex_el 
		as(select o.order_id,o.pizza_id,
			o.topping_id,o.topping_name 
		    from ord o
			left join exl on exl.order_id=o.order_id and exl.pizza_id=o.pizza_id and
			exl.topping_id=o.topping_id
			where exl.topping_id is null
		union all
			select order_id,pizza_id,
			topping_id,topping_name
			from ext)
		select topping_name,count(topping_id) cn
		from ord_with_ex_el o
		join runner_orders1 ro on ro.order_id=o.order_id
		where cancellation is null
		group by topping_name
		order by 2 desc;
		
--D. Pricing and Ratings

--If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and 
--there were no charges for changes how much money has Pizza Runner made so far if there are no delivery fees?
select
sum(case when pizza_id=1 then 12 
	else 10
   end) total_amt
from customer_orders1 co
join runner_orders1 ro on ro.order_id=co.order_id
where cancellation is null;


--What if there was an additional $1 charge for any pizza extras?
with ext as (select tp.order_id,tp.pizza_id,extra,extras
			from(select order_id,pizza_id,extras,
				unnest(string_to_array(extras,','))::int as extra
				from customer_orders1 co) as tp
			join pizza_toppings t on t.topping_id=tp.extra
			group by tp.order_id,tp.pizza_id,extra,extras),
	 --select *from ext
	t1 as (select co.order_id,co.pizza_id,e.extras,
		count(distinct e.extra) ei from customer_orders1 co
		left join ext e on e.order_id=co.order_id and e.extras=co.extras
		group by co.order_id,co.pizza_id,e.extras
		order by 1)
	select * from t1
select t2.total_pizza_amt,t2.ex_amt,
(t2.ex_amt+t2.total_pizza_amt) as total_amt
from (select sum(case when t1.pizza_id=1 then 12 
			else 10
   			end) total_pizza_amt,
	   		sum(case when t1.ei=1 then 1 
		    when t1.ei>1 then 2 
		    else 0 end) ex_amt
from t1
join runner_orders1 ro on ro.order_id=t1.order_id
where ro.cancellation is null) t2;


--The Pizza Runner team now wants to add an additional ratings system that allows 
--customers to rate their runner, how would you design an additional table for this new dataset
-- generate a schema for this new table and insert your own data for ratings for 
--each successful customer order between 1 to 5.
drop table if exists runner_rating;
create table runner_rating (
order_id int,
rating int);
insert into runner_rating (order_id, rating)
values
  (1,3),
  (2,5),
  (3,3),
  (4,1),
  (5,5),
  (7,3),
  (8,4),
  (10,3);
select *from runner_rating;
 

--. Using your newly generated table — can you join all of the information together 
--to form a table which has the following information for successful deliveries?
select co.customer_id,co.order_id,ro.runner_id,--rating,
co.order_time,ro.pickup_time,
date_part('minute',ro.pickup_time-co.order_time)::numeric(3,1) as time_diff_min,
ro.duration,
avg(distance/duration)::numeric(4,2)*60 as avg_speed,
count(co.order_id) as no_pizza
from customer_orders1 co
join runner_orders1 ro on co.order_id=ro.order_id
where ro.cancellation is null
group by co.customer_id,co.order_id,ro.runner_id,--rating,
co.order_time,ro.pickup_time,ro.duration
order by co.customer_id,co.order_id


--If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and 
--each runner is paid $0.30 per kilometre traveled
-- how much money does Pizza Runner have left over after these deliveries?
select t1.total_amt,t1.runner_paid,
(t1.total_amt-t1.runner_paid) as amt_aft_deliver
from(select
		sum(case when pizza_id=1 then 12 
		else 10
   		end) total_amt,
		sum (0.30*distance)::numeric(3,1) runner_paid
		from customer_orders1 co
	join runner_orders1 ro on ro.order_id=co.order_id
	where cancellation is null) t1;
