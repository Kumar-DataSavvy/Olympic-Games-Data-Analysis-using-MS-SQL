create database olympic

use olympic

select * from athlete_events
select * from noc_regions

--Querying for dataset analysis:

--1. How many Olympics games have been held?
select count(distinct Games)
from olympic.dbo.athlete_events

--2. List down all Olympic games held so far?
select distinct Year, Games, Season, City
from athlete_events
order by Year

--3. Mention the total number of nations who participated in each Olympics game?
select Year, Games, count(distinct region) as no_of_country 
from athlete_events ae
join noc_regions nr
on ae.NOC = nr.NOC
group by Year, Games
order by Year

--4. Which year saw the highest and lowest no of countries participating in the Olympics?
with CTE
as
(select Year, count(distinct region) as no_of_country,
ROW_NUMBER() over(order by count(distinct region) asc) as asc_rank,
ROW_NUMBER() over(order by count(distinct region) desc) as desc_rank
from athlete_events ae
join noc_regions nr on ae.NOC=nr.NOC
group by Year)
select
    t1.Year as min_country_count_year, 
    t1.no_of_country as min_country_count,
    t2.Year as max_country_count_year,
    t2.no_of_country as max_country_count
from CTE t1
join CTE t2 on t1.asc_rank = 1 and t2.desc_rank = 1

--5. Which nation has participated in all of the Olympic games?
select region, count(distinct Games) as no_of_games
from athlete_events as ae
join noc_regions as nr on nr.NOC= ae.NOC
group by region
having count(distinct Games)= 51

--6. Identify the sport which was played in all summer Olympics.
--Method 1:
select count(distinct Games) from athlete_events
where Season = 'Summer'                     -- to get the no of summer olympic games.

select e.Sport, count(e.Sport) 
from
(select distinct Games,Sport from athlete_events
where Season= 'Summer') e
group by e.sport
having count(e.Sport)= 29

--Method 2:
with SummerGames as 
    (select distinct Games
    from athlete_events
    where Season = 'Summer'),

SportCounts as 
    (select Sport, count(distinct Games) as games_count
    from athlete_events
    where Season = 'Summer'
    and Games in (select Games from SummerGames)
    group by Sport)

select Sport, games_count
from SportCounts
where games_count = (select count(*) from SummerGames)

--7. Which Sports were just played only once in the Olympics?
select e.Sport, count(e.Sport)
from
(select distinct Sport, Year from athlete_events) e
group by e.Sport
having count(e.Sport)= 1

--8. Fetch the total no of sports played in each Olympic game.
select distinct Games, count(distinct Sport) as no_of_sports
from athlete_events
group by Games
order by no_of_sports desc

--9. Fetch details of the oldest athletes to win a gold medal.
select e.*
from (select *, DENSE_RANK() over(order by Age desc) as rnk
      from athlete_events
	  where Medal='Gold') e
where rnk=1

--10. Find the Ratio of male and female athletes who participated in all Olympic games.
with t1 (div)
as
(select cast(sq.male_count as float)/ cast(sq.female_count as float) as div
from
(select sum(case when Sex='M' then 1 else 0 end) as male_count,
       sum(case when Sex='F' then 1 else 0 end) as female_count 
from athlete_events) as sq)

select concat('1:', round(div,2)) as Gender_ration from t1

--11. Fetch the top 5 athletes who have won the most gold medals.
with t1(Name, rank, medal_count)
as
(select Name, DENSE_RANK() over(order by medal_count desc) as rank, medal_count
from
(select Name, count(Medal) as medal_count from athlete_events
where Medal='Gold'
group by Name) as sq)

select * from t1
where rank<=5

--12. Fetch the top 5 athletes who have won the most medals (gold/silver/bronze).
with t1(Name, rank, medal_count)
as
(select Name, DENSE_RANK() over(order by medal_count desc) as rank, medal_count
from
(select Name, count(Medal) as medal_count from athlete_events
where Medal in ('Gold','Silver','Bronze')
group by Name) sq)

select * from t1
where rank<= 5

--13. Fetch the top 5 most successful countries in Olympics. Success is defined by no of medals won.
with t1(country_rank, region, medal_count)
as
(select DENSE_RANK() over(order by medal_count desc) as country_rank, region, medal_count
from
(select region, sum(case when Medal in ('Gold','Silver','Bronze') then 1 else 0 end) as medal_count
from athlete_events ae
join noc_regions nr on ae.NOC= nr.NOC
group by region)sq)

select * from t1
where country_rank<=5

--14. List down total gold, silver and bronze medals won by each country.
select region, sum(case when Medal ='Gold' then 1 else 0 end)as total_gold_medals,
               sum(case when Medal ='Silver' then 1 else 0 end)as total_silver_medals,
			   sum(case when Medal ='Bronze' then 1 else 0 end)as total_bronze_medals
from athlete_events ae
join noc_regions nr on nr.NOC=ae.NOC
group by region
order by total_gold_medals desc, total_silver_medals desc, total_bronze_medals desc

--15. List down total gold, silver and broze medals won by each country corresponding to each olympic games.
select distinct Games, region, sum(case when Medal ='Gold' then 1 else 0 end)as total_gold_medals,
               sum(case when Medal ='Silver' then 1 else 0 end)as total_silver_medals,
			   sum(case when Medal ='Bronze' then 1 else 0 end)as total_bronze_medals
from athlete_events ae
join noc_regions nr on ae.NOC = nr.NOC
group by Games, region
order by Games, region

--16. Identify which country won the most gold, most silver, and most bronze medals in each Olympic game.
with t1(Games, region, no_gold, no_silver, no_bronze)
as
(select Games, region, sum(case when Medal ='Gold' then 1 else 0 end)as no_gold,
               sum(case when Medal ='Silver' then 1 else 0 end)as no_silver,
			   sum(case when Medal ='Bronze' then 1 else 0 end)as no_bronze
from athlete_events ae
join noc_regions nr on ae.NOC = nr.NOC
group by Games, region)

select distinct Games,
concat ((FIRST_VALUE (region) over (partition by Games order by no_gold desc)), 
		' - ', FIRST_VALUE (no_gold) over (partition by Games order by no_gold desc)) as Max_gold,
--query uses the window function FIRST_VALUE() to get the first value of 'region' within each partition defined by 'Games', 
--with the rows ordered by 'no_gold' in descending order.
concat ((FIRST_VALUE (region) over (partition by Games order by no_silver desc)),
		' - ', FIRST_VALUE (no_silver) over (partition by Games order by no_silver desc)) as Max_silver,
concat ((FIRST_VALUE (region) over (partition by Games order by no_bronze desc)),
		' - ', FIRST_VALUE (no_bronze) over (partition by Games order by no_bronze desc)) as Max_bronze
from t1
order by Games

--17. Identify which country won the most gold, most silver, most bronze medals and the most medals in each olympic games.
with t1(Games, region, no_gold, no_silver, no_bronze, total_medals)
as
(select Games, region, sum(case when Medal ='Gold' then 1 else 0 end)as no_gold,
               sum(case when Medal ='Silver' then 1 else 0 end)as no_silver,
			   sum(case when Medal ='Bronze' then 1 else 0 end)as no_bronze,
			   sum(case when Medal in ('Gold','Silver','Bronze') then 1 else 0 end) as total_medals
from athlete_events ae
join noc_regions nr on ae.NOC = nr.NOC
group by Games, region)

select distinct Games,
concat ((FIRST_VALUE (region) over (partition by Games order by no_gold desc)), 
		' - ', FIRST_VALUE (no_gold) over (partition by Games order by no_gold desc)) as Max_gold,
concat ((FIRST_VALUE (region) over (partition by Games order by no_silver desc)),
		' - ', FIRST_VALUE (no_silver) over (partition by Games order by no_silver desc)) as Max_silver,
concat ((FIRST_VALUE (region) over (partition by Games order by no_bronze desc)),
		' - ', FIRST_VALUE (no_bronze) over (partition by Games order by no_bronze desc)) as Max_bronze,
concat ((FIRST_VALUE (region) over (partition by Games order by total_medals desc)),
		' - ', FIRST_VALUE (total_medals) over (partition by Games order by total_medals desc)) as Max_medals
from t1
order by Games

--18. Which countries have never won gold medal but have won silver/bronze medals?
with t1(region, no_gold, no_silver, no_bronze)
as
(select region, sum(case when Medal ='Gold' then 1 else 0 end)as no_gold,
               sum(case when Medal ='Silver' then 1 else 0 end)as no_silver,
			   sum(case when Medal ='Bronze' then 1 else 0 end)as no_bronze
from athlete_events ae
join noc_regions nr on ae.NOC = nr.NOC
group by region)

select * from t1
where no_gold= 0 and (no_silver>0 or no_bronze>0)
order by no_silver desc, no_bronze desc

--19. In which Sport, did India win its highest medals?
with t1
as
(select Sport, region,total_medals, DENSE_RANK() over(partition by region order by total_medals desc) as rank
from
(select Sport, region, sum(case when Medal in ('Gold','Silver','Bronze') then 1 else 0 end) as total_medals
from athlete_events ae
join noc_regions nr on ae.NOC = nr.NOC
group by Sport, region)sq)

select Sport, total_medals from t1
where rank=1 and region='India'

--20. Break down all olympic games where India won medal for Hockey and how many medals in each olympic games.
select Games,Sport, region, sum(case when Medal in ('Gold','Silver','Bronze') then 1 else 0 end) as total_medals
from athlete_events ae
join noc_regions nr on ae.NOC = nr.NOC
where region='India' and Sport='Hockey'
group by Games, region, Sport
--having region='India' and Sport='Hockey'




