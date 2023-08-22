-------------------------ex01------------------------- 
CREATE OR REPLACE PROCEDURE DropTablesStartingWithTableName()
LANGUAGE plpgsql
AS $$
DECLARE
    table_name_to_drop TEXT; 
BEGIN
    FOR table_name_to_drop IN (SELECT table_name FROM information_schema.tables WHERE table_name LIKE 'tablename%')
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || table_name_to_drop || ' CASCADE;';
    END LOOP;
END;
$$;

-------------------------ex02------------------------- 
CREATE OR REPLACE PROCEDURE list_scalar_functions()
LANGUAGE plpgsql
AS $$
DECLARE
    function_name TEXT;
    parameter_list TEXT;
    return_type TEXT;
BEGIN
    FOR function_name IN (
        SELECT p.proname AS function_name
        FROM pg_proc AS p
        JOIN pg_namespace AS n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prorettype <> 'pg_catalog.cstring'::regtype 
          AND p.proargtypes[0] = 'pg_catalog.cstring'::regtype 
    )
    LOOP
        parameter_list := (
            SELECT string_agg(p.typname || ' ' || a.argname, ', ')
            FROM unnest(p.proargtypes) WITH ORDINALITY AS a(arg, ord)
            JOIN pg_type AS p ON a.arg = p.oid
            WHERE a.ord > 0
        );

        return_type := (
            SELECT typname
            FROM pg_type
            WHERE oid = (SELECT prorettype FROM pg_proc WHERE proname = function_name)
        );
    END LOOP;
	RAISE NOTICE 'Function: %(%); Return Type: %', function_name, parameter_list, return_type;
END;
$$;

-- CREATE OR REPLACE FUNCTION add_numbers(num1 INTEGER, num2 INTEGER)
-- RETURNS INTEGER AS
-- $$
-- BEGIN
--     RETURN num1 + num2;
-- END;
-- $$
-- LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION ScalarPower(num FLOAT, pow INT)
-- RETURNS FLOAT
-- AS $$
-- BEGIN
-- 	RETURN POWER(num, pow);
-- END;
-- $$
-- LANGUAGE plpgsql;

-------------------------ex03------------------------- 
CREATE OR REPLACE PROCEDURE destroy_all_dml_triggers(OUT destroyed_trigger_count INTEGER)
AS $$
DECLARE
    trigger_rec RECORD;
    trigger_row RECORD;
BEGIN
    destroyed_trigger_count := 0;
    FOR trigger_rec IN (
        SELECT event_object_table, trigger_name
        FROM information_schema.triggers
        WHERE trigger_schema = 'public'
    )
    LOOP
        trigger_row := trigger_rec;
        EXECUTE 'DROP TRIGGER IF EXISTS ' || trigger_row.trigger_name || ' ON ' || trigger_row.event_object_table;
        destroyed_trigger_count := destroyed_trigger_count + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- DO $$
-- DECLARE
-- 	total_triggers INTEGER;
-- BEGIN
-- 	CALL destroy_all_dml_triggers(total_triggers);
-- 	RAISE NOTICE 'Total triggers destroyed: %', total_triggers;
-- END;
-- $$;

-------------------------ex04-------------------------
CREATE OR REPLACE PROCEDURE search_objects_by_description(IN search_string TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    object_name TEXT;
    object_description TEXT;
BEGIN
    FOR object_name, object_description IN (
        SELECT proname, obj_description(oid, 'pg_proc')
        FROM pg_proc
        WHERE proname ILIKE '%' || search_string || '%'
    )
    LOOP
        RAISE NOTICE 'Object Name: %, Description: %', object_name, object_description;
    END LOOP;
END;
$$;

--CALL search_objects_by_description('add');
