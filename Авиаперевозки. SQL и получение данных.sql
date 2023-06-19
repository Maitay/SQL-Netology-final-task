--1) Какие самолеты имеют более 50 посадочных мест?

select model from aircrafts a
join seats s on a.aircraft_code = s.aircraft_code
group by model
having count(seat_no)>50



--2) В каких аэропортах есть рейсы, в рамках которых можно добраться бизнес - классом дешевле, чем эконом - классом?

with cte as (
select distinct f.flight_no, fare_conditions, amount, departure_airport, arrival_airport 
from flights f 
join ticket_flights tf on f.flight_id =tf.flight_id 
),
cte2 as (
select flight_no, fare_conditions,amount
from cte
where fare_conditions = 'Business'
),
cte3 as (
select flight_no, fare_conditions,amount, departure_airport, arrival_airport
from cte
where fare_conditions = 'Economy'
)
select distinct city
from cte2
join cte3 on cte2.flight_no = cte3.flight_no
join airports a on a.airport_code = cte3.departure_airport or a.airport_code = cte3.arrival_airport 
where cte2.amount<cte3.amount



--3) Есть ли самолеты, не имеющие бизнес - класса?
with cte as (
select distinct model, array_agg(distinct fare_conditions) as fares
from aircrafts a 
join seats s on s.aircraft_code = a.aircraft_code
group by model
)
select model
from cte
where 'Business' != all(fares)


--4) Найдите количество занятых мест для каждого рейса, процентное отношение количества занятых мест к 
--общему количеству мест в самолете, добавьте накопительный итог вывезенных пассажиров по каждому аэропорту на каждый день.

with occ as (
select distinct flight_id, count(ticket_no) as occupied
from ticket_flights tf 
group by flight_id
),
all_ as (
select distinct f.flight_id, count(seat_no) as overall
from seats s
join aircrafts a on s.aircraft_code = a.aircraft_code 
join flights f on f.aircraft_code = a.aircraft_code 
group by flight_id
)
select occ.flight_id, departure_airport, actual_departure, occupied, overall,
round(cast(occupied as float)/cast(overall as float)*100) as percent_,
sum(occupied) over(partition by departure_airport, date(actual_departure) order by actual_departure)
from occ
join all_ on all_.flight_id = occ.flight_id
join flights f on f.flight_id = all_.flight_id
join airports a on a.airport_code = f.departure_airport

--5) Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов. 
--Выведите в результат названия аэропортов и процентное отношение.
with cte as (
select distinct flight_no, departure_airport,
cast(count(flight_no) over (partition by flight_no)as float)/cast(count(flight_no) over() as float)*100 as route_percent
from flights f
)
select airport_name, route_percent
from airports a
join cte on a.airport_code = cte.departure_airport
order by airport_name, route_percent


--6)Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - 
--это три символа после +7

with cte as (
select passenger_id, contact_data, (contact_data->>'phone') as phone
from tickets
)
select count(passenger_id), substring(phone, 3, 3)
from cte
group by substring(phone, 3, 3)


--7) Между какими городами не существует перелетов?

with cte as (
select a1.city  as air1, a2.city as air2
from airports a1, airports a2
),
cte2 as (
select air1, air2
from cte
except
select distinct ai1.city as city1,ai2.city as city2
from flights f 
join airports ai1 on f.departure_airport = ai1.airport_code 
join airports ai2 on f.arrival_airport = ai2.airport_code 
)
select *
from cte2
where air1>air2



--8)Классифицируйте финансовые обороты (сумма стоимости билетов) по маршрутам:
--До 50 млн - low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high
--Выведите в результат количество маршрутов в каждом классе.

with cte as (
select flight_no, tf.ticket_no, amount
from ticket_flights tf
join flights f on f.flight_id = tf.flight_id
),
cte2 as (
select flight_no, sum(amount) as sum_amount
from cte
group by flight_no
),
cte3 as (
select flight_no,
case 
	when sum_amount < 50000000 then 'low'
	when sum_amount<150000000 then 'middle'
	else 'high'
end as case_
from cte2
)
select case_, count(flight_no)
from cte3
group by case_


--9) Выведите пары городов между которыми расстояние более 5000 км

select *
from (
select one, two,
6371 * acos (
sin(radians(la1))
* sin(radians(la2))
+ cos(radians(la1))
* cos(radians(la2))
* cos(radians(lo1) - radians(lo2))) as distance
from (
select a.city as one, a2.city as two, a.longitude as lo1, a.latitude as la1,
a2.longitude as lo2,a2.latitude as la2
from airports a, airports a2
where a.city<a2.city
) t1
) t2
where distance > 5000
