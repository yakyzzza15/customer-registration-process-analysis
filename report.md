# Анализ процесса регистрации клиентов
Представим, что владельцы продукта/процесса жили без аналитики, и вот в команде появляется аналитик данных, который наконец-то покажет как ведет себя процесс, подсветит проблемные зоны, сообщит что изменилось за последние 7 месяцев с указанием «в лучшую» или «в худшую» сторону произошли изменения и почему. Аналитика должна представлять из себя набор графиков/диаграмм или табличных форм с пояснениями и выводами. Графики будут оцениваться по визуализации и содержимому, чтобы они были понятны бизнес-пользователям
### Инструменты
- MySQL (DBeaver) — расчёты
- Power BI — визуализация
- Python (PyCharm) — преобразование исходной таблицы
### Структура
- `tasks` — исходное задание
- `sql` — SQL-запросы по заданиям
- `python` — Python-запрос по заданию
- `data` — выгрузки результатов
- `docs` — файлы, которые создавал в процессе
- `powerbi` — дашборд

### Задание 1: Динамика по месяцам
Показать в динамике по месяцам:
1) количество успешных регистраций
2) среднее время процесса успешной регистрации.

При расчете среднего времени нужно исключать выбросы, в рамках задачи будем считать за выбросы регистрации, которые длятся более 30 минут

#### Решение:

Для начала проанализирую форматы строк. Дата и время записаны строками в нестандартой форме, поэтому для удобства импорта, используя Python, приведу их стандартному виду:

```python

import pandas as pd


INPUT_FILE = r'C:\Users\User\Desktop\Тестовое задание\dataset.csv'# путь к исходнику
OUTPUT_FILE = r'C:\Users\User\Downloads\dataset_fixed1.csv'# куда сохранить исправленный

df = pd.read_csv(INPUT_FILE, sep=';', dtype=str) # чтение файла

df['TIMESTAMP'] = pd.to_datetime(
    df['TIMESTAMP'], 
    format='%d.%m.%y %H:%M:%S,%f', 
    errors='coerce'
) # исправление timestamp
df['TIMESTAMP'] = df['TIMESTAMP'].dt.strftime('%Y-%m-%d %H:%M:%S.%f')

df['TIMESTAMP_DAY'] = pd.to_datetime(
    df['TIMESTAMP_DAY'], 
    format='%d.%m.%Y', 
    errors='coerce'
) # исправление timestamp_day
df['TIMESTAMP_DAY'] = df['TIMESTAMP_DAY'].dt.strftime('%Y-%m-%d')

df.to_csv(OUTPUT_FILE, index=False, encoding='utf-8') # сохранение
print('ready', OUTPUT_FILE)
```
Далее импортирую исправленную таблицу в DBeaver, исправлю типы данных на необходимые и поменяю название

Проверю вид исправленной таблицы и посмотрю количество строк
```sql
Select * from my_database.events
limit 20;
```
**Результат:**

|timestamp|timestamp_day|employee_id|case_id|event_category|event_name|event_property|
|---------|-------------|-----------|-------|--------------|----------|--------------|
|2024-01-11 14:57:19.646000|2024-01-11|2167193964|659fd71c83c9203126a7e90a|summary|Submit > Response||
|2024-01-11 17:05:40.014000|2024-01-11|2167193964|659ff53053858648a60d861a|summary|Submit > Response||
|2024-01-11 07:06:10.261000|2024-01-11|3712217667|659f67076743b31d8bbf7001|summary|Submit > Response||
|2024-01-11 13:09:54.309000|2024-01-11|3712217667|659fbdd9232ba543279bc860|summary|Submit > Response||
|2024-01-11 12:04:31.848000|2024-01-11|1427323230|659fae3383c9203126a7e861|summary|Submit > Response||
|2024-01-11 14:31:05.843000|2024-01-11|1427323230|659fd06702d7967b3c1d7de0|summary|Submit > Response||
|2024-01-11 10:35:20.753000|2024-01-11|3061131108|659f98f102d7967b3c1d7ce0|summary|Submit > Response||
|2024-01-11 12:25:51.257000|2024-01-11|3061131108|659fb33183c9203126a7e87f|summary|Submit > Response||
|2024-01-11 17:55:23.988000|2024-01-11|3437336231|65a0005d53858648a60d863b|summary|Submit > Response||
|2024-01-11 13:46:59.536000|2024-01-11|4135849837|659fc694bbe4365dc0663bc3|summary|Submit > Response||
|2024-01-11 16:17:37.866000|2024-01-11|4135849837|659fe877232ba543279bc914|summary|Submit > Response||
|2024-01-11 17:34:47.602000|2024-01-11|4135849837|659ffbaf83c9203126a7e996|summary|Submit > Response||
|2024-01-11 19:29:55.015000|2024-01-11|4135849837|65a016f5bbe4365dc0663cd1|summary|Submit > Response||
|2024-01-10 13:30:43.812000|2024-01-10|1317783931|659e704a8936952d67311937|employment|Click > Submit|Не трудоустроен|
|2024-01-10 15:23:32.352000|2024-01-10|1317783931|659e8c0883c9203126a7e6d6|employment|Click > Submit|Не трудоустроен|


```sql
Select count(*) from my_database.events;
```
**Результат:**
4 401 659

Теперь можно приступить к заданию.

Для начала хочу проанализировать: что должен содержать фактор успешной регистрации? Старт, вход, финиш и выход. Если чего-то нету, то регистрация либо не завершилась, либо данные сломались по пути.

Время всего процесса буду считать, как разницу по времени между концом и началом регистрации.

Как выяснилось позже, у некоторых есть несколько входов и завершений, буду брать самый ранний вход и самый поздний успешный выход

Посчитаем также количество успешных регистраций с выбросами и количество успешных регистраций без выбросов (пригодиться в анализе)

Дальше найду для каждого пользователя по их case_id время начала и конца регистрации и не null

```sql
select case_id, Max(case when event_category = 'result' and event_name = 'Submit > Response' then timestamp end) as fin_time, 
Min(case when event_category = 'session' and event_name = 'Sign In' then timestamp end) as start_time
from my_database.events e 
group by case_id 
having start_time IS NOT NULL AND fin_time IS NOT NULL;
```
**Результат:**

|case_id|fin_time|start_time|
|-------|--------|----------|
|0B998ECD87A22C34E0643863BB4C2866|2024-01-10 07:40:27.654000|2024-01-10 07:35:09.088000|
|0CC75710ADE84CCFE0643863BB4C2866|2024-01-30 15:28:30.238000|2024-01-30 15:21:48.491000|
|0CF2884361182571E0643863BB4C2866|2024-01-09 16:24:26.233000|2024-01-09 16:20:24.337000|
|0DA0C1B4222E4BC3E0643863BB4C2866|2024-01-18 09:34:07.681000|2024-01-18 09:15:59.861000|
|0DA869811D4E23C7E0643863BB4C2866|2024-01-10 11:29:42.363000|2024-01-10 11:15:50.307000|
|...|...|...|

Всё супер, получился отличный CTE для нахождения разницы времен.

Теперь посчитаем длительность, которая входит в диапазон 30 минут
```sql
with time_yspeh_reg as( 
select case_id, Max(case when event_category = 'result' and event_name = 'Submit > Response' then timestamp end) as fin_time, 
Min(case when event_category = 'session' and event_name = 'Sign In' then timestamp end) as start_time
from my_database.events 
group by case_id 
having start_time IS NOT NULL AND fin_time IS NOT NULL
)

select case_id, fin_time, start_time, TIMESTAMPDIFF(SECOND, start_time, fin_time) as diff_time from time_yspeh_reg
where TIMESTAMPDIFF(SECOND, start_time, fin_time) between 1 and 1800;
```
**Результат:**

|case_id|fin_time|start_time|diff_time|
|-------|--------|----------|---------|
|0B998ECD87A22C34E0643863BB4C2866|2024-01-10 07:40:27.654000|2024-01-10 07:35:09.088000|318|
|0CC75710ADE84CCFE0643863BB4C2866|2024-01-30 15:28:30.238000|2024-01-30 15:21:48.491000|401|
|0CF2884361182571E0643863BB4C2866|2024-01-09 16:24:26.233000|2024-01-09 16:20:24.337000|241|
|0DA0C1B4222E4BC3E0643863BB4C2866|2024-01-18 09:34:07.681000|2024-01-18 09:15:59.861000|1087|
|0DA869811D4E23C7E0643863BB4C2866|2024-01-10 11:29:42.363000|2024-01-10 11:15:50.307000|832|
|...|...|...|...|

Отлично, теперь готов второй CTE.

Теперь нужно сгруппировать по месяцам, подсчитать среднее и добавить количество успешных регистраций, учитывая те, которые НЕ вышли из 30 минут. Если вдруг регистрация началась в прошлом месяце, а закончилась в следующем, то будем приписывать будем к прошлому месяцу.
```sql
with time_yspeh_reg as( 
select case_id, Max(case when event_category = 'result' and event_name = 'Submit > Response' then timestamp end) as fin_time, 
Min(case when event_category = 'session' and event_name = 'Sign In' then timestamp end) as start_time
from my_database.events 
group by case_id 
having start_time IS NOT NULL AND fin_time IS NOT NULL
),
raz_time as(
select case_id, fin_time, start_time, TIMESTAMPDIFF(SECOND, start_time, fin_time) as diff_time from time_yspeh_reg
where TIMESTAMPDIFF(SECOND, start_time, fin_time) between 1 and 1800
)

select DATE_FORMAT(start_time, '%Y-%m') as month, count(*) as yspeh_reg, avg(diff_time) as avg_diff_time from raz_time
group by DATE_FORMAT(start_time, '%Y-%m')
order by DATE_FORMAT(start_time, '%Y-%m')
```
**Результат:**

|month|yspeh_reg|avg_diff_time|
|-----|---------|-------------|
|2024-01|14295|416.2031|
|2024-02|16865|417.8840|
|2024-03|18021|413.6884|
|2024-04|18230|411.5779|
|2024-05|19203|407.6373|
|2024-06|18297|411.6657|
|2024-07|20831|413.1168|

По сути это и есть решение первого задания, но я хочу добавить в таблицу количество успешных регистраций без учета выбросов.

Чтобы это сделать из моей CTE raz_time я уберу условие на нахождение выбросов и перенесу его в итоговый select
```sql
with time_yspeh_reg as( 
select case_id, Max(case when event_category = 'result' and event_name = 'Submit > Response' then timestamp end) as fin_time, 
Min(case when event_category = 'session' and event_name = 'Sign In' then timestamp end) as start_time
from my_database.events 
group by case_id 
having start_time IS NOT NULL AND fin_time IS NOT NULL
),
raz_time as(
select case_id, fin_time, start_time, TIMESTAMPDIFF(SECOND, start_time, fin_time) as diff_time from time_yspeh_reg
where TIMESTAMPDIFF(SECOND, start_time, fin_time) between 1 and 1800
)

select DATE_FORMAT(start_time, '%Y-%m') as month, count(*) as total_yspeh_reg, 
SUM(case when diff_time between 1 and 1800 then 1 else 0 end) as yspeh_reg, 
avg(diff_time) as avg_diff_time 
from raz_time
group by DATE_FORMAT(start_time, '%Y-%m')
order by DATE_FORMAT(start_time, '%Y-%m')
```
**Результат:**

|month|total_yspeh_reg|yspeh_reg|avg_diff_time|
|-----|---------------|---------|-------------|
|2024-01|14338|14295|416.2031|
|2024-02|16912|16865|417.8840|
|2024-03|18079|18021|413.6884|
|2024-04|18303|18230|411.5779|
|2024-05|19260|19203|407.6373|
|2024-06|18361|18297|411.6657|
|2024-07|20901|20831|413.1168|

#### Что мы имеем
1) Выбросов совсем немного, всего 0,2% в среднем, значит, что долгих регистраций почти нет и интерфейс понятен для пользователей.
2) Объем регистраций растет, рост за 7 месяцев примерно 46%. Это отличный результат, который может быть связан с сезонностью, расширением штата или улучшением процессов в целом
3) Среднее время довольно стабильное, в среднем около 7 минут, тренда нету.

**Визуализация по заданию представлена в аналитическом отчете в папке PowerBI**

### Задание 2: Детализация по формам
Детализировать среднее время процесса успешной регистрации на 12 основных экранных форм (справочник форм представлен в конце файла). 

Учитывайте, что в процессе регистрации возможны возвращения на предыдущие экранные формы => можно проходить одну экранную форму несколько раз. Список экранных форм указан ниже в справочнике. Сумма времени по экранным формам должна сходиться к общему времени процесса из задания 1. При расчете времени шага также нужно исключать регистрации, которые длятся более 30 минут.

#### Решение:
Итак, наши события result и session не находятся ни в одной форме и, по сути, являются системными, а время между ними должно сходиться с суммой времени по экранным формам. Из логики, чтобы сумма между 1 и 12 этапом сходилась с разницей result и session отнесу session к первой форме, так как после начала сессии пользователь сразу делать первое действие на форме main. А result отнесем к последней форме docsUpload, так как это последнее действие пользователя, которое характеризует окончание процесса.

Для решения я создам новую таблицу, которую назову form, а заполню я ее данными из справочника основных экранных форм и добавлю дополнительные формы из описания событий и свяжу их с соответствующими основными формами.

**Таблица form**

| event_category  | main_form       | step_name                              | step_order | form_type      |
|-----------------|-----------------|----------------------------------------|------------|----------------|
| main            | main            | Персональные данные                    | 1          | Основная       |
| identification  | identification  | Идентификация паспортных данных        | 2          | Основная       |
| taxResidentInfo | taxResidentInfo | Резидент или информация о нерезиденте  | 3          | Основная       |
| addresses       | addresses       | Адреса                                 | 4          | Основная       |
| employment      | employment      | Занятость                              | 5          | Основная       |
| contacts        | contacts        | Контактная информация                  | 6          | Основная       |
| servicePackage  | servicePackage  | ПУ и счета                             | 7          | Основная       |
| cards           | cards           | Заказ именных карт                     | 8          | Основная       |
| accessCard      | accessCard      | Моментальная выдача карты              | 9          | Основная       |
| summary         | summary         | Проверка данных и подписание черновика | 10         | Основная       |
| questionnaire   | questionnaire   | Подписание анкеты                      | 11         | Основная       |
| docsUpload      | docsUpload      | Прикрепление документов                | 12         | Основная       |
| cardsDelivery   | cards           | Оформление доставки именных карт       | 8          | Дополнительная |
| nonResidentInfo | taxResidentInfo | Ввод информации по нерезидентам        | 3          | Дополнительная |
| confirm         | summary         | Ввод кода из СМС для подписания        | 10         | Дополнительная |
| session         | main            | Старт процесса регистрации             | 1          | Системное      |
| result          | docsUpload      | Завершение процесса                    | 12         | Системное      |

Далее импортирую таблицу в DBeaver и проверяю все ли хорошо

```sql
Select * from my_database.form
```
Таблица получилась такой же

Так как при расчете все также необходимо исключать регистрации, которые длятся более 30 минут и в итоге сравнить с общим временем процесса, то воспользуюсь CTE, которые я писал в задании 1. Единственное, что нет необходимости считать разницу времен во второй CTE, ну и название тогда лучше поменять (для удобства)

```sql
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
)
```
Хорошо, теперь все регистрации удовлетворяют нашим условиям по окончанию и выбросам. Теперь нам нужно подключить новую таблицу form и выведем из нее наши основные формы, заодно учтем, чтобы все времена лежали внутри начала и конца (а то вдруг что-то заллогалось).

```sql
filtered_events as (
    select e.case_id, e.timestamp, f.main_form
    from my_database.events e
    join confirm_case cc on e.case_id = cc.case_id
    join my_database.form f on e.event_category = f.event_category
    where e.timestamp between cc.start_time and cc.fin_time
)
```
Теперь у нас есть события, которые относятся к правильной регистрации, и все они знают к какой из форм они отнесены.

Чтобы понять, как события идут друг за другом будем использовать оконные функции, а точнее функцию смещения – lead, которая вернет значение из столбца вперед на n записей (в нашем случае на 1).

```sql
event_next as (
    select case_id, timestamp, main_form,
           LEAD(timestamp) OVER (partition by case_id order by timestamp) as next_timestamp 
    from filtered_events 
)
```
Теперь, зная время на текущем и следующим за ним событием можем посчитать время по каждой форме для каждого кейса. Не забываем, что последняя строка next_timestamp будет null, что логично, ведь за result ничего нет, надо это учесть. Также пользователь мог возвращаться на форму ни один раз, поэтому разницу времен будем суммировать. 

```sql
time_per_form_per_case as (
    select case_id, main_form,
           SUM(TIMESTAMPDIFF(SECOND, timestamp, next_timestamp)) AS time_on_form
    from event_next
    where next_timestamp IS NOT NULL
    group by case_id, main_form
)
```
Теперь мы знаем, сколько времени на каждой форме провел каждый пользователь. Отлично, значит, наконец-то, мы можем посчитать среднее по каждой форме, чтобы понимать какая форма где, придется снова подсоединить таблицу form, где мы сможем взять названия формы, ее номер. Также я хочу вывести количество кейсов, которые вообще дошли до каждой формы (понять где происходит обрыв).

```sql
select f.step_order, f.step_name, COUNT(*) AS case_count,
       AVG(t.time_on_form) AS avg_time_on_form
from time_per_form_per_case t
join my_database.form f on t.main_form = f.event_category
GROUP BY f.step_order, f.step_name
ORDER BY f.step_order
```
Итоговый запрос:

```sql
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
    select e.case_id, e.timestamp, f.main_form
    from my_database.events e
    join confirm_case cc on e.case_id = cc.case_id
    join my_database.form f on e.event_category = f.event_category
    where e.timestamp between cc.start_time and cc.fin_time
),
event_next as (
    select case_id, timestamp, main_form,
           LEAD(timestamp) OVER (partition by case_id order by timestamp) as next_timestamp 
    from filtered_events
),
time_per_form_per_case as (
    select case_id, main_form,
           SUM(TIMESTAMPDIFF(SECOND, timestamp, next_timestamp)) AS time_on_form
    from event_next
    where next_timestamp IS NOT NULL
    group by case_id, main_form
)
select f.step_order, f.step_name, COUNT(*) as case_count,
       AVG(t.time_on_form) as avg_time_on_form
from time_per_form_per_case t
join my_database.form f on t.main_form = f.event_category
group by f.step_order, f.step_name
order by f.step_order;
```
**Результат:**

|step_order|step_name|case_count|avg_time_on_form|
|----------|---------|----------|----------------|
|1|Персональные данные|125742|61.3181|
|2|Идентификация паспортных данных|125740|9.6742|
|3|Резидент или информация о нерезиденте|125740|40.4218|
|4|Адреса|125741|28.3031|
|5|Занятость|125741|4.0376|
|6|Контактная информация|125741|11.4471|
|7|ПУ и счета|125741|16.3272|
|8|Заказ именных карт|125702|20.2128|
|9|Моментальная выдача карты|115272|16.5757|
|10|Проверка данных и подписание черновика|125698|89.5559|
|11|Подписание анкеты|125742|0.0518|
|12|Прикрепление документов|125742|104.1768|

Итак, проверка: если сложить все времена, то получится примерно 402 секунды. В 1 задании среднее время процесса было примерно 413 секунды. Расхождение примерно 3,5%, приемлемо. На некоторых операциях sql теряет секунды, так как округляет дробные части (timestampdiff). 

#### Что мы имеем:
1) Шаги 12 и 10 занимают почти половину всего времени (примерно 48%). Это шаги: «Прикрепление документов» и «Проверка данных и подписание» соответственно. В чем может быть проблема? Документы тормозят по техническим причинам, пользователь долго читает или отвлекается
2) Шаг 9 имеет провал по кейсам. Потерялись 10 430 кейсов (примерно 8%). В чем может быть проблема? Форма опциональная (не все заказывают моментальную карту) или техническая ошибка.

**Визуализация по заданию представлена в аналитическом отчете в папке PowerBI**
### Задание 3: Дополнительные метрики
Предложить список метрик (помимо кол-ва успешных регистрации и времени успешной операции), которые также необходимо отслеживать в динамике. Пояснить свой выбор и отразить цифровые значения метрик.

#### Решение:
Итак, теперь необходимо предложить список собственных метрик, которые я бы предложил отслеживать. В рамках тестового задания остановлюсь на 3 дополнительных метриках в виду сроков выполнения. 
В первую очередь хочу предложить отслеживать ту метрику, которую я косвенно выводил в предыдущем задании.

**1. Конверсия по формам**
Итак, конверсия по формам поможет осознать на каком шаге теряются кейсы, а это либо техническая ошибка, либо непонятный ux. Но также, возможно, что этот шаг просто опциональный, провал там абсолютно нормален, но всё равно лучше убедиться, что проблема не технического характера.

Для начала буду использовать то, что уже писал, немного доработав:

```sql
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
)
```
Теперь чтобы понять, что событие совершило успешный переход с формы будем искать отклик Submit > Response.
```sql
reached as (
    select fe.main_form, COUNT(distinct fe.case_id) as cases_reached
    from filtered_events fe
    where fe.event_name = 'Submit > Response'
    group by fe.main_form
)
```
Отлично, теперь поняв, что переход был совершен, можно написать основной select, который выведет мне информацию по количеству кейсов, которые перешли и процент перехода с соседней формы.
```sql
select f.step_order, f.step_name, r.cases_reached,
       (select COUNT(*) from confirm_case) as total_valid_cases,
       r.cases_reached * 100 / LAG(r.cases_reached) over (order by f.step_order) as conversion_from_prev_pct
from reached r
join my_database.form f on r.main_form = f.main_form and f.form_type = 'Основная'
order by f.step_order;
```
Итоговый запрос:
```sql
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
    where fe.event_name = 'Submit > Response'
    group by fe.main_form
)
select f.step_order, f.step_name, r.cases_reached,
       (select COUNT(*) from confirm_case) as total_valid_cases,
       r.cases_reached * 100 / LAG(r.cases_reached) over (order by f.step_order) as conversion_from_prev_pct
from reached r
join my_database.form f on r.main_form = f.main_form and f.form_type = 'Основная'
order by f.step_order;
```
**Результат:**

|step_order|step_name|cases_reached|total_valid_cases|conversion_from_prev_pct|
|----------|---------|-------------|-----------------|------------------------|
|1|Персональные данные|125740|125742||
|2|Идентификация паспортных данных|66412|125742|52.8169|
|3|Резидент или информация о нерезиденте|125740|125742|189.3333|
|4|Адреса|125708|125742|99.9746|
|5|Занятость|125741|125742|100.0263|
|6|Контактная информация|125740|125742|99.9992|
|7|ПУ и счета|125741|125742|100.0008|
|8|Заказ именных карт|125702|125742|99.9690|
|9|Моментальная выдача карты|115272|125742|91.7026|
|10|Проверка данных и подписание черновика|124834|125742|108.2952|
|11|Подписание анкеты|125742|125742|100.7274|
|12|Прикрепление документов|125742|125742|100.0000|
Результат – абсурд. На шаге 2 конверсия всего 53%, то есть на форме идентификации теряется половина клиентов. Физически – невозможно, так как на форме 3 снова 125 740 кейсов и конверсия 189%. Я решил проверить: «Что же не так с моим запросом?», не понял. Решил проверить все ли события Submit > Response логируются для второго шага.

```sql
select event_category, event_name, COUNT(*) as count
from my_database.events
where event_category = 'identification'
group by event_category, event_name
```
**Результат:**

|event_category|event_name|count|
|--------------|----------|-----|
|identification|Submit > Response|72068|
|identification|Click > Submit|140422|
|identification|Click > Back|6095|
Что получили: кликов – 140 422, ответов – 72 068. Логирование сломано, фиксация ответов только в половине случаев, а клиент форму проходит.

Вывод: Submit > Response не надёжна как идентификатор успешного прохода формы. Придется убрать его из CTE
```sql
reached as (
    select fe.main_form, COUNT(distinct fe.case_id) as cases_reached
    from filtered_events fe
    group by fe.main_form
)
```
Итоговый запрос:
```sql
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
)
select f.step_order, f.step_name, r.cases_reached,
       (select COUNT(*) from confirm_case) as total_valid_cases,
       r.cases_reached * 100 / LAG(r.cases_reached) over (order by f.step_order) as conversion_from_prev_pct
from reached r
join my_database.form f on r.main_form = f.main_form and f.form_type = 'Основная'
order by f.step_order;
```
**Результат:**

|step_order|step_name|cases_reached|total_valid_cases|conversion_from_prev_pct|
|----------|---------|-------------|-----------------|------------------------|
|1|Персональные данные|125742|125742||
|2|Идентификация паспортных данных|125740|125742|99.9984|
|3|Резидент или информация о нерезиденте|125740|125742|100.0000|
|4|Адреса|125741|125742|100.0008|
|5|Занятость|125741|125742|100.0000|
|6|Контактная информация|125741|125742|100.0000|
|7|ПУ и счета|125741|125742|100.0000|
|8|Заказ именных карт|125702|125742|99.9690|
|9|Моментальная выдача карты|115272|125742|91.7026|
|10|Проверка данных и подписание черновика|125698|125742|109.0447|
|11|Подписание анкеты|125742|125742|100.0350|
|12|Прикрепление документов|125742|125742|100.0000|

#### Что мы имеем:
Конверсия ровная, почти все клиенты проходят весь процесс регистрации. Провал есть в форме 9, но это опциональная форма, однако в логах все равно можно проверить, действительно ли все отказались, а не застряли из-за технической ошибки. Из-за провала на 9 шаге, конверсия на 10 шаге больше 100% - это норма.

Самый важный вывод – сломанное Submit > Response, надо исправит или документировать. Также аналогичную проверку можно провести и для других форм, может где-то еще есть поломки.

**2. Возвраты на предыдущие формы**

Итак, далее хочу предложить рассматривать возвраты на формы, ведь тут всего 3 варианта: пользователь передумал (проверил), ошибся и есть ошибка валидации или ux. Собственно, последний вариант и можно анализировать.

Необходимо посчитать количество Click > Back для каждой формы, найти долю возвратов среди тех кто дошел до формы. Также для анализа можно взять то, сколько уникальных кейсов имели возврат.

Для начала возьмем CTE из предыдущих заданий.

```sql
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
)
```
И теперь напишем счетчик возвратов по каждой форме.

```sql
backs as (
    select fe.main_form,
           COUNT(*) as back_clicks,                          
           COUNT(distinct fe.case_id) as cases_with_back
    from filtered_events fe
    where fe.event_name = 'Click > Back'
    group by fe.main_form
)
```
Теперь, зная сколько кликов назад существует для каждой формы и сколько возвратов существует для каждой формы мы можем написать основной select для вывода этого и долей. Не забываем, что если все исправно, то первая и последняя форма должны иметь 0 возвратов, следовательно, выведет null, заменим его на 0. И если вдруг возвратов на любую другую форму нету, то также заменил null на 0. Также важный момент присоединять backs через left, так как если в форме не было возвратов, то она не попадет в результат. 

```sql
select f.step_order, f.step_name, r.cases_reached,
       COALESCE(b.back_clicks, 0) as back_clicks,
       COALESCE(b.cases_with_back, 0) as cases_with_back,
       COALESCE(b.back_clicks, 0) * 100 / r.cases_reached as back_rate_pct
from reached r
join my_database.form f on r.main_form = f.main_form and f.form_type = 'Основная'
left join backs b on r.main_form = b.main_form
order by step_order;
```
Итоговый запрос:
```sql
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
```
**Результат:**

|step_order|step_name|cases_reached|back_clicks|cases_with_back|back_rate_pct|
|----------|---------|-------------|-----------|---------------|-------------|
|1|Персональные данные|125742|0|0|0.0000|
|2|Идентификация паспортных данных|125740|4724|3912|3.7570|
|3|Резидент или информация о нерезиденте|125740|6720|3602|5.3444|
|4|Адреса|125741|1806|1644|1.4363|
|5|Занятость|125741|2169|2097|1.7250|
|6|Контактная информация|125741|1903|1831|1.5134|
|7|ПУ и счета|125741|2783|2643|2.2133|
|8|Заказ именных карт|125702|2889|2691|2.2983|
|9|Моментальная выдача карты|115272|2648|2519|2.2972|
|10|Проверка данных и подписание черновика|125698|9357|6346|7.4440|
|11|Подписание анкеты|125742|8|6|0.0064|
|12|Прикрепление документов|125742|0|0|0.0000|
#### Что мы имеем:
1) На форме 10 возврат чаще всего (7,5%). Это форма с проверкой данных. Скорее всего пользователь заметил какую-то ошибку и хочет ее исправить. Для этого ему необходимо вернуться до нужного шага и вернуться. Можно разрешить редактирование прямо на форме с проверкой, без возврата. Так удобнее.
2) На форме 3 также наблюдается частый возврат (что странно). Скорее всего пользователи не понимают интерфейс и возвращаются для проверки. Можно переработать форму и провести A/B-тест.
3) На форме 2 также наблюдается большой возврат. Скорее всего люди чаще всего допускают ошибки именно в этом поле, но возможно их сбивает «Меняли паспорт?». Также можно переработать форму и провести A/B-тест.

Остальные формы не отличаются большим возвратом.

**3. Количество событий на кейс**

Здесь я хочу рассмотреть вопрос: «Насколько длинный путь проходит клиент внутри системы?». Если обычный пользователь в норме делает условные 20 действий, а в некоторых кейсах – 100, то значит, что его гоняет по кругу. Причин, конечно, может быть много, допустим: возвращается на предыдущие формы, не работает валидация, данные не принимаются с первого раза, технические сбои и тд.

Нужно будет рассмотреть распределение: если разброс большой – система нестабильна по опыту клиента, значит что-то не так.

Для начала возьмем CTE из предыдущих заданий.

```sql
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
```
И теперь напишем новый CTE, который будет считать число событий в каждом кейсе.
```sql
case_depth as (
    select case_id, COUNT(*) as events_count
    from filtered_events
    group by case_id
)
```
Отлично, теперь я хочу вывести 4 параметра: самый короткий кейс, самый длинный кейс, среднее количество действий, стандартное отклонение (STDDEV).
```sql
select MIN(events_count) as min_events,
 	 MAX(events_count) as max_events,
       AVG(events_count) as avg_events,
       STDDEV(events_count) as stddev_events
from case_depth;
```
Итоговый запрос:
```sql
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
```
**Результат:**

|min_events|max_events|avg_events|stddev_events|
|----------|----------|----------|-------------|
|8|192|34.2690|6.353959083344903|

#### Что мы имеем:
1) Среднее количество действий примерно 34. Значит типичный пользователь делает именно столько действий в процессе регистрации. Вполне логично для 12 форм, где как минимум на каждой форме есть по 2 события + еще возвраты.
2) Среднее отклонение – 6,4. Если посчитать коэффициент вариации, который равен делению ср. кв. отклонения на среднее арифмитическое в процентах, то получим около 18%. Довольно мало, как говорит гугл – В контексте пользовательского опыта (UX) и продуктовой аналитики коэффициент вариации, равный 18%, считается очень хорошим показателем, который указывает на среднюю (ближе к слабой) изменчивость и высокую однородность данных. Значит все отлично и клиентов не гоняет по кругу.
3) Можно рассмотреть самый минимальный (8) и самый максимальный (192) кейсы. Проанализировав их отдельно (лучше руками), мы выясним была ли это техническая ошибка. Если максимальный кейс еще можно обосновать тем, что клиент по 20 раз возвращался назад, то минимальный кейс с 8 событиями очень странный. Возможно, система автоматически пропускает какие-то формы, или часть событий вообще не логируется, или события потерялись при выгрузке. Если это автопропуск, то задокументировать, если нет, то починить.

**Визуализация по заданию представлена в аналитическом отчете в папке PowerBI**

### Задание 4: Оценка изменений
Необходимо оценить: в лучшую или худшую сторону изменился процесс за представленные 7 месяцев. Мы оцениваем результаты работы команды разработки, поэтому учитывать нужно только те факторы, на которые команда может повлиять. Необходимо объяснить свою оценку и подтвердить ваши выводы на основе данных
#### Решение
Итак, чтобы оценить в лучшую или худшую сторону изменился процесс необходимо понять по каким параметрам мы будем проводить оценку.

Я предлагаю оценивать то насколько изменился процесс по тем метрикам, которые я рассматривал в предыдущих заданиях (в динамике по месяцам) и на которые может повлиять команда разработки.

Рассмотрим такие метрики как:
1. Среднее время процесса успешной регистрации
2. Среднее время по каждой форме 
3. Конверсия по формам
4. Возвраты на предыдущие формы
5. Количество событий на кейс

Рассмотрим и проанализируем каждую метрику отдельно:

**1. Среднее время процесса успешной регистрации**

Первую метрику мы в точности рассматривали в 1 задании. Напомню результат:
**Результат:**

|month|total_yspeh_reg|yspeh_reg|avg_diff_time|
|-----|---------------|---------|-------------|
|2024-01|14338|14295|416.2031|
|2024-02|16912|16865|417.8840|
|2024-03|18079|18021|413.6884|
|2024-04|18303|18230|411.5779|
|2024-05|19260|19203|407.6373|
|2024-06|18361|18297|411.6657|
|2024-07|20901|20831|413.1168|

Как мы можем заметить, по средней длительности значительных изменений не наблюдается. Среднее время находиться в диапазоне 407-416 секунд, отклонение всего около 2%. 

Если сравнивать между собой первый и последний месяц, то статистически они почти неотличимы: январь – 416 секунд, июль – 414 секунды. Но, как можно заметить, количество успешных регистраций на месяц увеличилось примерно на 50%. Значит, команда разработчиков смогла удержать производитель при увеличении числа пользователей, но мы не можем считать это за улучшение или ухудшение процесса. 

**2. Среднее время по каждой форме**

В процессе выполнения задания 2 мы рассматривали суммарное время на каждой форме за весь период, теперь же нам нужно рассмотреть формы по месяцам. Для этого необходимо добавить месяца в CTE расчета времени на каждой форме.

Итоговый запрос:

```sql
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
select t.month, f.step_order, f.step_name, COUNT(*) as case_count,
       AVG(t.time_on_form) as avg_time_on_form
from time_per_form_per_case t
join my_database.form f on t.main_form = f.event_category
group by t.month, f.step_order, f.step_name
order by t.month, f.step_order;
```
**Результат:**

|month|step_order|step_name|case_count|avg_time_on_form|
|-----|----------|---------|----------|----------------|
|2024-01|1|Персональные данные|14295|63.1540|
|2024-01|2|Идентификация паспортных данных|14294|9.4463|
|2024-01|3|Резидент или информация о нерезиденте|14294|36.7894|
|2024-01|4|Адреса|14294|29.6596|
|2024-01|5|Занятость|14294|4.3383|
|2024-01|6|Контактная информация|14294|8.5206|
|2024-01|7|ПУ и счета|14294|31.1249|
|2024-01|8|Заказ именных карт|14289|18.7963|
|2024-01|9|Моментальная выдача карты|13126|24.0434|
|2024-01|10|Проверка данных и подписание черновика|14282|86.0079|
|2024-01|11|Подписание анкеты|14295|0.0281|
|2024-01|12|Прикрепление документов|14295|94.4870|
|...|...|...|...|...|
|2024-07|1|Персональные данные|20831|60.9136|
|2024-07|2|Идентификация паспортных данных|20831|9.5651|
|2024-07|3|Резидент или информация о нерезиденте|20831|42.7221|
|2024-07|4|Адреса|20831|27.2792|
|2024-07|5|Занятость|20831|3.9761|
|2024-07|6|Контактная информация|20831|13.2688|
|2024-07|7|ПУ и счета|20831|9.1162|
|2024-07|8|Заказ именных карт|20826|23.4339|
|2024-07|9|Моментальная выдача карты|19120|14.0180|
|2024-07|10|Проверка данных и подписание черновика|20830|89.5622|
|2024-07|11|Подписание анкеты|20831|0.1093|
|2024-07|12|Прикрепление документов|20831|107.6348|

Итак, чтобы понять, как изменился процесс за эти 7 месяцев сравним первый и последний месяц по каждой форме, для удобства сделаю таблицу сравнения:

| Форма                                  | Январь | Июль   | Разница | %      | Вердикт             |
|----------------------------------------|--------|--------|---------|--------|---------------------|
| Персональные данные                    | 63.15  | 60.91  | -2.24   | -3.55  | улучшено            |
| Идентификация паспортных данных        | 9.45   | 9.57   | 0.12    | 1.26   | нейтрально          |
| Резидент или информация о нерезиденте  | 36.79  | 42.72  | 5.93    | 16.13  | ухудшено            |
| Адреса                                 | 29.66  | 27.28  | -2.38   | -8.03  | улучшено            |
| Занятость                              | 4.34   | 3.98   | -0.36   | -8.38  | улучшено            |
| Контактная информация                  | 8.52   | 13.27  | 4.75    | 55.74  | сильно ухудшено     |
| ПУ и счета                             | 31.12  | 9.12   | -22.01  | -70.71 | сильно улучшено     |
| Заказ именных карт                     | 18.80  | 23.43  | 4.64    | 24.68  | ухудшено            |
| Моментальная выдача карты              | 24.04  | 14.02  | -10.02  | -41.70 | улучшено            |
| Проверка данных и подписание черновика | 86.01  | 89.56  | 3.56    | 4.13   | немного ухудшено    |
| Подписание анкеты                      | 0.03   | 0.11   | 0.08    | 288.97 | значения близки к 0, форма автоматическая|
| Прикрепление документов                | 94.49  | 107.63 | 13.15   | 13.91  | ухудшено            |



Улучшения:

- Персональные данные: улучшение на 3,55%, улучшение не сильное, скорее показывает стабильность формы
- Адреса: улучшение на 8,03%, улучшение не сильное, скорее показывает стабильность формы
- Занятость: улучшение на 8,38%, улучшение не сильное, скорее показывает стабильность формы
- ПУ и счета: очень сильное улучшение на 70,71%, команда явно добавила что-то новое, форма стала удобнее/понятней
- Моментальная выдача карты: заметное улучшение на 41,7%, команда явно добавила что-то новое, форма стала удобнее/понятней

Ухудшения:
- Резидент или информация о нерезиденте: ухудшение на 16,13%, возможно форма усложнилась (добавилось новое окно) или количество резидентов возросло. Команде необходимо разобраться 
- Контактная информация: сильное ухудшение на 55,74%, скорее всего команда добавила на форму что-то новое, что привело к увеличению времени. Команде необходимо разобраться
- Заказ именных карт: ухудшение на 24,68%, скорее всего команда добавила новые карты, следовательно, время выбора клиента стало дольше
- Проверка данных и подписание черновика: ухудшение на 4,13%, ухудшение не сильное, скорее относится к стабильности
- Прикрепление документов: ухудшение на 13,91%, форма самая долгая, стала еще дольше, возможно, связано с увеличением числа документов на подпись, либо форма тормозит. Команде необходимо разобраться 

Среднее время процесса регистрации остается стабильным, но времена на формах изменились относительно начальных. Следовательно, улучшения и ухудшения компенсировали друг друга.

**3. Конверсия по формам**

Далее рассмотрим конверсию по формам для каждого месяца. В задании 3, я рассматривал конверсию именно по самим формам, теперь нужно рассмотреть каждую форму в месяце. Для этого помимо группировки по месяцам, необходимо поменять числитель и знаменатель в расчете самой конверсии, так как делил я на общее количество. Для этого напишу новый CTE для расчета того, сколько кейсов стартовало в каждом месяце и изменю reached

```sql
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
```
Итоговый запрос:
```sql
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
```
**Результат:**

|month|step_order|step_name|total_cases|cases_reached|conversion_pct|
|-----|----------|---------|-----------|-------------|--------------|
|2024-01|1|Персональные данные|14295|14295|100.0000|
|2024-01|2|Идентификация паспортных данных|14295|14294|99.9930|
|2024-01|3|Резидент или информация о нерезиденте|14295|14294|99.9930|
|2024-01|4|Адреса|14295|14294|99.9930|
|2024-01|5|Занятость|14295|14294|99.9930|
|2024-01|6|Контактная информация|14295|14294|99.9930|
|2024-01|7|ПУ и счета|14295|14294|99.9930|
|2024-01|8|Заказ именных карт|14295|14289|99.9580|
|2024-01|9|Моментальная выдача карты|14295|13126|91.8223|
|2024-01|10|Проверка данных и подписание черновика|14295|14282|99.9091|
|2024-01|11|Подписание анкеты|14295|14295|100.0000|
|2024-01|12|Прикрепление документов|14295|14295|100.0000|
|...|...|...|...|...|...|
|2024-07|1|Персональные данные|20831|20831|100.0000|
|2024-07|2|Идентификация паспортных данных|20831|20831|100.0000|
|2024-07|3|Резидент или информация о нерезиденте|20831|20831|100.0000|
|2024-07|4|Адреса|20831|20831|100.0000|
|2024-07|5|Занятость|20831|20831|100.0000|
|2024-07|6|Контактная информация|20831|20831|100.0000|
|2024-07|7|ПУ и счета|20831|20831|100.0000|
|2024-07|8|Заказ именных карт|20831|20826|99.9760|
|2024-07|9|Моментальная выдача карты|20831|19120|91.7863|
|2024-07|10|Проверка данных и подписание черновика|20831|20830|99.9952|
|2024-07|11|Подписание анкеты|20831|20831|100.0000|
|2024-07|12|Прикрепление документов|20831|20831|100.0000|

Итак, чтобы понять, как изменился процесс за эти 7 месяцев сравним первый и последний месяц по каждой форме, для удобства сделаю таблицу сравнения:

| Форма                                  | Январь | Июль   | Разница | %     | Вердикт   |
|----------------------------------------|--------|--------|---------|-------|-----------|
| Персональные данные                    | 100.00 | 100.00 | 0.00    | 0.00  | стабильно |
| Идентификация паспортных данных        | 99.99  | 100.00 | 0.01    | 0.01  | стабильно |
| Резидент или информация о нерезиденте  | 99.99  | 100.00 | 0.01    | 0.01  | стабильно |
| Адреса                                 | 99.99  | 100.00 | 0.01    | 0.01  | стабильно |
| Занятость                              | 99.99  | 100.00 | 0.01    | 0.01  | стабильно |
| Контактная информация                  | 99.99  | 100.00 | 0.01    | 0.01  | стабильно |
| ПУ и счета                             | 99.99  | 100.00 | 0.01    | 0.01  | стабильно |
| Заказ именных карт                     | 99.96  | 99.98  | 0.02    | 0.02  | стабильно |
| Моментальная выдача карты              | 91.82  | 91.79  | -0.04   | -0.04 | стабильно |
| Проверка данных и подписание черновика | 99.91  | 99.99  | 0.08    | 0.08  | улучшение |
| Подписание анкеты                      | 100.00 | 100.00 | 0.00    | 0.00  | стабильно |
| Прикрепление документов                | 100.00 | 100.00 | 0.00    | 0.00  | стабильно |

Из таблицы сравнения можно сделать вывод, что все формы на протяжении всего времени – стабильны. Это означает, что команда разработчиков не допустила ошибок здесь и всё работает постоянно.

Более того, форма «Проверка данных и подписание черновика» показывает улучшение, к июлю форма вообще не теряет кейсов. Команда разработчиков убрала все (даже маленькие) баги.

На форме «Моментальная выдача карты» конверсия 91,8% сохраняется постоянно, значит это не ошибка разработчиков.

**4. Возвраты на предыдущие формы**

Далее рассмотрим возвраты на предыдущие формы, но именно по месяцам. Для этого воспользуемся той же логикой, добавим группировку по месяцам в предыдущие CTE. Важный момент про left join: если не прописать, что джоин также идет по месяцам, то каждая строка из reached брала ьы все строки backs (из других месяцев тоже).

Итоговый запрос:
```sql
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
reached as (
    select fe.month, fe.main_form, COUNT(distinct fe.case_id) as cases_reached
    from filtered_events fe
    group by fe.month, fe.main_form
),
backs as (
    select fe.month, fe.main_form,
		   COUNT(*) as back_clicks,                          
           COUNT(distinct fe.case_id) as cases_with_back
    from filtered_events fe
    where fe.event_name = 'Click > Back'
    group by fe.month, fe.main_form
)
select r.month, f.step_order, f.step_name, r.cases_reached,
       COALESCE(b.back_clicks, 0) as back_clicks,
       COALESCE(b.cases_with_back, 0) as cases_with_back,
       COALESCE(b.back_clicks, 0) * 100 / r.cases_reached as back_rate_pct
from reached r
join my_database.form f on r.main_form = f.main_form and f.form_type = 'Основная'
left join backs b on r.main_form = b.main_form and r.month = b.month
order by r.month, step_order;
```
**Результат:**

|month|step_order|step_name|cases_reached|back_clicks|cases_with_back|back_rate_pct|
|-----|----------|---------|-------------|-----------|---------------|-------------|
|2024-01|1|Персональные данные|14295|0|0|0.0000|
|2024-01|2|Идентификация паспортных данных|14294|448|384|3.1342|
|2024-01|3|Резидент или информация о нерезиденте|14294|611|356|4.2745|
|2024-01|4|Адреса|14294|192|175|1.3432|
|2024-01|5|Занятость|14294|256|249|1.7910|
|2024-01|6|Контактная информация|14294|231|223|1.6161|
|2024-01|7|ПУ и счета|14294|331|318|2.3157|
|2024-01|8|Заказ именных карт|14289|342|325|2.3934|
|2024-01|9|Моментальная выдача карты|13126|295|283|2.2474|
|2024-01|10|Проверка данных и подписание черновика|14282|1228|927|8.5982|
|2024-01|11|Подписание анкеты|14295|0|0|0.0000|
|2024-01|12|Прикрепление документов|14295|0|0|0.0000|
|...|...|...|...|...|...|...|
|2024-07|1|Персональные данные|20831|0|0|0.0000|
|2024-07|2|Идентификация паспортных данных|20831|842|700|4.0421|
|2024-07|3|Резидент или информация о нерезиденте|20831|1271|667|6.1015|
|2024-07|4|Адреса|20831|324|294|1.5554|
|2024-07|5|Занятость|20831|368|356|1.7666|
|2024-07|6|Контактная информация|20831|292|286|1.4018|
|2024-07|7|ПУ и счета|20831|440|419|2.1122|
|2024-07|8|Заказ именных карт|20826|500|462|2.4008|
|2024-07|9|Моментальная выдача карты|19120|466|445|2.4372|
|2024-07|10|Проверка данных и подписание черновика|20830|1538|1007|7.3836|
|2024-07|11|Подписание анкеты|20831|0|0|0.0000|
|2024-07|12|Прикрепление документов|20831|0|0|0.0000|

Итак, чтобы понять, как изменился процесс за эти 7 месяцев сравним первый и последний месяц по каждой форме, для удобства сделаю таблицу сравнения:

| Форма                                  | Январь | Июль | Разница | %      | Вердикт           |
|----------------------------------------|--------|------|---------|--------|-------------------|
| Персональные данные                    | 0      | 0.00 | 0.00    | 0.00   | стабильно         |
| Идентификация паспортных данных        | 3.1342 | 4.04 | 0.91    | 28.97  | ухудшение         |
| Резидент или информация о нерезиденте  | 4.2745 | 6.10 | 1.83    | 42.74  | сильное ухудшение |
| Адреса                                 | 1.34   | 1.56 | 0,21    | 15,80 | ухудшение         |
| Занятость                              | 1.79   | 1.77 | -0.02   | -1.36  | стабильно         |
| Контактная информация                  | 1.62   | 1.40 | -0.21   | -13.26 | улучшение         |
| ПУ и счета                             | 2.32   | 2.11 | -0.21   | -8.88  | улучшение         |
| Заказ именных карт                     | 2.39   | 2.40 | 0.01    | 0.31   | стабильно         |
| Моментальная выдача карты              | 2.24   | 2.44 | 0.20    | 8.93   | ухудшение         |
| Проверка данных и подписание черновика | 8.60   | 7.38 | -1.21   | -14.13 | улучшение         |
| Подписание анкеты                      | 0.00   | 0.00 | 0.00    | 0.00   | стабильно         |
| Прикрепление документов                | 0.00   | 0.00 | 0.00    | 0.00   | стабильно         |

Улучшения:

- Контактная информация: улучшение на 13,26%, время на этой форме как раз сильно увеличилось, еще одно подтверждение того, что команда разработчиков добавила на эту форму что-то новое, что влияет на время и сокращает возвраты
-	ПУ и счета: улучшение на 8,88%, время на этой форме сильно сократилось, скорее всего команда упростила поля или улучшила отклик, это снизило и возвраты. То, что применили здесь, надо использовать и на проблемных формах.
-	Проверка данных и подписание черновика: улучшение на 14,13%, эта форма лидирует по возвратам, но с января месяца было явно улучшение, которое пробовало убрать эту проблему.

Ухудшения:
	
- Адреса: ухудшение на 15,8%, улучшение не сильное, скорее показывает стабильность формы
-	Идентификация паспортных данных: ухудшение на 28,97%, выяснив, что на этой форме есть проблема логирования, можно сделать вывод о том, что эта проблема связана с этим. Форма плохо откликается – клиенты возвращаются 
-	Резидент или информация о нерезиденте: сильное ухудшение на 42,74%, время на этой форме также выросло, скорее всего форма все-таки стала сложнее. Команде необходимо разобраться
-	Моментальная выдача карты: ухудшение на 8,93%, улучшение не сильное, скорее показывает стабильность формы

**5. Количество событий на кейс**

Далее рассмотрим количество событий на кейс по месяцам. Для этого воспользуемся той же логикой, добавим группировку по месяцам в предыдущие CTE. Также добавлю автоматический расчет коэффициента вариации для каждого месяца.

Итоговый запрос:
```sql
with time_yspeh_reg as( 
select case_id, Max(case when event_category = 'result' and event_name = 'Submit > Response' then timestamp end) as fin_time, 
Min(case when event_category = 'session' and event_name = 'Sign In' then timestamp end) as start_time
from my_database.events 
group by case_id 
having start_time IS NOT NULL AND fin_time IS NOT NULL
),
confirm_case as(
select case_id, fin_time, start_time, DATE_FORMAT(start_time, '%Y-%m') as month from time_yspeh_reg
where TIMESTAMPDIFF(SECOND, start_time, fin_time) between 1 and 1800
),
filtered_events as (
    select e.case_id, e.timestamp, e.event_name, e.event_property, f.main_form, f.step_order, f.step_name, cc.month
    from my_database.events e
    join confirm_case cc on e.case_id = cc.case_id
    join my_database.form f on e.event_category = f.event_category
    where e.timestamp between cc.start_time and cc.fin_time
),
case_depth as (
    select month, case_id, COUNT(*) as events_count
    from filtered_events
    group by month, case_id
)
select month, MIN(events_count) as min_events,
 	   MAX(events_count) as max_events,
       AVG(events_count) as avg_events,
       STDDEV(events_count) as stddev_events,
       STDDEV(events_count) * 100/ AVG(events_count) as koef_var
from case_depth
group by month
order by month;
```
**Результат:**

|month|min_events|max_events|avg_events|stddev_events|koef_var|
|-----|----------|----------|----------|-------------|--------|
|2024-01|8|192|33.3570|5.864968482048493|17.582433541726015|
|2024-02|25|156|33.5048|6.143755943854349|18.336924815660346|
|2024-03|23|133|33.7252|6.185376126620651|18.340512105162663|
|2024-04|25|179|34.4094|6.377208359525716|18.53331320343306|
|2024-05|26|152|34.6673|6.324972455493454|18.2447839713828|
|2024-06|26|161|34.8825|6.496384900381886|18.623595686438662|
|2024-07|26|183|34.9548|6.681089653840736|19.113496586061874|

Как мы можем заметить:

- Среднее количество событий каждый месяц стабильно растет (на 4,8% с января по июль). Это может значит то, что ux не улучшался/ухудшился.
-	Среднее квадратичное отклонение также выросло на 14% с 5,86 до 6,68. Разброс увеличился, процесс стал менее однородным, часть клиентов стала проходить заметно быстрее, другая заметно дольше.
-	Коэффициент вариации по месяцам относительно стабилен, следовательно, процесс остается стабильным на протяжении всех месяцев, НО тренд все равно идет в сторону меньшей стабильности (поднялся на 1,58%)
-	Также интересно, что аномальный минимум случился именно в январе, это может быть связано с первоначальными тестами, потерей событий или автоматическим пропуском. Но такой случай единичный.

#### Что мы имеем:

После проведенного анализа можно сказать, что процесс за 7 месяцев остался без изменений с легким уклоном в худшую сторону. Видно, что команда разработчиков за данный период внедряла обновления системы, но процесс в среднем остался стабильным, без значительных улучшений. 

Можно выделить разнонаправленные точечные изменения: 3 формы оказались улучшены (ПУ и счета, Моментальная выдача карты, Проверка данных и подписание черновика), 4 формы ухудшились (Резидент или информация о нерезиденте, Контактная информация, Идентификация паспортных данных, Прикрепление документов), остальные остались стабильны.

Несмотря на улучшения, количество регрессов превышает улучшения.

**Визуализация по заданию представлена в аналитическом отчете в папке PowerBI**

### Задание 5: Что донести владельцу
В этом задании укажите, какую бы еще информацию вы бы донесли до владельца продукта/процесса регистрации. Это могут быть проблемные зоны процесса, со скрытые взаимосвязи, предложения по улучшению интерфейса приложения или всего процесса.

#### Решение:

Процесс регистрации за 7 месяцев показывает стабильную работу, но имеет легкий уклон в сторону ухудшения. Среднее время процесса за 7 месяцев не изменилось (416 сек за январь - 414 сек за июль, –0.6%), однако за этими числами скрываются разнонаправленные изменения: команда улучшила формы 7, 9 и 10, но допустила регресс на формах 3, 6, 8, 12. Улучшения и ухудшения взаимно компенсируются, из-за чего средние метрики маскируют реальную картину.

**Конкретные изменения по формам, которые улучшились:**
-	Форма 7 «ПУ и счета» - среднее время сократилось на 70,71% (31,12 сек за январь – 9,12 сек за июль), количество возвратов сократилось на 8,88% (2,32% за январь – 2,11% за июль), конверсия осталась стабильной (на уровне 100%)
-	Форма 9 «Моментальная выдача карты» - среднее время сократилось на 41,7% (24,04 сек за январь – 14,02 сек за июль), возвраты выросли незначительно, конверсия осталась стабильной (на уровне 91,8%)
-	Форма 10 «Проверка данных и подписание черновика» - время выросло незначительно (на 4,13%), количество возвратов сократилось на 14,13% (с 8,6% за январь – 7,38% за июль), конверсия выросла до 100% (с 99,91%)

**Приоритеты на ближайший квартал:**
1. Форма 3 «Резидент или информация о нерезиденте» - системный регресс по двум метрикам
- Среднее время увеличилось на 16,13% (36,79 сек за январь – 42,72 сек за июль)
- Возвраты выросли на 42,74% (4,27% за январь – 6,1% за июль)

Скорее всего команда разработки усложнила форму. Необходимо изучить историю новых релизов за 7 месяцев и найти конкретное изменение
2.	Форма 12 «Прикрепление документов – самая длительная форма, постоянный рост

- Среднее время увеличилось на 13,9% (94,49 сек в январе – 107,63 сек в июле)
- Абсолютный прирост: +13.14 сек — это наибольшее ухудшение среди всех форм
- Вместе с формой 10 занимает 48% всего времени процесса

Скорее всего увеличился средний размер прикрепляемых документов или добавились проверки/тормозит сервер. Команде необходимо найти проблему
3. Форма 2 «Идентификация паспортных данных» - двойная проблема
- Баг логирования: Submit > Response фиксируется только в 53% случаев, а это событие является определяющим переход.
- Возвраты выросли на 28,97% (3,13% в январе – 4,04% в июле)
- Среднее время осталось стабильным

Скорее всего есть общая причина. Из-за бага логирования клиент жмёт «Продолжить», не видит ответа, жмёт ещё раз или возвращается назад. Команда должна разобраться с багом логирования, после этого проверить, ушли ли возвраты.
4. Форма 6 «Контактная информация» - увеличение времени при уменьшении количества возвратов
- Среднее время увеличилось на 55,7% (8,52 сек в январе – 13,27 сек в июле), самый большой относительный рост времени среди форм
- Возвраты уменьшились на 13% (1,62% в январе – 1,4% в июле)

Скорее всего команда добавила на форму подсказку или расширила поля для заполнения – клиенты стали дольше заполнять форму, но реже возвращаться назад. Команде необходимо проверить осознанно ли это произошло, если да, то оценить, что выгоднее.

**Предложения по улучшению процесса:**

1. Перейти от метрики «среднее время» к матрице по формам
Общее время не меняется, но по формам разброс огромный: от –70.7% (форма 7) до 55.7% (форма 6). Одна метрика усредняет всё в ноль и не показывает, где команда работает успешно, а где есть регресс.
2. Маркировать опциональные формы в отчётах
Форма 9 «Моментальная выдача карты» стабильно показывает конверсию 91.7% — теряется около 8% кейсов. Это нормально, ведь клиенты осознанно отказываются от карты. Но без пометки «опциональная форма» новые сотрудники будут постоянно задаваться вопросом по поводу потери кейсов. Нужно визуально выделять такие формы и в отчётах, и в интерфейсе.
3. Добавить статистку по сотрудникам
Сейчас все метрики посчитаны в среднем по всем сотрудникам. Если выделить сотрудников по их employee_id, то можно увидеть среднее время работы каждого. Это поможет определить узкие места.

**Визуализация по заданию представлена в аналитическом отчете в папке PowerBI**