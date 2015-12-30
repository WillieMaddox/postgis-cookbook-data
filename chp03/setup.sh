#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCH=chp03
DIR=/$USER/$SCH

cd $DIR/

cat << EOF | su - $USER -c "psql -d $DB"
DROP SCHEMA IF EXISTS $SCH CASCADE;
-- DROP SCHEMA IF EXISTS hu_topo CASCADE;
SELECT DropTopology('hu_topo');
CREATE SCHEMA $SCH;
EOF

echo '### 1. Working with GPS data'
cat << EOF | su - $USER -c "psql -d $DB"
CREATE TABLE $SCH.rk_track_points
(
fid serial NOT NULL, the_geom geometry(Point,4326),
ele double precision, "time" timestamp with time zone,
CONSTRAINT activities_pk PRIMARY KEY (fid)
);
EOF

if [[ ! -d runkeeper_gpx ]]; then
  mkdir ./runkeeper_gpx
  unzip runkeeper-gpx -d runkeeper_gpx
fi

for f in `find runkeeper_gpx -name \*.gpx -printf "%f\n"`
do
    echo "Importing gpx file $f to chp03.rk_track_points PostGIS table..." #, ${f%.*}"
    ogr2ogr -append -update  -f PostgreSQL PG:"dbname=$DB user=$USER password=$PASS" runkeeper_gpx/$f -nln chp03.rk_track_points -sql "SELECT ele, time FROM track_points"
done

cat << EOF | su - $USER -c "psql -d $DB"
SELECT ST_MakeLine(the_geom) AS the_geom,
run_date::date, MIN(run_time) as start_time,
MAX(run_time) as end_time INTO $SCH.tracks
FROM (SELECT the_geom, "time"::date as run_date,
"time" as run_time FROM $SCH.rk_track_points
ORDER BY run_time) AS foo GROUP BY run_date;

CREATE INDEX rk_track_points_geom_idx ON $SCH.rk_track_points USING gist(the_geom);
CREATE INDEX tracks_geom_idx ON $SCH.tracks USING gist(the_geom);

SELECT EXTRACT(year FROM run_date) AS run_year,
EXTRACT(MONTH FROM run_date) as run_month,
SUM(ST_Length(geography(the_geom)))/1000 AS distance
FROM $SCH.tracks GROUP BY run_year, run_month;

SELECT c.name, SUM(ST_Length(geography(t.the_geom)))/1000 AS run_distance
FROM $SCH.tracks AS t JOIN chp01.countries AS c ON ST_Intersects(t.the_geom, c.the_geom)
GROUP BY c.name ORDER BY run_distance DESC;
EOF

echo '### 2. Fixing invalid geometries'

if [[ ! -d TM_WORLD_BORDERS-0.3 ]]; then
  mkdir ./TM_WORLD_BORDERS-0.3
  unzip TM_WORLD_BORDERS-0.3 -d TM_WORLD_BORDERS-0.3
fi

shp2pgsql -s 4326 -g the_geom -W LATIN1 -I TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp $SCH.countries > countries.sql
psql -U $USER -d $DB -f countries.sql

cat << EOF | su - $USER -c "psql -d $DB"
SELECT gid, name, ST_IsValidReason(the_geom) FROM $SCH.countries WHERE ST_IsValid(the_geom)=false;

SELECT * INTO $SCH.invalid_geometries
FROM (SELECT 'broken'::varchar(10) as status,
ST_GeometryN(the_geom, generate_series(1, ST_NRings(the_geom)))::geometry(Polygon,4326) as the_geom
FROM $SCH.countries WHERE name = 'Russia') AS foo
WHERE ST_Intersects(the_geom, ST_SetSRID(ST_Point(143.661926,49.31221), 4326));

INSERT INTO $SCH.invalid_geometries VALUES ('repaired', (SELECT ST_MakeValid(the_geom) FROM $SCH.invalid_geometries));

SELECT status, ST_NRings(the_geom) FROM $SCH.invalid_geometries;

UPDATE $SCH.countries SET the_geom = ST_MakeValid(the_geom) WHERE ST_IsValid(the_geom) = false;
EOF

echo '### 3. GIS analysis with spatial joins'

if [[ ! -f 2012_Earthquakes_ALL.kml ]]; then
  cp 2012_Earthquakes_ALL.kmz 2012_Earthquakes_ALL.zip
  unzip 2012_Earthquakes_ALL.zip
  rm 2012_Earthquakes_ALL.zip
fi

for ((i = 1; i < 9 ; i++)) ; do
    echo "Importing earthquakes with magnitude $i to chp03.earthquakes PostGIS table..."
    ogr2ogr -append -f PostgreSQL -nln chp03.earthquakes PG:"dbname=$DB user=$USER password=$PASS" 2012_Earthquakes_ALL.kml -sql "SELECT name, description, CAST($i AS integer) AS magnitude FROM 'Magnitude $i'"
done

cat << EOF | su - $USER -c "psql -d $DB"
ALTER TABLE $SCH.earthquakes RENAME wkb_geometry TO the_geom;
EOF

if [[ ! -d citiesx020 ]]; then
  mkdir ./citiesx020
  tar -xzf citiesx020_nt00007.tar.gz -C citiesx020
fi

if [[ ! -d statesp020 ]]; then
  mkdir ./statesp020
  tar -xzf statesp020_nt00032.tar.gz -C statesp020
fi

ogr2ogr -f PostgreSQL -s_srs EPSG:4269 -t_srs EPSG:4326 -lco GEOMETRY_NAME=the_geom -nln $SCH.cities PG:"dbname=$DB user=$USER password=$PASS" citiesx020/citiesx020.shp
ogr2ogr -f PostgreSQL -s_srs EPSG:4269 -t_srs EPSG:4326 -lco GEOMETRY_NAME=the_geom -nln $SCH.states -nlt MULTIPOLYGON PG:"dbname=$DB user=$USER password=$PASS" statesp020/statesp020.shp

cat << EOF | su - $USER -c "psql -d $DB"
SELECT s.state, COUNT(*) AS hq_count FROM $SCH.states AS s JOIN $SCH.earthquakes AS e ON ST_Intersects(s.the_geom, e.the_geom) GROUP BY s.state ORDER BY hq_count DESC;

SELECT c.name, e.magnitude, count(*) as hq_count FROM $SCH.cities AS c JOIN $SCH.earthquakes AS e ON ST_DWithin(geography(c.the_geom), geography(e.the_geom), 200000) WHERE c.pop_2000 > 1000000 GROUP BY c.name, e.magnitude ORDER BY c.name, e.magnitude, hq_count;

SELECT c.name, e.magnitude, ST_Distance(geography(c.the_geom), geography(e.the_geom)) AS distance FROM $SCH.cities AS c JOIN $SCH.earthquakes AS e ON ST_DWithin(geography(c.the_geom), geography(e.the_geom), 200000) WHERE c.pop_2000 > 1000000 ORDER BY distance;

SELECT s.state, COUNT(*) AS city_count, SUM(pop_2000) AS pop_2000 FROM $SCH.states AS s JOIN $SCH.cities AS c ON ST_Intersects(s.the_geom, c.the_geom) WHERE c.pop_2000 > 0 GROUP BY s.state ORDER BY pop_2000 DESC;

ALTER TABLE $SCH.earthquakes ADD COLUMN state_fips character varying(2);

UPDATE $SCH.earthquakes AS e SET state_fips = s.state_fips FROM $SCH.states AS s WHERE ST_Intersects(s.the_geom, e.the_geom);
EOF

echo '### 4. Simplifying geometries'

cat << EOF | su - $USER -c "psql -d $DB"
SET search_path TO $SCH, public;

CREATE TABLE states_simplify_topology AS SELECT ST_SimplifyPreserveTopology(ST_Transform(the_geom, 2163), 500) FROM states;

SET search_path TO $SCH, public;

-- first project the spatial table to a planar system
CREATE TABLE states_2163 AS SELECT ST_Transform(the_geom, 2163)::geometry(MultiPolygon, 2163) AS the_geom, state FROM states;

-- now decompose the geometries from multipolygons to polygons (2895) using the ST_Dump function
CREATE TABLE polygons AS SELECT (ST_Dump(the_geom)).geom AS the_geom FROM states_2163;

-- now decompose from polygons (2895) to rings (3150) using the ST_DumpRings function
CREATE TABLE rings AS SELECT (ST_DumpRings(the_geom)).geom AS the_geom FROM polygons;

-- now decompose from rings (3150) to linestrings (3150) using the ST_Boundary function
CREATE TABLE ringlines AS SELECT(ST_boundary(the_geom)) AS the_geom FROM rings;

-- now merge all linestrings (3150) in a single merged linestring (this way duplicate linestrings at polygon borders disappear)
CREATE TABLE mergedringlines AS SELECT ST_Union(the_geom) AS the_geom FROM ringlines;

-- finally simplify the linestring with a tolerance of 150 meters
CREATE TABLE simplified_ringlines AS SELECT ST_SimplifyPreserveTopology(the_geom, 150) AS the_geom FROM mergedringlines;

-- now compose a polygons collection from the linestring using the ST_Polygonize function
CREATE TABLE simplified_polycollection AS SELECT ST_Polygonize(the_geom) AS the_geom FROM simplified_ringlines;

-- here you generate polygons (2895) from the polygons collection using ST_Dumps
CREATE TABLE simplified_polygons AS SELECT ST_Transform((ST_Dump(the_geom)).geom, 4326)::geometry(Polygon,4326) AS the_geom FROM simplified_polycollection;

-- time to create an index, to make next operations faster
CREATE INDEX simplified_polygons_gist ON simplified_polygons USING GIST (the_geom);

-- now copy the state name attribute from old layer with a spatial join using the ST_Intersects and ST_PointOnSurface function
CREATE TABLE simplified_polygonsattr AS SELECT new.the_geom, old.state FROM simplified_polygons new, states old WHERE ST_Intersects(new.the_geom, old.the_geom) AND ST_Intersects(ST_PointOnSurface(new.the_geom), old.the_geom);

-- now make the union of all polygons with a common name
CREATE TABLE states_simplified AS SELECT ST_Union(the_geom) AS the_geom, state FROM simplified_polygonsattr GROUP BY state;
EOF

echo '### 5. Measuring distances'

ogr2ogr -f PostgreSQL -s_srs EPSG:4269 -t_srs EPSG:4326 -lco GEOMETRY_NAME=the_geom -nln $SCH.cities PG:"dbname=$DB user=$USER password=$PASS" citiesx020/citiesx020.shp

cat << EOF | su - $USER -c "psql -d $DB"
SELECT c1.name, c2.name, ST_Distance(ST_Transform(c1.the_geom, 900913), ST_Transform(c2.the_geom, 900913))/1000 AS distance_900913 FROM $SCH.cities AS c1 CROSS JOIN $SCH.cities AS c2 WHERE c1.pop_2000 > 1000000 AND c2.pop_2000 > 1000000 AND c1.name < c2.name ORDER BY distance_900913 DESC;

WITH cities AS (SELECT name, the_geom FROM $SCH.cities WHERE pop_2000 > 1000000 ) SELECT c1.name, c2.name, ST_Distance(ST_Transform(c1.the_geom, 900913), ST_Transform(c2.the_geom, 900913))/1000 AS distance_900913 FROM cities c1 CROSS JOIN cities c2 where c1.name < c2.name ORDER BY distance_900913 DESC;

WITH cities AS (SELECT name, the_geom FROM $SCH.cities WHERE pop_2000 > 1000000 )
SELECT c1.name, c2.name, ST_Distance(ST_Transform(c1.the_geom, 900913), ST_Transform(c2.the_geom, 900913))/1000 AS d_900913, ST_Distance_Sphere(c1.the_geom, c2.the_geom)/1000 AS d_4326_sphere, ST_Distance_Spheroid(c1.the_geom, c2.the_geom, 'SPHEROID["GRS_1980",6378137,298.257222101]')/1000 AS d_4326_spheroid, ST_Distance(geography(c1.the_geom), geography(c2.the_geom))/1000 AS d_4326_geography FROM cities c1 CROSS JOIN cities c2 where c1.name < c2.name ORDER BY d_900913 DESC;
EOF


echo '### 6. Merging polygons using a common attribute'

if [[ ! -d co2000p020 ]]; then
  mkdir ./co2000p020
  tar -xzf co2000p020_nt00157.tar.gz -C co2000p020
fi

ogr2ogr -f PostgreSQL -s_srs EPSG:4269 -t_srs EPSG:4326 -lco GEOMETRY_NAME=the_geom -nln $SCH.counties -nlt MULTIPOLYGON PG:"dbname=$DB user=$USER password=$PASS" co2000p020/co2000p020.shp

cat << EOF | su - $USER -c "psql -d $DB"
-- SELECT county, fips, state_fips FROM $SCH.counties ORDER BY county;
CREATE TABLE $SCH.states_from_counties AS SELECT ST_Multi(ST_Union(the_geom)) as the_geom, state_fips FROM $SCH.counties GROUP BY state_fips;
EOF

echo '### 7. Computing intersections'

if [[ ! -d 10m-rivers-lake-centerlines ]]; then
  mkdir ./10m-rivers-lake-centerlines
  unzip 10m-rivers-lake-centerlines -d 10m-rivers-lake-centerlines
fi

shp2pgsql -I -W LATIN1 -s 4326 -g the_geom 10m-rivers-lake-centerlines/ne_10m_rivers_lake_centerlines.shp $SCH.rivers > rivers.sql
psql -U $USER -d $DB -f rivers.sql

cat << EOF | su - $USER -c "psql -d $DB"
-- SELECT r1.gid AS gid1, r2.gid AS gid2, ST_AsText(ST_Intersection(r1.the_geom, r2.the_geom)) AS the_geom FROM $SCH.rivers r1 JOIN $SCH.rivers r2 ON ST_Intersects(r1.the_geom, r2.the_geom) WHERE r1.gid != r2.gid;

SELECT COUNT(*), ST_GeometryType(ST_Intersection(r1.the_geom, r2.the_geom)) AS geometry_type FROM $SCH.rivers r1 JOIN $SCH.rivers r2 ON ST_Intersects(r1.the_geom, r2.the_geom) WHERE r1.gid != r2.gid GROUP BY geometry_type;

CREATE TABLE $SCH.intersections_simple AS SELECT r1.gid AS gid1, r2.gid AS gid2, ST_Multi(ST_Intersection(r1.the_geom, r2.the_geom))::geometry(MultiPoint, 4326) AS the_geom FROM $SCH.rivers r1 JOIN $SCH.rivers r2 ON ST_Intersects(r1.the_geom, r2.the_geom) WHERE r1.gid != r2.gid AND ST_GeometryType(ST_Intersection(r1.the_geom, r2.the_geom)) != 'ST_GeometryCollection';

CREATE TABLE $SCH.intersections_all AS SELECT gid1, gid2, the_geom::geometry(MultiPoint, 4326) FROM ( SELECT r1.gid AS gid1, r2.gid AS gid2, CASE WHEN ST_GeometryType(ST_Intersection(r1.the_geom, r2.the_geom)) != 'ST_GeometryCollection' THEN ST_Multi(ST_Intersection(r1.the_geom, r2.the_geom)) ELSE ST_CollectionExtract(ST_Intersection(r1.the_geom, r2.the_geom), 1) END AS the_geom FROM $SCH.rivers r1 JOIN $SCH.rivers r2 ON ST_Intersects(r1.the_geom, r2.the_geom) WHERE r1.gid != r2.gid) AS only_multipoints_geometries;

SELECT SUM(ST_NPoints(the_geom)) FROM $SCH.intersections_simple; --2268 points per 1444 records
SELECT SUM(ST_NPoints(the_geom)) FROM $SCH.intersections_all; --2282 points per 1448 records
EOF

echo '### 8. Clipping geometries to deploy data'

cat << EOF | su - $USER -c "psql -d $DB"
CREATE VIEW $SCH.rivers_clipped_by_country AS SELECT r.name, c.iso2, ST_Intersection(r.the_geom, c.the_geom)::geometry(Geometry,4326) AS the_geom FROM $SCH.countries AS c JOIN $SCH.rivers AS r ON ST_Intersects(r.the_geom, c.the_geom);
EOF

if [[ -d rivers ]]; then
  rm -rf rivers
fi

if [[ ! -d rivers ]]; then
  mkdir rivers
fi

for f in `ogrinfo PG:"dbname=$DB user=$USER password=$PASS" -sql "SELECT DISTINCT(iso2) FROM chp03.countries ORDER BY iso2" | grep iso2 | awk '{print $4}'` 
do 
  echo "Exporting river shapefile for $f country..." 
  ogr2ogr rivers/rivers_$f.shp PG:"dbname=$DB user=$USER password=$PASS" -sql "SELECT * FROM chp03.rivers_clipped_by_country WHERE iso2 = '$f'" 
done

echo '### 9. Simplifying geometries with PostGIS topology'

if [[ ! -d HUN_adm ]]; then
  mkdir ./HUN_adm
  unzip HUN_adm -d HUN_adm
fi

ogr2ogr -f PostgreSQL -t_srs EPSG:3857 -nlt MULTIPOLYGON -lco GEOMETRY_NAME=the_geom -nln $SCH.hungary PG:"dbname=$DB user=$USER password=$PASS" HUN_adm/HUN_adm1.shp

cat << EOF | su - $USER -c "psql -d $DB"
SELECT COUNT(*) FROM $SCH.hungary;
SET search_path TO $SCH, topology, public;
SELECT CreateTopology('hu_topo', 3857);
SELECT * FROM topology.topology;
\dtv hu_topo.*
SELECT topologysummary('hu_topo');

CREATE TABLE $SCH.hu_topo_polygons(gid serial primary key, name_1 varchar(75));
\! echo '-----. BEGIN AddTopoGeometryColumn'
SELECT AddTopoGeometryColumn('hu_topo', '$SCH', 'hu_topo_polygons', 'the_geom_topo', 'MULTIPOLYGON') AS layer_id;
\! echo '-----. BEGIN INSERT INTO'
INSERT INTO $SCH.hu_topo_polygons(name_1, the_geom_topo) SELECT name_1, toTopoGeom(the_geom, 'hu_topo', 1) FROM $SCH.hungary;
SELECT topologysummary('hu_topo');

SELECT row_number() OVER (ORDER BY ST_Area(mbr) DESC) as rownum, ST_Area(mbr)/100000 AS area FROM hu_topo.face ORDER BY area DESC;
SELECT DropTopology('hu_topo');
DROP TABLE $SCH.hu_topo_polygons;
SELECT CreateTopology('hu_topo', 3857, 1);

CREATE TABLE $SCH.hu_topo_polygons(gid serial primary key, name_1 varchar(75));
SELECT AddTopoGeometryColumn('hu_topo', '$SCH', 'hu_topo_polygons', 'the_geom_topo', 'MULTIPOLYGON') AS layer_id;
INSERT INTO $SCH.hu_topo_polygons(name_1, the_geom_topo) SELECT name_1, toTopoGeom(the_geom, 'hu_topo', 1) FROM $SCH.hungary;
SELECT topologysummary('hu_topo');

SELECT ST_ChangeEdgeGeom('hu_topo', edge_id, ST_SimplifyPreserveTopology(geom, 500)) FROM hu_topo.edge;
UPDATE $SCH.hungary hu SET the_geom = hut.the_geom_topo FROM $SCH.hu_topo_polygons hut WHERE hu.name_1 = hut.name_1;
EOF



