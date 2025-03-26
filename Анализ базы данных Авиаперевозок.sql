Анализ БД Авиаперевозок. 

Задания:

1. Выведите название самолетов, которые имеют менее 50 посадочных мест?
2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.
3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.
4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, учитывая только те самолеты, которые летали пустыми и только те дни, где из одного аэропорта таких самолетов вылетало более одного.
 В результате должны быть код аэропорта, дата, количество пустых мест в самолете и накопительный итог.
5. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
 Выведите в результат названия аэропортов и процентное отношение.
 Решение должно быть через оконную функцию.
6. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7
7. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
 До 50 млн - low
 От 50 млн включительно до 150 млн - middle
 От 150 млн включительно - high
 Выведите в результат количество маршрутов в каждом полученном классе
8. Вычислите медиану стоимости перелетов, медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов, округленной до сотых
9. Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат
  Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
  Для работы модуля earthdistance необходимо предварительно установить модуль cube.
  Установка модулей происходит через команду: create extension название_модуля


--1. Выведите название самолетов, которые имеют менее 50 посадочных мест?

select a.aircraft_code, count(seat_no)
from aircrafts a
join seats s on a.aircraft_code =s.aircraft_code 
group by a.aircraft_code
having (count(seat_no)) < 50

--2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

select *, round(100*((sum - lag(sum) over (order by date_trunc))/lag(sum) over (order by date_trunc)),2) as percentage
from (
select date_trunc('month',book_date), sum(total_amount)
      from bookings 
      group by date_trunc('month',book_date)) t 


--3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.
 
 select model, a.aircraft_code, array_agg as conditions
 from (select aircraft_code, array_agg(distinct fare_conditions order by fare_conditions) 
 from seats
 group by aircraft_code
 having not (array_agg(distinct fare_conditions order by fare_conditions) @> array['Business'::varchar])
 order by aircraft_code
 ) t 
 join aircrafts a on t.aircraft_code = a.aircraft_code

 
--4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, 
 --учитывая только те самолеты, которые летали пустыми и только те дни, где из одного аэропорта таких самолетов вылетало более одного.
--В результате должны быть код аэропорта, дата, количество пустых мест и накопительный итог.

                 
 with cte1 as ( select f.departure_airport,f.actual_departure,f.aircraft_code, count(f.flight_no) over (partition by f.departure_airport,f.actual_departure::date order by f.actual_departure::date) -- выводим все рейсы на которых летали самолеты пустыми 
          from flights f 
          left join boarding_passes bp on bp.flight_id =f.flight_id 
          where bp.boarding_no is null and f.actual_departure is not null 
          order by departure_airport, actual_departure),
 cte3 as (select aircraft_code, count(seat_no) -- количество мест в самолете
         from seats 
         group by aircraft_code)
select cte1.departure_airport "Код аэропорта", cte1.actual_departure::date "Дата", cte3.count "Количество пустых мест", 
       sum(cte3.count) over (partition by cte1.departure_airport,cte1.actual_departure::date order by cte1.actual_departure) "Накопительный итог"
from cte1
join cte3 on cte1.aircraft_code=cte3.aircraft_code
where cte1.count > 1
order by cte1.departure_airport,cte1.actual_departure


-- 5. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
--Выведите в результат названия аэропортов и процентное отношение.
--Решение должно быть через оконную функцию.


select a.airport_name "Аэропорт вылета", a2.airport_name "Аэропорт прилета", 
      round(((count(f.flight_no)/sum(count(f.flight_no)) over ())*100),2) "Процентное соотношение перелетов"-- количество перелетов по каждому марщруту 
from flights f 
join airports a on f.departure_airport = a.airport_code 
join airports a2 on f.arrival_airport =a2.airport_code 
group by a.airport_name, a2.airport_name
order by a.airport_name, a2.airport_name

--6 Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7

      
      select substring(contact_data->>'phone' from 3 for 3) "Код оператора", count(passenger_id) "Количество пассажиров"
      from tickets
      group by substring(contact_data->>'phone' from 3 for 3)

--7 Классифицируйте финансовые обороты (сумма стоимости билетов) по маршрутам: 
--До 50 млн - low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high
--Выведите в результат количество маршрутов в каждом полученном классе.
     

select t.klass "Класс", sum(t.count) "Количество маршрутов"
from (select f.departure_airport, f.arrival_airport, count (f.flight_id),
      case 
       	 when sum (tf.amount) < 50000000 then 'Low'
       	 when sum (tf.amount) >=50000000 and sum (tf.amount) < 150000000 then 'Middle'
       	 else 'High'
       end klass
     from flights f
     join ticket_flights tf on f.flight_id =tf.flight_id 
     group by f.departure_airport, f.arrival_airport) t      
 group by t.klass 
 
 -- 8 Вычислите медиану стоимости билетов, медиану размера бронирования 
--и отношение медианы бронирования к медиане стоимости билетов, округленной до сотых.


with cte1 as (select PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY total_amount)
from bookings b),
cte2 as (select PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY tf.amount)
from ticket_flights tf)
select cte1.PERCENTILE_DISC "Медиана размера бронирования", cte2.PERCENTILE_DISC "Медиана стоимости билетов", 
       round((cte1.PERCENTILE_DISC/cte2.PERCENTILE_DISC),2)
from cte1, cte2

--9 Найдите значение минимальной стоимости полета 1 км для пассажиров. 
--То есть нужно найти расстояние между аэропортами и с учетом стоимости билетов получить искомый результат.
--Для поиска расстояния между двумя точка на поверхности Земли нужно использовать 
--дополнительный модуль earthdistance (https://postgrespro.ru/docs/postgresql/15/earthdistance). 
--Для работы данного модуля нужно установить еще один модуль cube (https://postgrespro.ru/docs/postgresql/15/cube). 
--Установка дополнительных модулей происходит через оператор create extension название_модуля.
--Функция earth_distance возвращает результат в метрах.
--В облачной базе данных модули уже установлены.


CREATE EXTENSION cube;

CREATE EXTENSION earthdistance;

with cte1 as (select *,ll_to_earth (latitude,longitude)
              from flights f
              join airports a on a.airport_code = f.departure_airport),
cte2 as(select *,ll_to_earth (latitude,longitude)
        from flights f
        join airports a on a.airport_code = f.arrival_airport),
cte3 as (select cte1.departure_airport,cte2.arrival_airport, tf.amount/(earth_distance ( cte1.ll_to_earth, cte2.ll_to_earth )/1000) m
         from cte1
         join cte2 on cte1.flight_id=cte2.flight_id
         join ticket_flights tf on cte1.flight_id=tf.flight_id)
select min(m)
from cte3 
 
