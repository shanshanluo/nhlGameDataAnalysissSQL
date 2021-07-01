use nhl;

-- how many records for each table
select count(*) from game;
select count(*) from game_goalie_stats;
select count(*) from game_plays;
select count(*) from game_plays_players; 
select count(*) from game_shifts;
select count(*) from game_skater_stats;
select count(*) from game_teams_stats;
-- 2409 players
select count(*) from player_info;
-- 33 teams
select count(*) from team_info;
/****************************************************/
--
-- Explore team info
select * from team_info;
-- How many teams in each franchise Id - 2 teams for franchise_id: 28 and 35. 1 for all other franchises
select franchise_id, count(*) as total_teams
	from team_info
    group by franchise_id
    order by total_teams desc;
/****************************************************/
--
-- Explore player_info
select * from player_info limit 20;

-- How many players from each country
-- Outcome: Canada has the most players followed by USA
select nationality, count(*) as count
  from player_info
  group by nationality
  order by count desc;
  
-- How many players in each country at each primary position
-- Players averege age for each position in each country
-- Output: orders for each primary position: CAN - USA - SWE - FIN
-- Ouput: at each position, average age of USA players is younger or equal to the average age of Canada players
 select primary_position, nationality, count(*) as players,
			floor(avg(datediff(curdate(), birth_date)/365)) as average_age,
            -- ceiling(med(datediff(curdate(), birth_date)/365)) as median_age,
            floor(max(datediff(curdate(), birth_date)/365)) as max_age,
            floor(min(datediff(curdate(), birth_date)/365)) as min_age
  from player_info
  group by primary_position, nationality
  order by primary_position, players desc;
/*********************************************************************/
--
-- Explore game
select * from game limit 10;

-- What is the average away_goal and average home_goal for all games in each season
-- Output: H0: For all the games from 2010 season to 2018 season, average goals of home team is higher than that of away team.
-- Output: Why 2012 season has way less games than other season ?? - season lockout !
select sub.*,  (sub.avg_home_goals - sub.avg_away_goals) as diff
	from 
    (
		select season, count(*) as total_games, round(avg(away_goals), 2) as avg_away_goals, 
			round(avg(home_goals), 2) as avg_home_goals
		from game
		group by season
	) sub
    order by season;

-- How many distict venues in all these years
select count(*) from 
(
	select distinct venue from game
) sub;

-- How mant games hold in each venue for each season
create view games_venue
	as 
		select season, venue, count(*) as total_games
		from game
		group by season, venue
		order by season, total_games desc;
select * from games_venue;

-- Which venue holds the most games and which hold the least games for each season
-- Ouput: There could be multiple venues that hold most games or least games in one season
-- Output: games distribution across all venues are more evenly than any other season.
select * from
(
select gv.season, sub.max_total, gv.venue as max_venue
	from games_venue as gv
	inner join (
		select season,
			max(total_games) as max_total,
            min(total_games) as min_total
		from games_venue
        group by season
    ) as sub
    on gv.season=sub.season and gv.total_games=sub.max_total
 ) as sub_max
inner join
(
	select gv.season, sub.min_total, gv.venue as min_venue
	from games_venue as gv
	inner join (
		select season,
			max(total_games) as max_total,
            min(total_games) as min_total
		from games_venue
        group by season
    ) as sub
    on gv.season=sub.season and gv.total_games=sub.min_total
) as sub_min
on sub_max.season = sub_min.season;
/****************************************************************************/
--
-- Explore game_team_stats
select * from game_teams_stats limit 10;

-- how many wons for each team in each season
create view team_wins_season
	as
		select sub.*, 
			round(total_wins/total_games, 2) as winning_rate
		from (
			select game.season, team_id, count(*) as total_games,
				sum(won='TRUE') as  'total_wins',
				sum(won='FALSE')  as 'total_lose'
			from game_teams_stats as gts
				inner join game
				on gts.game_id = game.game_id
			group by game.season, team_id
		) sub
		having winning_rate > 0.5
		order by season, winning_rate desc;
select * from team_wins_season;

-- Top-3 teams in each season
select season, team_id, winning_rate, team_rank
	from (
		select season, team_id, winning_rate,
				@team_rank := if(@current_season=season, @team_rank+1, 1) as team_rank,
				@current_season := season
		from team_wins_season
		order by season, winning_rate desc
	) ranking
	where team_rank <= 3;

-- Which team appears in seasonal top-3 the most
-- team_id 5 was in top3 for 5 times followed by team_id 6 with 3 times.
-- Total 15 teams have been in top3 at least once.
select team_id, count(*) as counts_top3
	from 
    (
		select season, team_id, winning_rate, team_rank
		from (
			select season, team_id, winning_rate,
					@team_rank := if(@current_season=season, @team_rank+1, 1) as team_rank,
                    @current_season,
					@current_season := season
			from team_wins_season
			order by season, winning_rate desc
		) ranking
	where team_rank <= 3
    ) top3
    group by team_id
    order by counts_top3 desc;
/*******************************************************************/
--
-- Explore game_skate_stats and game_goalie_stats
select * from game_skater_stats limit 20;
select * from game_goalie_stats limit 10;

-- how many skaters in each team played for each game
select game_id, team_id, count(distinct player_id) as total_players
	from game_skater_stats
    group by game_id, team_id
--    order by game_id, team_id;
    order by total_players desc;
select game_id, team_id, count(distinct player_id) as total_players
	from game_goalie_stats
    group by game_id, team_id
    order by game_id, team_id;
    
-- which players goaled in each game
create view players_goals
	as
		select game_id, team_id, player_id, goals
		from game_skater_stats
		having goals > 0
		order by game_id, team_id, goals;
select * from players_goals;

-- Ranking of players by their total goals in each season
create view player_goals_season
as 
	select left(cast(game_id as char), 4) as season, player_id,
			sum(goals) as total_goals
	from players_goals
	group by season, player_id
    order by season, total_goals desc;
select * from player_goals_season;
    
set @current_season := 0;
set @player_rank := 0;

select ranks.season, ranks.player_id, ranks.total_goals, ranks.player_rank
from
(
	select season, player_id, total_goals, 
			@player_rank := if(@current_season=season, @player_rank+1, 1)  as player_rank,
            @current_season := season
	from player_goals_season
	order by season, total_goals desc
) ranks
where ranks.player_rank <= 3;





/********************************************************************/
--  Explore game_plays_players and player_info
select * from game_plays_players;
select * from player_info; 

-- how many games are recorded in game_plays_players
select count(distinct game_id) from game_plays_players;
-- how many plays for each game
select game_id, count(distinct play_id) as total_plays
	from game_plays_players
    group by game_id
    order by total_plays desc;
