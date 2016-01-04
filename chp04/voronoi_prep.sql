CREATE OR REPLACE FUNCTION voronoi_prep (geometry, integer) RETURNS vor AS $$
WITH astext AS (SELECT ST_AsText(the_geom) AS pstring, gid
FROM (SELECT (ST_DumpPoints($1)).geom AS the_geom, $2 AS gid) AS point_dump),
astextcomma AS (SELECT replace(pstring, ' ', ',') AS pstring, gid FROM astext),
startingbracket AS (SELECT replace(pstring, 'POINT(', '[') AS pstring, gid FROM astextcomma),
endingbracket AS (SELECT replace(pstring, ')', ']') AS pstring, gid FROM startingbracket)
SELECT ROW(pstring, gid)::vor FROM endingbracket;
$$ LANGUAGE SQL;


