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
    select e.case_id, e.timestamp, e.event_name, e.event_property, f.main_form, f.step_order, f.step_name
    from my_database.events e
    join confirm_case cc on e.case_id = cc.case_id
    join my_database.form f on e.event_category = f.event_category
    where e.timestamp between cc.start_time and cc.fin_time
),
case_depth as (
    select case_id, COUNT(*) as events_count
    from filtered_events
    group by case_id
)
select MIN(events_count) as min_events,
 	   MAX(events_count) as max_events,
       AVG(events_count) as avg_events,
       STDDEV(events_count) as stddev_events
from case_depth;
