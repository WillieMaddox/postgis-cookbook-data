#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCH=chp04
DIR=/$USER/$SCH

cd $DIR/

cat << EOF | su - $USER -c "psql -d $DB"
DROP SCHEMA IF EXISTS $SCH CASCADE;
CREATE SCHEMA $SCH;
EOF

echo '### p128. Improving proximity filtering with KNN'

#SS=''
SS=_subset
CAP=cuy_address_points
CAPL=cuy_address_points$SS
CAPU=CUY_ADDRESS_POINTS$SS

if [[ ! -d $CAP ]]; then
  mkdir ./$CAP
fi
if [[ ! -f $CAP/$CAPU.shp ]]; then
  unzip $CAPL -d $CAP
fi

shp2pgsql -s 3734 -d -i -I -W LATIN1 -g the_geom $CAP/$CAPU $SCH.knn_addresses | psql -U $USER -d $DB

cat << EOF | su - $USER -c "psql -d $DB"
SELECT COUNT(*) FROM $SCH.knn_addresses;

SELECT ST_Distance(searchpoint.the_geom, addr.the_geom) AS dist, * FROM $SCH.knn_addresses addr, (SELECT ST_Transform(ST_SetSRID(ST_MakePoint(-81.738624, 41.396679), 4326), 3734) AS the_geom) searchpoint ORDER BY ST_Distance(searchpoint.the_geom, addr.the_geom) LIMIT 10;

SELECT ST_Distance(searchpoint.the_geom, addr.the_geom) AS dist, * FROM $SCH.knn_addresses addr, (SELECT ST_Transform(ST_SetSRID(ST_MakePoint(-81.738624, 41.396679), 4326), 3734) AS the_geom) searchpoint WHERE ST_DWithin(searchpoint.the_geom, addr.the_geom, 200) ORDER BY ST_Distance(searchpoint.the_geom, addr.the_geom) LIMIT 10;

SELECT ST_Distance(searchpoint.the_geom, addr.the_geom) AS dist, * FROM $SCH.knn_addresses addr, (SELECT ST_Transform(ST_SetSRID(ST_MakePoint(-81.738624, 41.396679), 4326), 3734) AS the_geom) searchpoint ORDER BY addr.the_geom <-> searchpoint.the_geom LIMIT 10;
EOF

echo '### p132. Improving proximity filtering with KNN – advanced'

if [[ ! -d cuy_streets ]]; then
  mkdir ./cuy_streets
  unzip cuy_streets -d cuy_streets
fi

shp2pgsql -s 3734 -d -i -I -W LATIN1 -g the_geom cuy_streets/CUY_STREETS $SCH.knn_streets | psql -U $USER -d $DB

cat << EOF | su - $USER -c "psql -d $DB"
\i $DIR/angle_to_street.sql
CREATE TABLE $SCH.knn_address_points_rot AS SELECT addr.*, angle_to_street(addr.the_geom) FROM $SCH.knn_addresses addr;
EOF

echo '### p137. Rotating geometries'

cat << EOF | su - $USER -c "psql -d $DB"
CREATE TABLE $SCH.tsr_building AS SELECT ST_Rotate(ST_Envelope(ST_Buffer(the_geom, 20)), radians(90 - angle_to_street(addr.the_geom)), addr.the_geom) AS the_geom FROM $SCH.knn_addresses addr LIMIT 500;
EOF

echo '### p140. Improving ST_Polygonize'

cat << EOF | su - $USER -c "psql -d $DB"
\i $DIR/polygonize_to_multi.sql
EOF

echo '### p142. Translating, scaling, and rotating geometries – advanced'

cat << EOF | su - $USER -c "psql -d $DB"
\i $DIR/create_grid.sql
CREATE TABLE $SCH.tsr_grid AS
SELECT create_grid(ST_SetSRID(ST_MakePoint(0,0), 3734), 0) AS the_geom
UNION ALL
SELECT create_grid(ST_SetSRID(ST_MakePoint(0,100), 3734), 0.274352 * pi()) AS the_geom
UNION ALL
SELECT create_grid(ST_SetSRID(ST_MakePoint(100,0), 3734), 0.824378 * pi()) AS the_geom
UNION ALL
SELECT create_grid(ST_SetSRID(ST_MakePoint(0,-100), 3734), 0.43587 * pi()) AS the_geom
UNION ALL
SELECT create_grid(ST_SetSRID(ST_MakePoint(-100,0), 3734), 1 * pi()) AS the_geom
;
EOF

echo '### p148. Detailed building footprints from LiDAR'

if [[ ! -d lidar_buildings ]]; then
  mkdir ./lidar_buildings
  unzip lidar_buildings -d lidar_buildings
fi

shp2pgsql -s 3734 -d -i -I -W LATIN1 -g the_geom lidar_buildings/lidar_buildings $SCH.lidar_buildings | psql -U $USER -d $DB

cat << EOF | su - $USER -c "psql -d $DB"
CREATE TABLE $SCH.lidar_buildings_buffer AS WITH lidar_query AS
(SELECT ST_ExteriorRing(ST_SimplifyPreserveTopology((ST_Dump(ST_Union(ST_Buffer(the_geom, 5)))).geom, 10)) AS the_geom FROM $SCH.lidar_buildings)
SELECT polygonize_to_multi(the_geom) AS the_geom from lidar_query;
EOF

echo '### p152. Using external scripts to embed new functionality in order to calculate a Voronoi diagram'

cat << EOF | su - $USER -c "psql -d $DB"
\i $DIR/voronoi.sql
DROP TABLE IF EXISTS $SCH.voronoi_test_points;
CREATE TABLE $SCH.voronoi_test_points(x numeric, y numeric) WITH (OIDS=FALSE);
ALTER TABLE $SCH.voronoi_test_points ADD COLUMN gid serial;
ALTER TABLE $SCH.voronoi_test_points ADD PRIMARY KEY (gid);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 5, random() * 7);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 2, random() * 8);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 10, random() * 4);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 1, random() * 15);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 4, random() * 9);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 8, random() * 3);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 5, random() * 3);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 20, random() * 0.1);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (random() * 5, random() * 7);
SELECT AddGeometryColumn ('$SCH', 'voronoi_test_points', 'the_geom', 3734, 'POINT', 2);
UPDATE $SCH.voronoi_test_points SET the_geom = ST_SetSRID(ST_MakePoint(x, y), 3734) WHERE the_geom IS NULL;

-- CREATE TABLE $SCH.voronoi_test AS SELECT * FROM voronoi('$SCH.voronoi_test_points', 'the_geom') AS (id integer, the_geom geometry);
-- DROP TABLE IF EXISTS $SCH.voronoi_test_points_u CASCADE;

CREATE TABLE $SCH.voronoi_test_points_u AS WITH bboxpoints AS (SELECT (ST_DumpPoints(ST_SetSRID(ST_Extent(the_geom), 3734))).geom AS the_geom FROM $SCH.voronoi_test_points UNION ALL SELECT the_geom FROM $SCH.voronoi_test_points) SELECT (ST_Dump(ST_Union(the_geom))).geom AS the_geom FROM bboxpoints;

CREATE TABLE $SCH.voronoi_test AS SELECT * FROM voronoi('$SCH.voronoi_test_points_u', 'the_geom') AS (id integer, the_geom geometry);

CREATE INDEX $SCH_voronoi_test_points_u_the_geom_idx ON $SCH.voronoi_test_points_u USING gist(the_geom);
CREATE INDEX $SCH_voronoi_test_the_geom_idx ON $SCH.voronoi_test USING gist(the_geom);

CREATE TABLE $SCH.voronoi_test_points_u_clean AS WITH voronoi AS (SELECT COUNT(*), v.the_geom FROM $SCH.voronoi_test v, $SCH.voronoi_test_points_u p WHERE ST_Intersects(v.the_geom, p.the_geom) GROUP BY v.the_geom) SELECT the_geom FROM voronoi WHERE count = 1;
EOF

echo '### p156. Using external scripts to embed other libraries in order to calculate a Voronoi diagram – advanced'

cat << EOF | su - $USER -c "psql -d $DB"
\i $DIR/voronoi_fast.sql
\i $DIR/voronoi_prep.sql

DROP TABLE IF EXISTS $SCH.voronoi_test_points;

CREATE TABLE $SCH.voronoi_test_points(x numeric, y numeric) WITH (OIDS=FALSE);
ALTER TABLE $SCH.voronoi_test_points ADD COLUMN gid serial;
ALTER TABLE $SCH.voronoi_test_points ADD PRIMARY KEY (gid);
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (5 * random(), 7 * random());
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (2 * random(), 8 * random());
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (10 * random(), 4 * random());
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (1 * random(), 15 * random());
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (4 * random(), 9 * random());
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (8 * random(), 3 * random());
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (5 * random(), 3 * random());
INSERT INTO $SCH.voronoi_test_points (x, y) VALUES (20 * random(), 0.1 * random());
SELECT AddGeometryColumn ('$SCH', 'voronoi_test_points', 'the_geom', 3734, 'POINT', 2);
UPDATE $SCH.voronoi_test_points SET the_geom = ST_SetSRID(ST_MakePoint(x, y), 3734) WHERE the_geom IS NULL;
CREATE TYPE vor AS (geomstring text, gid integer);

DROP TABLE IF EXISTS $SCH.voronoi_test;

CREATE TABLE $SCH.voronoi_test AS (
WITH stringprep AS (
SELECT voronoi_prep(the_geom, gid) FROM $SCH.voronoi_test_points),
aggstring AS (
SELECT '[' || STRING_AGG((voronoi_prep).geomstring, ',' ORDER BY
(voronoi_prep).gid) || ']' AS inputtext
FROM stringprep),
voronoi_string AS (
SELECT voronoi_fast(inputtext) AS vstring FROM aggstring),
vpoints AS (
SELECT split_part(vstring, ', 999999999,', 1) || ']' AS points
FROM voronoi_string), vids AS (
SELECT trim(trailing ']' FROM split_part(vstring, ', 999999999,', 2)) || ']' AS ids
FROM voronoi_string), arpt(pts) AS (
SELECT replace(replace((SELECT points FROM vpoints), ']' ,'}'), '[', '{')::float8[][]),
reg AS (SELECT ROW_NUMBER() OVER() As gid, ('{' || region[1] || '}')::integer[]
AS regindex
FROM regexp_matches((SELECT ids FROM vids), '\[([0-9,\s]+)\]', 'g') AS region),
regptloc AS (SELECT gid, ROW_NUMBER() OVER(PARTITION BY gid) AS ptloc,
unnest(regindex) As ptindex FROM reg),
vregions AS (SELECT ST_Collect(ST_MakePoint(pts[ptindex + 1][1], pts[ptindex + 1][2]) ORDER BY ptloc ) AS vregions
FROM regptloc CROSS JOIN arpt GROUP BY gid)
SELECT ST_ConvexHull(vregions) AS the_geom FROM vregions);
EOF
