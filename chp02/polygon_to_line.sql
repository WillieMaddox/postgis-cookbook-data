CREATE OR REPLACE FUNCTION polygon_to_line(geometry) RETURNS geometry AS $BODY$
SELECT ST_MakeLine(geom) FROM (SELECT (ST_DumpPoints(ST_ExteriorRing((ST_Dump($1)).geom))).geom) AS linpoints
$BODY$ LANGUAGE sql VOLATILE;
