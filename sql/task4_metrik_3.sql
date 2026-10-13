with time_yspeh_reg as( 
select case_id, Max(case when event_category = 'result' and event_name = 'Submit > Response' then timestamp end) as fin_time, 
Min(case when event_category = 'session' and event_name = 'Sign In' then timestamp end) as start_time
from my_database.events 
group by case_id 
having start_time IS NOT NULL AND fin_time IS NOT NULL
),
confirm_case as(
select case_id, fin_time, start_time, 
DATE_FORMAT(start_time, '%Y-%m') as month 
from time_yspeh_reg
where TIMESTAMPDIFF(SECOND, start_time, fin_time) between 1 and 1800
),
filtered_events as (
    select e.case_id, e.timestamp, e.event_name, e.event_property, f.main_form, f.step_order, f.step_name, cc.month
    from my_database.events e
    join confirm_case cc on e.case_id = cc.case_id
    join my_database.form f on e.event_category = f.event_category
    where e.timestamp between cc.start_time and cc.fin_time
),
monthly_total as (
    select month,
    COUNT(*) as total_cases
    from confirm_case
    group by month
),
reached as (
    select month, fe.main_form, COUNT(distinct fe.case_id) as cases_reached
    from filtered_events fe
    group by month, fe.main_form
)
select r.month, f.step_order, f.step_name, mt.total_cases, r.cases_reached, 
       r.cases_reached * 100 / mt.total_cases as conversion_pct
from reached r
join my_database.form f on r.main_form = f.main_form and f.form_type = 'Основная'
join monthly_total mt on r.month = mt.month
order by r.month, f.step_order;
