------------------------ex01------------------------
CREATE OR REPLACE PROCEDURE add_p2p_check(
    IN p_check_peer VARCHAR,
    IN p_checker_peer VARCHAR,
    IN p_task_name VARCHAR,
    IN p_state status,
    IN p_time TIME
)
LANGUAGE PLPGSQL
AS $$
BEGIN
    IF p_state = 'Start' THEN
        INSERT INTO Checks (Peer, Task, "Date")
        VALUES (p_check_peer, p_task_name, CURRENT_DATE);
        INSERT INTO P2P("Check", CheckingPeer, "State", "Time")
        VALUES ((SELECT MAX(ID) FROM Checks), p_checker_peer, p_state, p_time);
    ELSE
        INSERT INTO P2P("Check", CheckingPeer, "State", "Time")
        VALUES ((SELECT MAX(ID) FROM Checks), p_checker_peer, p_state, p_time);
    END IF;
END;
$$;

------------------------ex02------------------------
CREATE OR REPLACE PROCEDURE add_verter_check(
    IN p_nickname VARCHAR,
    IN p_task_name VARCHAR,
    "state" status,
    IN p_time TIME
) 
LANGUAGE PLPGSQL
AS $$
BEGIN
    WITH latest_p2p_step AS (
        SELECT ch.ID AS check_id
        FROM P2P AS pp
            LEFT JOIN Checks AS ch
                ON (ch.ID = pp."Check")
        WHERE (pp."Time" < p_time) AND (pp."State" = 'Success') AND (pp."Check" IS NOT NULL)
        ORDER BY pp."Time" DESC
        LIMIT 1
    )

    INSERT INTO Verter ("Check", "State", "Time")
    SELECT
        (SELECT MAX(ID) FROM Checks), "state", p_time
    WHERE EXISTS (SELECT 1 FROM latest_p2p_step);
END;
$$;

--CALL add_verter_check('aimeejoh', 'C3_s21_string+', 'Success', '15:30:00');

------------------------ex03------------------------
CREATE OR REPLACE FUNCTION p2p_update_points()
RETURNS TRIGGER AS $$
DECLARE
  peer_value VARCHAR;
BEGIN
  SELECT Peer INTO peer_value
  FROM Checks
  WHERE Checks.ID = NEW."Check"
  LIMIT 1;
  IF NEW."State" IN ('Success', 'Failure') THEN
    	UPDATE TransferredPoints
    	SET PointsAmount = PointsAmount + 1
    	WHERE NEW.CheckingPeer = TransferredPoints.CheckingPeer 
		AND peer_value = TransferredPoints.CheckedPeer;
	ELSE 
		IF NOT EXISTS (
			SELECT *
			FROM TransferredPoints
			WHERE NEW.CheckingPeer = TransferredPoints.CheckingPeer 
			AND peer_value = TransferredPoints.CheckedPeer
		) THEN
		INSERT INTO TransferredPoints(CheckingPeer, CheckedPeer)
		VALUES(NEW.CheckingPeer, (SELECT Peer
							FROM Checks
							WHERE Checks.ID = NEW."Check"
							LIMIT 1));
		END IF;
	END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER trg_p2p_update_points
AFTER INSERT ON P2P
FOR EACH ROW
EXECUTE FUNCTION p2p_update_points();

------------------------ex04------------------------
CREATE OR REPLACE FUNCTION valid_xp()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.XPAmount > (SELECT Tasks.MaxXP
					  FROM Checks
					  JOIN Tasks ON Tasks.Title = Checks.Task
					  JOIN XP ON Checks.ID = XP."Check"
					  LIMIT 1)
		THEN RAISE EXCEPTION 'XP amount can''''t exceed maximum XP for current task';			
	END IF;
	IF (SELECT COUNT(*)
	   FROM Checks
	   LEFT JOIN Verter ON Verter."Check" = Checks.ID
	   LEFT JOIN P2P ON P2P."Check" = Checks.ID
	   WHERE ((Verter."State" = 'Success' OR Verter."State" IS NULL) AND P2P."State" = 'Success')) > 0
	THEN RETURN NEW;
	ELSE RETURN NULL;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_valid_xp
BEFORE INSERT ON XP
FOR EACH ROW
EXECUTE FUNCTION valid_xp();
