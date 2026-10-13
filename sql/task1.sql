with time_yspeh_reg as( 
select case_id, Max(case when event_category = 'result' and event_name = 'Submit > Response' then timestamp end) as fin_time, 
Min(case when event_category = 'session' and event_name = 'Sign In' then timestamp end) as start_time
from my_database.events 
group by case_id 
HAVING start_time IS NOT NULL AND fin_time IS NOT NULL
),
raz_time as(
select case_id, fin_time, start_time, TIMESTAMPDIFF(SECOND, start_time, fin_time) as diff_time from time_yspeh_reg
where TIMESTAMPDIFF(SECOND, start_time, fin_time) between 1 and 1800
)

select DATE_FORMAT(start_time, '%Y-%m') as month, count(*) as total_yspeh_reg, 
SUM(case when diff_time BETWEEN 1 AND 1800 then 1 else 0 end) as yspeh_reg, 
avg(diff_time) as avg_diff_time 
from raz_time
group by DATE_FORMAT(start_time, '%Y-%m')
order by DATE_FORMAT(start_time, '%Y-%m')
