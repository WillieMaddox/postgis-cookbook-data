CREATE OR REPLACE FUNCTION create_grid (geometry, float) RETURNS geometry AS $$
WITH middleline AS (
SELECT ST_MakeLine(ST_Translate($1, -10, 0), ST_Translate($1, 40.0, 0)) AS the_geom),
topline AS (
SELECT ST_MakeLine(ST_Translate($1, -10, 10.0), ST_Translate($1, 40.0, 10)) AS the_geom),
bottomline AS (
SELECT ST_MakeLine(ST_Translate($1, -10, -10.0), ST_Translate($1, 40.0, -10)) AS the_geom),
oneline AS (
SELECT ST_MakeLine(ST_Translate($1, -10, 10.0), ST_Translate($1, -10, -10)) AS the_geom),
twoline AS (
SELECT ST_MakeLine(ST_Translate($1, 0, 10.0), ST_Translate($1, 0, -10)) AS the_geom),
threeline AS (
SELECT ST_MakeLine(ST_Translate($1, 10, 10.0), ST_Translate($1, 10, -10)) AS the_geom),
fourline AS (
SELECT ST_MakeLine(ST_Translate($1, 20, 10.0), ST_Translate($1, 20, -10)) AS the_geom),
fiveline AS (
SELECT ST_MakeLine(ST_Translate($1, 30, 10.0), ST_Translate($1, 30, -10)) AS the_geom),
sixline AS (
SELECT ST_MakeLine(ST_Translate($1, 40, 10.0), ST_Translate($1, 40, -10)) AS the_geom),
combined AS (
SELECT ST_Union(the_geom) AS the_geom FROM
(
SELECT the_geom FROM middleline
UNION ALL
SELECT the_geom FROM topline
UNION ALL
SELECT the_geom FROM bottomline
UNION ALL
SELECT the_geom FROM oneline
UNION ALL
SELECT the_geom FROM twoline
UNION ALL
SELECT the_geom FROM threeline
UNION ALL
SELECT the_geom FROM fourline
UNION ALL
SELECT the_geom FROM fiveline
UNION ALL
SELECT the_geom FROM sixline
) AS alllines
)
SELECT polygonize_to_multi(ST_Rotate(the_geom, $2, $1)) AS the_geom FROM combined;
$$ LANGUAGE SQL;

