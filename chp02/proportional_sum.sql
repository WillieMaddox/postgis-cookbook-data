CREATE OR REPLACE FUNCTION proportional_sum(geometry, geometry, numeric) RETURNS numeric AS $BODY$
SELECT $3 * areacalc FROM (SELECT (ST_Area(ST_Intersection($1, $2))/ST_Area($2))::numeric AS areacalc) AS areac;
$BODY$ LANGUAGE sql VOLATILE;

