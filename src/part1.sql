DROP TABLE IF EXISTS Peers CASCADE;
DROP TABLE IF EXISTS Verter CASCADE;
DROP TABLE IF EXISTS Tasks CASCADE;
DROP TABLE IF EXISTS Friends CASCADE;
DROP TABLE IF EXISTS Checks CASCADE;
DROP TABLE IF EXISTS TransferredPoints CASCADE;
DROP TABLE IF EXISTS P2P CASCADE;
DROP TABLE IF EXISTS XP CASCADE;
DROP TABLE IF EXISTS TimeTracking CASCADE;
DROP TABLE IF EXISTS Recommendations CASCADE;

DROP FUNCTION IF EXISTS single_root();
DROP FUNCTION IF EXISTS only_one_start_p2p();
DROP FUNCTION IF EXISTS only_one_start_verter();
DROP FUNCTION IF EXISTS trg_p2p_update_points();
DROP FUNCTION IF EXISTS add_inverse_friend();
DROP FUNCTION IF EXISTS insert_new_state();
DROP FUNCTION IF EXISTS trg_p2p_update_points();
DROP FUNCTION IF EXISTS valid_xp();
DROP FUNCTION IF EXISTS hr_tranferred_ponts();
DROP FUNCTION IF EXISTS completed_tasks();
DROP FUNCTION IF EXISTS whole_day_work(pday DATE);
DROP FUNCTION IF EXISTS prp_change();
DROP FUNCTION IF EXISTS hr_prp_change();
DROP FUNCTION IF EXISTS popular_checks();
DROP FUNCTION IF EXISTS finished_block(pblock VARCHAR);
DROP FUNCTION IF EXISTS best_checkers();
DROP FUNCTION IF EXISTS blocks_percentage(pblock1 VARCHAR, pblock2 VARCHAR);
DROP FUNCTION IF EXISTS birthday_submitions();
DROP FUNCTION IF EXISTS submitted_tasks(task1 VARCHAR, task2 VARCHAR, task3 VARCHAR);
DROP FUNCTION IF EXISTS previous_tasks();
DROP FUNCTION IF EXISTS most_experience();
DROP FUNCTION IF EXISTS coming_peers (find_time TIME, N INT);
DROP FUNCTION IF EXISTS print_peer_visits(N DATE, M INT);
DROP FUNCTION IF EXISTS find_lucky_days(IN p_cons_days INT);
DROP FUNCTION IF EXISTS add_numbers(num1 INTEGER, num2 INTEGER);
DROP FUNCTION IF EXISTS ScalarPower(num FLOAT, pow INT);

DROP PROCEDURE IF EXISTS add_p2p_check(
    IN p_check_peer VARCHAR,
    IN p_checker_peer VARCHAR,
    IN p_task_name VARCHAR,
    IN p_state status,
    IN p_time TIME
);
DROP PROCEDURE IF EXISTS add_verter_check(
    IN p_nickname VARCHAR,
    IN p_task_name VARCHAR,
    "state" status,
    IN p_time TIME
);
DROP PROCEDURE IF EXISTS DropTablesStartingWithTableName();
DROP PROCEDURE IF EXISTS get_scalar_functions(OUT function_list TEXT[], OUT function_count INTEGER);
DROP PROCEDURE IF EXISTS destroy_all_dml_triggers(OUT destroyed_trigger_count INTEGER);
DROP PROCEDURE IF EXISTS search_objects_by_description(IN search_string TEXT);
DROP PROCEDURE IF EXISTS calculate_early_entry_percentage();

DROP TRIGGER IF EXISTS trg_Tasks ON Tasks;
DROP TRIGGER IF EXISTS trg_p2p_update_points ON P2P;
DROP TRIGGER IF EXISTS trg_verter ON Verter;
DROP TRIGGER IF EXISTS add_inverse_friend_insert_trigger ON Friends;
DROP TRIGGER IF EXISTS trg_timetracking ON TimeTracking;
DROP TRIGGER IF EXISTS valid_xp ON XP;


DROP TYPE IF EXISTS status;

CREATE TYPE status AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE IF NOT EXISTS Peers(
	Nickname VARCHAR PRIMARY KEY NOT NULL,
	Birthday DATE
);

CREATE TABLE IF NOT EXISTS Verter(
	ID SERIAL PRIMARY KEY ,
	"Check" BIGINT NOT NULL,
	"State" status,
	"Time" TIME NOT NULL
);

CREATE TABLE IF NOT EXISTS Tasks(
	Title VARCHAR PRIMARY KEY NOT NULL UNIQUE,
	ParentTask VARCHAR,
	MaxXP INT NOT NULL,
	CONSTRAINT fk_parent_task FOREIGN KEY (ParentTask) REFERENCES Tasks(Title),
	CONSTRAINT unique_pair CHECK (ParentTask != Title)
);

CREATE TABLE IF NOT EXISTS Friends (
  	ID SERIAL PRIMARY KEY ,
	Peer1 VARCHAR NOT NULL,
	Peer2 VARCHAR NOT NULL,
	CONSTRAINT fk_friends_peer1 FOREIGN KEY (Peer1) REFERENCES Peers(Nickname),
	CONSTRAINT fk_friends_peer2 FOREIGN KEY (Peer2) REFERENCES Peers(Nickname),
	CONSTRAINT unique_pair CHECK (Peer1 != Peer2)
);

CREATE TABLE IF NOT EXISTS Checks (
	ID SERIAL PRIMARY KEY,
	Peer VARCHAR NOT NULL,
	Task VARCHAR NOT NULL,
	"Date" DATE,
	CONSTRAINT fk_checks_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_checks_task FOREIGN KEY (Task) REFERENCES Tasks(Title)
);

CREATE TABLE IF NOT EXISTS TransferredPoints (
	ID SERIAL PRIMARY KEY ,
	CheckingPeer VARCHAR NOT NULL,
	CheckedPeer VARCHAR NOT NULL,
	PointsAmount INT NOT NULL DEFAULT 0,
	CONSTRAINT unique_pair CHECK (CheckingPeer != CheckedPeer),
	CONSTRAINT fk_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_checked_peer FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname)						 
);

CREATE TABLE IF NOT EXISTS P2P(
	ID SERIAL PRIMARY KEY ,
	"Check" BIGINT NOT NULL,
	CheckingPeer VARCHAR NOT NULL,
	"State" status,
	"Time" TIME NOT NULL,
	CONSTRAINT fk_p2p_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname)
);

CREATE TABLE IF NOT EXISTS XP (
	ID SERIAL PRIMARY KEY,
	"Check" BIGINT NOT NULL,
	XPAmount BIGINT NOT NULL,
	CONSTRAINT fk_check_id FOREIGN KEY ("Check") REFERENCES Checks(ID)
);

CREATE TABLE IF NOT EXISTS TimeTracking (
  ID SERIAL PRIMARY KEY,
  Peer VARCHAR NOT NULL,
  "Date" DATE NOT NULL,
  "Time" TIME WITHOUT TIME ZONE NOT NULL,
  "State" VARCHAR NOT NULL,
  CONSTRAINT valid_state CHECK ("State" IN ('1', '2')),
  CONSTRAINT fk_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname)
);

CREATE TABLE IF NOT EXISTS Recommendations (
	ID SERIAL PRIMARY KEY,
	Peer VARCHAR NOT NULL,
	RecommendedPeer VARCHAR NOT NULL,
	CONSTRAINT fk_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_recommendedpeer FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname),
	CONSTRAINT unique_pair CHECK (Peer != RecommendedPeer)
);

CREATE OR REPLACE FUNCTION single_root()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.ParentTask IS NULL THEN
		IF EXISTS (
			SELECT * 
			FROM Tasks
			WHERE Title = NEW.Title AND ParentTask IS NULL
		)
		THEN RAISE EXCEPTION 'There can be only one root task';
		END IF;
	END IF;
	IF NEW.ParentTask IS NOT NULL THEN
		IF NOT EXISTS (
			SELECT * 
			FROM Tasks
			WHERE ParentTask IS NULL
		)
		THEN RAISE EXCEPTION 'There is no root task yet';
		END IF;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_Tasks
BEFORE INSERT OR UPDATE ON Tasks
FOR EACH ROW
EXECUTE FUNCTION single_root();

CREATE OR REPLACE FUNCTION only_one_start_p2p()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW."State" = 'Start' THEN
		IF EXISTS (
			SELECT * 
			FROM P2P
			WHERE id = NEW.id AND "State" = 'Start'
		)
		THEN RAISE EXCEPTION 'Check already has Start status';
		END IF;
	END IF;
	IF NEW."State" IN ('Success', 'Failure') THEN
		IF NEW."Time" <= (SELECT "Time"
					   FROM P2P
					   WHERE NEW."Check" = P2P."Check"
					   ORDER BY "Time" DESC
					   LIMIT 1) THEN
		RAISE EXCEPTION 'Check can not be finished earlier then it''''s start';
		END IF;
		IF NOT EXISTS (
			SELECT * 
			FROM P2P
			WHERE "Check" = NEW."Check" AND "State" = 'Start'
		)
		THEN RAISE EXCEPTION 'Check doesn''''t have Start status';
		END IF;
	END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_p2p
BEFORE INSERT OR UPDATE ON P2P
FOR EACH ROW
EXECUTE FUNCTION only_one_start_p2p();

CREATE OR REPLACE FUNCTION only_one_start_verter()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW."State" = 'Start' THEN
		IF EXISTS (
			SELECT * 
			FROM Verter
			WHERE id = NEW.id AND "State" = 'Start'
		)
		THEN RAISE EXCEPTION 'Check already has Start status';
		END IF;
	END IF;
	IF NEW."State" IN ('Success', 'Failure') THEN
		IF NEW."Time" <= (SELECT "Time"
					   FROM Verter
					   WHERE NEW."Check" = Verter."Check"
					   ORDER BY "Time" DESC
					   LIMIT 1) THEN
		RAISE EXCEPTION 'Check can not be finished earlier then it''''s start';
		END IF;
		IF NOT EXISTS (
			SELECT * 
			FROM Verter
			WHERE "Check" = NEW."Check" AND "State" = 'Start'
		)
		THEN RAISE EXCEPTION 'Check doesn''''t have Start status';
		END IF;
	END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_verter
BEFORE INSERT OR UPDATE ON Verter
FOR EACH ROW
EXECUTE FUNCTION only_one_start_verter();

CREATE OR REPLACE FUNCTION trg_p2p_update_points()
RETURNS TRIGGER AS $$
DECLARE
  peer_value VARCHAR;
BEGIN
  IF NEW."State" IN ('Success', 'Failure') THEN
    BEGIN
      SELECT Peer INTO peer_value
      FROM Checks
      WHERE Checks.ID = NEW."Check"
      LIMIT 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE NOTICE 'No corresponding Peer found for Check ID %', NEW."Check";
        RETURN NEW;
    END;
	IF EXISTS (
		SELECT *
		FROM TransferredPoints
		WHERE NEW.CheckingPeer = TransferredPoints.CheckingPeer AND peer_value = TransferredPoints.CheckedPeer
	) THEN 
    	UPDATE TransferredPoints
    	SET PointsAmount = PointsAmount + 1
    	WHERE NEW.CheckingPeer = TransferredPoints.CheckingPeer AND peer_value = TransferredPoints.CheckedPeer;
	ELSE 
		INSERT INTO TransferredPoints
		VALUES(NEW.CheckingPeer, (SELECT Peer
								 FROM Checks
								 WHERE Checks.ID = P2P.Check),
			  	0);
	END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_p2p_update_points
AFTER INSERT ON P2P
FOR EACH ROW
EXECUTE FUNCTION trg_p2p_update_points();

CREATE OR REPLACE FUNCTION add_inverse_friend()
RETURNS TRIGGER AS
$$
BEGIN
   IF NOT EXISTS (SELECT Peer1, Peer2
      FROM Friends
      WHERE Peer1 = NEW.Peer2 AND Peer2 = NEW.Peer1)
   THEN INSERT INTO Friends (Peer1, Peer2)
    VALUES (NEW.Peer2, NEW.Peer1);
    RETURN NEW;
 ELSE
  RETURN NULL;
   END IF;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER add_inverse_friend_insert_trigger
AFTER INSERT ON Friends
FOR EACH ROW
EXECUTE FUNCTION add_inverse_friend();

CREATE OR REPLACE FUNCTION insert_new_state()
RETURNS TRIGGER AS $$
	DECLARE last_state VARCHAR(1);
	DECLARE last_time TIME WITHOUT TIME ZONE;
	DECLARE last_date DATE;
BEGIN
	 WITH last_record AS(
	 	 SELECT "State", "Time", "Date"
		 FROM TimeTracking
		 WHERE Peer = New.Peer
		 ORDER BY "Date" DESC, "Time" DESC
		 LIMIT 1
	 )
	 SELECT "State", "Time", "Date" INTO last_state, last_time, last_date
	 FROM last_record;
	 IF (NEW."Date" < last_date) OR (NEW."Date" = last_date AND NEW."Time" <= last_time) THEN
	  	RAISE EXCEPTION 'New time/date cannot be earlier than the last state';
	 END IF;

	 IF NEW."State" = last_state THEN
	  	RAISE EXCEPTION 'New state cannot be the same as the previous one';
	 END IF;

	 IF NEW."State" = '2' AND last_date != NEW."Date" THEN
	  	INSERT INTO TimeTracking (Peer, "Date", "Time", "State")
	  	VALUES (NEW.Peer, last_date, TIME '23:59:59', '2'),
			 (NEW.Peer, NEW."Date", TIME '00:00:00', '1');
	 END IF;

	 RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_timetracking
BEFORE INSERT ON TimeTracking
FOR EACH ROW
EXECUTE FUNCTION insert_new_state();

----------------import/export----------------
CREATE OR REPLACE PROCEDURE import_from_csv(
    IN p_table_name TEXT,
    IN p_file_path TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE 'COPY ' || p_table_name || ' FROM ''' || p_file_path || ''' WITH CSV HEADER;';
END;
$$;

CREATE OR REPLACE PROCEDURE export_to_csv(
    IN p_table_name TEXT,
    IN p_file_path TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE 'COPY ' || p_table_name || ' TO ''' || p_file_path || ''' WITH CSV HEADER;';
END;
$$;
