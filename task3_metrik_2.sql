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
reached as (
    select fe.main_form, COUNT(distinct fe.case_id) as cases_reached
    from filtered_events fe
    group by fe.main_form
),
backs as (
    select fe.main_form,
		   COUNT(*) as back_clicks,                          
           COUNT(distinct fe.case_id) as cases_with_back
    from filtered_events fe
    where fe.event_name = 'Click > Back'
    group by fe.main_form
)
select f.step_order, f.step_name, r.cases_reached,
       COALESCE(b.back_clicks, 0) as back_clicks,
       COALESCE(b.cases_with_back, 0) as cases_with_back,
       COALESCE(b.back_clicks, 0) * 100 / r.cases_reached as back_rate_pct
from reached r
join my_database.form f on r.main_form = f.main_form and f.form_type = 'Основная'
left join backs b on r.main_form = b.main_form
order by step_order;