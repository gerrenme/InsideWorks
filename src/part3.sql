-------------------------ex01------------------------- 
CREATE OR REPLACE FUNCTION hr_tranferred_ponts()
RETURNS TABLE(Peer1 VARCHAR, Peer2 VARCHAR, "PointsAmount" BIGINT) AS $$
BEGIN
	RETURN QUERY
	WITH reversed AS (
		SELECT
			CASE WHEN CheckingPeer > CheckedPeer THEN CheckingPeer ELSE CheckedPeer END AS CheckingPeer,
			CASE WHEN CheckingPeer > CheckedPeer THEN CheckedPeer ELSE CheckingPeer END AS CheckedPeer,
			CASE WHEN CheckingPeer > CheckedPeer THEN PointsAmount ELSE -PointsAmount END AS PointsAmount
		FROM TransferredPoints
	)
	SELECT CheckingPeer AS peer1, CheckedPeer AS Peer2, SUM(PointsAmount) FROM reversed
	GROUP BY CheckingPeer, CheckedPeer;
END;
$$ LANGUAGE plpgsql;

-------------------------ex02------------------------- 
CREATE OR REPLACE FUNCTION completed_tasks()
RETURNS TABLE(Peer VARCHAR, "Task" VARCHAR, "XPAmount" BIGINT) AS $$
BEGIN
	RETURN QUERY
	SELECT Checks.Peer AS Peer, Checks.Task AS Task, XPAmount AS XP
	FROM XP
	JOIN Checks ON Checks.ID = XP."Check";
END;
$$ LANGUAGE plpgsql;

-------------------------ex03------------------------- 
CREATE OR REPLACE FUNCTION whole_day_work(pday DATE)
RETURNS TABLE("Peer" VARCHAR) AS $$
BEGIN
RETURN QUERY
	 SELECT Peer
	 FROM TimeTracking
	 WHERE "Date" = pday AND "State" = '2' AND "Time" = '23:59:59';
END;
$$ LANGUAGE plpgsql;

--SELECT * FROM whole_day_work('2021-07-27');

-------------------------ex04------------------------- 
CREATE OR REPLACE FUNCTION prp_change()
RETURNS TABLE(Peer VARCHAR, PointsChange NUMERIC) AS $$
BEGIN
	RETURN QUERY
	WITH obtained
	AS (
		SELECT CheckingPeer AS Peer, SUM(PointsAmount) AS total_points
		FROM TransferredPoints
		GROUP BY CheckingPeer
	),
	lost AS (
		SELECT CheckedPeer AS Peer, -SUM(PointsAmount) AS total_points
		FROM TransferredPoints
		GROUP BY CheckedPeer
	),
	total AS (
		SELECT obtained.Peer, obtained.total_points
		FROM obtained
		UNION 
		SELECT lost.Peer, lost.total_points
		FROM lost
	)
	SELECT total.Peer, SUM(total.total_points)
	FROM total
	GROUP BY total.Peer;
END;
$$ LANGUAGE plpgsql;

-------------------------ex05------------------------- 
CREATE OR REPLACE FUNCTION prp_change_short_method()
RETURNS TABLE(Peer VARCHAR, PointsChange NUMERIC) AS $$
BEGIN
	RETURN QUERY
	WITH sums AS (
		SELECT Peer1 AS Peer, SUM("PointsAmount") AS PointsChange
		FROM hr_tranferred_ponts()
		GROUP BY Peer1
		UNION
		SELECT Peer2 AS Peer, -SUM("PointsAmount") AS PointsChange
		FROM hr_tranferred_ponts()
		GROUP BY Peer2
	)
	SELECT sums.Peer, SUM(sums.PointsChange)
	FROM sums
	GROUP BY sums.Peer;
END;
$$ LANGUAGE plpgsql;

-------------------------ex06------------------------- 
CREATE OR REPLACE FUNCTION popular_checks()
RETURNS TABLE(Biba DATE, Boba VARCHAR) AS $$
BEGIN
	RETURN QUERY
	SELECT ranked."Date", ranked.Task
	FROM (
		SELECT CheckDate AS "Date", TaskName AS Task, 
		ROW_NUMBER() OVER (PARTITION BY CheckDate ORDER BY TaskCount DESC) AS row_num
		FROM(
			SELECT "Date" AS CheckDate, Task AS TaskName, COUNT(*)
			AS TaskCount
			FROM Checks
			GROUP BY CheckDate, Task
		) AS COUNTS
	)AS ranked
	WHERE row_num = 1;
END;
$$ LANGUAGE plpgsql;

-------------------------ex07------------------------- 
CREATE OR REPLACE FUNCTION finished_block(pblock VARCHAR)
RETURNS TABLE (Peer VARCHAR, "Day" DATE ) AS $$
BEGIN
RETURN QUERY
	WITH cur_block AS (
		SELECT Task
		FROM Checks
		WHERE Task LIKE '%' || pblock || '%'
	)
	SELECT DISTINCT Checks.Peer , MAX(Checks."Date") AS "Day"
	FROM cur_block
	JOIN Checks ON Checks.Task = cur_block.Task
	JOIN XP ON Checks.ID = XP."Check"
	GROUP BY Checks.Peer
	HAVING COUNT(DISTINCT Checks.Task) = (SELECT COUNT(DISTINCT Task) FROM cur_block);
END;
$$ LANGUAGE plpgsql;

--SELECT * FROM finished_block('C');

-------------------------ex08------------------------- 
CREATE OR REPLACE FUNCTION best_checkers()
RETURNS TABLE(Peer VARCHAR, RecommendedPeer VARCHAR) AS $$
BEGIN
RETURN QUERY
	WITH friends_recommend AS (
		SELECT Recommendations.Peer, Recommendations.RecommendedPeer, COUNT(Recommendations.RecommendedPeer) AS recoms
		FROM Recommendations
		GROUP BY Recommendations.Peer, Recommendations.RecommendedPeer
	),
	peer_recom_counts AS (
		SELECT friends_recommend.RecommendedPeer, COUNT(friends_recommend.RecommendedPeer) AS total_recoms, Friends.Peer1 AS Peer
		FROM friends_recommend
		LEFT JOIN Friends ON friends_recommend.Peer = Friends.Peer2
		WHERE Friends.Peer1 != friends_recommend.RecommendedPeer
		GROUP BY friends_recommend.RecommendedPeer, friends_recommend.Peer,Friends.Peer1
	),
	result_table AS (
		SELECT peer_recom_counts.Peer, peer_recom_counts.RecommendedPeer, total_recoms, 
			ROW_NUMBER() OVER (PARTITION BY peer_recom_counts.Peer ORDER BY COUNT(*) DESC) AS rank
		FROM peer_recom_counts
		WHERE total_recoms = (SELECT MAX(total_recoms) 
						FROM peer_recom_counts) AND peer_recom_counts.Peer != peer_recom_counts.RecommendedPeer
		GROUP BY peer_recom_counts.Peer, peer_recom_counts.RecommendedPeer, total_recoms
		ORDER BY peer_recom_counts.Peer ASC
	)
	SELECT result_table.Peer, result_table.RecommendedPeer
	FROM result_table
	WHERE rank = 1;
END;
$$ LANGUAGE plpgsql;

-------------------------ex09------------------------- 
CREATE OR REPLACE FUNCTION blocks_percentage(pblock1 VARCHAR, pblock2 VARCHAR)
RETURNS TABLE (StartedBlock1 BIGINT, StartedBlock2 BIGINT, StartedBothBlocks BIGINT, DidntStatrAnyBlocks BIGINT) AS $$
BEGIN
RETURN QUERY
	WITH started_first AS (
		SELECT DISTINCT Peer
		From Checks
		WHERE Task LIKE '%' || pblock1 || '%'
	),
	started_second AS (
		SELECT DISTINCT Peer
		From Checks
		WHERE Task LIKE '%' || pblock2 || '%'
	),
	started_only_first AS(
		SELECT *
		FROM started_first
		LEFT JOIN started_second ON started_second.Peer = started_first.Peer
		WHERE started_second.Peer IS NULL
	),
	started_only_second AS(
		SELECT *
		FROM started_second
		LEFT JOIN started_first ON started_second.Peer = started_first.Peer
		WHERE started_first.Peer IS NULL
	),
	started_both AS (
		SELECT *
		FROM started_first
		INTERSECT
		SELECT *
		FROM started_second
	),
	didnt_start AS (
		SELECT Nickname
		FROM Peers
		WHERE Nickname NOT IN (SELECT * FROM started_first) AND Nickname NOT IN (SELECT * FROM started_second)
	)
	SELECT 100 * (SELECT COUNT(*)
			FROM started_only_first) / 
			(SELECT COUNT(*) 
			FROM Peers), 
			100 * (SELECT COUNT(*)
			FROM started_only_second) / 
			(SELECT COUNT(*) 
			FROM Peers),
			100 * (SELECT COUNT(*)
			FROM started_both) / 
			(SELECT COUNT(*) 
			FROM Peers),
			100 * (SELECT COUNT(*)
			FROM didnt_start) / 
			(SELECT COUNT(*) 
			FROM Peers)
	FROM started_first, started_second, started_both, didnt_start
	LIMIT 1;
END;
$$ LANGUAGE plpgsql;

--SELECT * FROM blocks_percentage('D', 'C');

-------------------------ex10------------------------- 
CREATE OR REPLACE FUNCTION birthday_submitions()
RETURNS TABLE (SuccessfulChecks BIGINT, UnsuccessfulChecks BIGINT)
AS $$
BEGIN
RETURN QUERY
	WITH passed AS (
    SELECT COUNT(*) AS amount
    FROM Peers AS pr 
        INNER JOIN Checks AS ch
            ON (ch.Peer = pr.Nickname)
        LEFT JOIN Verter ON Verter."Check" = ch.ID
	   LEFT JOIN P2P ON P2P."Check" = ch.ID
	   WHERE ((Verter."State" = 'Success' OR Verter."State" IS NULL) AND P2P."State" = 'Success' AND (EXTRACT(DAY FROM pr.Birthday) = EXTRACT(DAY FROM ch."Date")) AND (EXTRACT(MONTH FROM pr.Birthday) = EXTRACT(MONTH FROM ch."Date")))
    GROUP BY pr.Nickname
), missed AS (
    SELECT COUNT(*) AS amount
    FROM Peers AS pr 
        INNER JOIN Checks AS ch
            ON (ch.Peer = pr.Nickname)
        LEFT JOIN Verter ON Verter."Check" = ch.ID
	   LEFT JOIN P2P ON P2P."Check" = ch.ID
	   WHERE ((Verter."State" = 'Failure' OR Verter."State" IS NULL) AND P2P."State" = 'Failure' AND (EXTRACT(DAY FROM pr.Birthday) = EXTRACT(DAY FROM ch."Date")) AND (EXTRACT(MONTH FROM pr.Birthday) = EXTRACT(MONTH FROM ch."Date")))
    GROUP BY pr.Nickname
), total_peers AS (
    SELECT COALESCE(ps.amount, 0) + COALESCE((SELECT ms.amount FROM missed AS ms), 0) AS amount
	FROM passed AS ps
)

SELECT (COALESCE((ps.amount::FLOAT), 0)/(SELECT amount FROM total_peers)*100)::BIGINT AS SuccessfulChecks, (COALESCE((SELECT amount FROM missed)::FLOAT, 0)/(SELECT amount FROM total_peers)*100)::BIGINT AS UnsuccessfulChecks
FROM passed AS ps;
END;
$$ LANGUAGE plpgsql;

-- INSERT INTO P2P("Check", CheckingPeer, "State", "Time") VALUES
-- (22, 'heidedra', 'Start', '12:15:12'), 
-- (22, 'heidedra', 'Success', '12:25:12');

-------------------------ex12------------------------- 
CREATE OR REPLACE FUNCTION previous_tasks() 
RETURNS TABLE("Task" VARCHAR, "PrevCount" INT) AS $$
BEGIN
	RETURN QUERY
	WITH RECURSIVE TaskCTE AS (
		SELECT Title, 0 AS PrevCount
		FROM Tasks
		WHERE ParentTask IS NULL

		UNION ALL

		SELECT t.Title, TaskCTE.PrevCount + 1
		FROM Tasks t
		INNER JOIN TaskCTE ON t.ParentTask = TaskCTE.Title
	)
	SELECT Title AS Task, PrevCount
	FROM TaskCTE;
END;
$$ LANGUAGE plpgsql;

-------------------------ex14------------------------- 
CREATE OR REPLACE FUNCTION most_experience()
RETURNS TABLE (Peer VARCHAR, XP NUMERIC)
AS $$
BEGIN
	RETURN QUERY
    SELECT ch.Peer AS Peer, SUM(XP.XPAmount) AS XP
    FROM Checks AS ch
        INNER JOIN XP
            ON (XP."Check" = ch.ID)
    GROUP BY ch.Peer
    ORDER BY 2 DESC
    LIMIT 1;
END;
$$ LANGUAGE PLPGSQL;

-------------------------ex15------------------------- 
CREATE OR REPLACE FUNCTION coming_peers (find_time TIME, N INT)
RETURNS TABLE (Peer VARCHAR)
AS $$
BEGIN
	RETURN QUERY
		SELECT tt.Peer 
		FROM TimeTracking AS tt
		WHERE tt."Time" < find_time
		GROUP BY tt.Peer
		HAVING COUNT(*) >= N;
END;
$$ LANGUAGE PLPGSQL;

--SELECT * FROM coming_peers(TIME '19:08:52', 1);

-------------------------ex16------------------------- 
CREATE OR REPLACE FUNCTION print_peer_visits(N DATE, M INT)
RETURNS TABLE (Peer VARCHAR)
AS $$
BEGIN
	RETURN QUERY
    SELECT tt.peer
    FROM Peers AS pr        
        INNER JOIN TimeTracking AS tt
            ON (tt.Peer = pr.Nickname)    
    WHERE ("State" = '2') AND ("Date" < N)
    GROUP BY tt.Peer    
    HAVING COUNT(*) > M;
END;
$$ LANGUAGE PLPGSQL;

--SELECT * FROM print_peer_visits('2021-07-27', 2);

-------------------------ex17-------------------------  
CREATE OR REPLACE PROCEDURE calculate_early_entry_percentage()
AS $$
DECLARE
    result_set REFCURSOR;
    month_data RECORD;
    early_entries INTEGER;
    total_entries INTEGER;
    percentage FLOAT;
BEGIN
    OPEN result_set FOR
    SELECT
        TO_CHAR(tt."Date", 'YYYY-MM') AS "Month",
        COUNT(*) AS "TotalEntries",
        COUNT(*) FILTER (WHERE EXTRACT(HOUR FROM tt."Time") < 12) AS "EarlyEntries"
    FROM TimeTracking AS tt
        INNER JOIN Peers AS pr
            ON (tt.Peer = pr.Nickname)
    WHERE
        EXTRACT(MONTH FROM pr.Birthday) = EXTRACT(MONTH FROM tt."Date")
    GROUP BY
        "Month"
    ORDER BY
        "Month" ASC;

    LOOP
        FETCH result_set INTO month_data;
        EXIT WHEN NOT FOUND;

        early_entries := month_data."EarlyEntries";
        total_entries := month_data."TotalEntries";

        IF total_entries > 0 THEN
            percentage := (early_entries::FLOAT / total_entries::FLOAT) * 100;
        ELSE
            percentage := 0;
        END IF;        

        RAISE NOTICE 'Month: %, Percentage of Early Entries: %', month_data."Month", percentage;
    END LOOP;

    CLOSE result_set;
END;
$$ LANGUAGE PLPGSQL;
