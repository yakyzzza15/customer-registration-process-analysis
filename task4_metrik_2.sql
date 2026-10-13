with time_yspeh_reg as( 
select case_id, Max(case when event_category = 'result' and event_name = 'Submit > Response' then timestamp end) as fin_time, 
Min(case when event_category = 'session' and event_name = 'Sign In' then timestamp end) as start_time
from my_database.events 
group by case_id 
having start_time IS NOT NULL AND fin_time IS NOT NULL
),
confirm_case as(
select case_id, fin_time, start_time from time_yspeh_reg
where TIMESTAMPDIFF(SECOND, start_time, fin_time) between 1 and 1800
),
filtered_events as (
    select e.case_id, e.timestamp, f.main_form, cc.start_time
    from my_database.events e
    join confirm_case cc on e.case_id = cc.case_id
    join my_database.form f on e.event_category = f.event_category
    where e.timestamp between cc.start_time and cc.fin_time
),
event_next as (
    select case_id, timestamp, main_form, start_time,
           LEAD(timestamp) OVER (partition by case_id order by timestamp) as next_timestamp 
    from filtered_events
),
time_per_form_per_case as (
    select case_id, main_form, DATE_FORMAT(start_time, '%Y-%m') as month,
           SUM(TIMESTAMPDIFF(SECOND, timestamp, next_timestamp)) AS time_on_form
    from event_next
    where next_timestamp IS NOT NULL
    group by case_id, main_form, DATE_FORMAT(start_time, '%Y-%m')
)
select t.month, f.step_order, f.step_name, COUNT(*) AS case_count,
       AVG(t.time_on_form) AS avg_time_on_form
from time_per_form_per_case t
join my_database.form f on t.main_form = f.event_category
GROUP BY t.month, f.step_order, f.step_name
ORDER BY t.month, f.step_order;