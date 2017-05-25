#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCH=chp02
DIR=/vagrant/$SCH

cd $DIR/

cat << EOF | su - vagrant -c "psql -d $DB"
DROP SCHEMA IF EXISTS $SCH CASCADE;
CREATE SCHEMA $SCH;
EOF

echo '### 1. Using geospatial views'

# -- Drop the table in case it exists
# -- This table will contain numeric x, y, and z values
# -- We will be disciplined and ensure we have a primary key
# -- Ensure we don't try to duplicate the view
# -- Retain original attributes, but also create a point attribute from x and y


cat << EOF | su - vagrant -c "psql -d $DB"
DROP TABLE IF EXISTS $SCH.xwhyzed CASCADE;
CREATE TABLE $SCH.xwhyzed (x numeric, y numeric, z numeric) WITH (OIDS=FALSE);
ALTER TABLE $SCH.xwhyzed OWNER TO $USER;
ALTER TABLE $SCH.xwhyzed ADD COLUMN gid serial;
ALTER TABLE $SCH.xwhyzed ADD PRIMARY KEY (gid);
INSERT INTO $SCH.xwhyzed (x, y, z) VALUES (random()*5, random()*7, random()*106);
INSERT INTO $SCH.xwhyzed (x, y, z) VALUES (random()*5, random()*7, random()*106);
INSERT INTO $SCH.xwhyzed (x, y, z) VALUES (random()*5, random()*7, random()*106);
INSERT INTO $SCH.xwhyzed (x, y, z) VALUES (random()*5, random()*7, random()*106);
DROP VIEW IF EXISTS $SCH.xbecausezed;
CREATE VIEW $SCH.xbecausezed AS SELECT x, y, z, ST_MakePoint(x, y) FROM $SCH.xwhyzed;
DROP VIEW IF EXISTS $SCH.xbecausezed;
CREATE VIEW $SCH.xbecausezed AS SELECT x, y, z, ST_SetSRID(ST_MakePoint(x, y), 3734) FROM $SCH.xwhyzed;
EOF

echo '### 2. Using triggers to populate a geometry column'

cat << EOF | su - vagrant -c "psql -d $DB"
DROP TABLE IF EXISTS $SCH.xwhyzed1 CASCADE;
CREATE TABLE $SCH.xwhyzed1(x numeric, y numeric, z numeric) WITH (OIDS=FALSE);
ALTER TABLE $SCH.xwhyzed1 OWNER TO $USER;
ALTER TABLE $SCH.xwhyzed1 ADD COLUMN gid serial;
ALTER TABLE $SCH.xwhyzed1 ADD PRIMARY KEY (gid);
INSERT INTO $SCH.xwhyzed1 (x, y, z) VALUES (random()*5, random()*7, random()*106);
INSERT INTO $SCH.xwhyzed1 (x, y, z) VALUES (random()*5, random()*7, random()*106);
INSERT INTO $SCH.xwhyzed1 (x, y, z) VALUES (random()*5, random()*7, random()*106);
INSERT INTO $SCH.xwhyzed1 (x, y, z) VALUES (random()*5, random()*7, random()*106);

SELECT AddGeometryColumn ("$SCH", 'xwhyzed1', 'geom', 3734, 'POINT', 2);

UPDATE $SCH.xwhyzed1 SET geom = ST_SetSRID(ST_MakePoint(x, y), 3734);

\ir $DIR/popgeom1.sql
-- CREATE TRIGGER popgeom_insert AFTER INSERT ON $SCH.xwhyzed1 FOR EACH STATEMENT EXECUTE PROCEDURE xyz_pop_geom();
CREATE TRIGGER popgeom_insert AFTER INSERT ON $SCH.xwhyzed1 FOR EACH ROW EXECUTE PROCEDURE xyz_pop_geom();
CREATE TRIGGER popgeom_update AFTER UPDATE ON $SCH.xwhyzed1 FOR EACH ROW WHEN (OLD.X IS DISTINCT FROM NEW.X AND OLD.Y IS DISTINCT FROM NEW.Y) EXECUTE PROCEDURE xyz_pop_geom();

INSERT INTO $SCH.xwhyzed1 (x, y, z) VALUES (random()*5, random()*7, random()*106);

EOF

echo '### 3. Structuring spatial data with table inheritance'

cat << EOF | su - vagrant -c "psql -d $DB"
CREATE TABLE $SCH.hydrology (gid SERIAL PRIMARY KEY, "name" text, hyd_type text, geom_type text, the_geom geometry);
CREATE TABLE $SCH.hydrology_centerlines ("length" numeric) INHERITS ($SCH.hydrology);
CREATE TABLE $SCH.hydrology_polygon (area numeric, perimeter numeric) INHERITS ($SCH.hydrology);
CREATE TABLE $SCH.hydrology_linestring (sinuosity numeric) INHERITS ($SCH.hydrology_centerlines);
EOF

if [[ ! -d hydrology ]]; then
  mkdir ./hydrology
  unzip hydrology -d hydrology
fi

#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom hydrology/cuyahoga_hydro_polygon $SCH.hydrology_polygon | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom hydrology/cuyahoga_hydro_polyline $SCH.hydrology_linestring | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom hydrology/cuyahoga_river_centerlines $SCH.hydrology_centerlines | psql -U $USER -d $DB

echo '### 4. Extending inheritance – table partitioning'

cat << EOF | su - vagrant -c "psql -d $DB"
-- CREATE TABLE $SCH.contour_2_cm_only AS SELECT contour.elevation, contour.gid, contour.div_10, contour.div_20, contour.div_50, contour.div_100, cc.id, ST_Intersection(contour.the_geom, cc.the_geom) AS the_geom FROM $SCH.cuy_contours_2 AS contour, $SCH.contour_clip AS cc WHERE ST_Within(contour.the_geom, cc.the_geom) OR ST_Crosses(contour.the_geom, cc.the_geom);
CREATE TABLE $SCH.contours(gid serial NOT NULL, elevation integer, __gid double precision, the_geom geometry(MultiLineStringZM, 3734), CONSTRAINT contours_pkey PRIMARY KEY (gid)) WITH (OIDS=FALSE);
CREATE TABLE $SCH.contour_N2260630(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2260000 630000, 2260000 635000, 2265000 635000, 2265000 630000, 2260000 630000))', 3734)))) INHERITS($SCH.contours);
CREATE TABLE $SCH.contour_N2260635(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2260000 635000, 2260000 640000, 2265000 640000, 2265000 635000, 2260000 635000))', 3734)))) INHERITS($SCH.contours);
CREATE TABLE $SCH.contour_N2260640(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2260000 640000, 2260000 645000, 2265000 645000, 2265000 640000, 2260000 640000))', 3734)))) INHERITS($SCH.contours);
CREATE TABLE $SCH.contour_N2265630(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2265000 630000, 2265000 635000, 2270000 635000, 2270000 630000, 2265000 630000))', 3734)))) INHERITS($SCH.contours);
CREATE TABLE $SCH.contour_N2265635(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2265000 635000, 2265000 640000, 2270000 640000, 2270000 635000, 2265000 635000))', 3734)))) INHERITS($SCH.contours);
CREATE TABLE $SCH.contour_N2265640(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2265000 640000, 2265000 645000, 2270000 645000, 2270000 640000, 2265000 640000))', 3734)))) INHERITS($SCH.contours);
CREATE TABLE $SCH.contour_N2270630(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2270000 630000, 2270000 635000, 2275000 635000, 2275000 630000, 2270000 630000))', 3734)))) INHERITS($SCH.contours);
CREATE TABLE $SCH.contour_N2270635(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2270000 635000, 2270000 640000, 2275000 640000, 2275000 635000, 2270000 635000))', 3734)))) INHERITS($SCH.contours);
CREATE TABLE $SCH.contour_N2270640(CHECK(ST_CoveredBy(the_geom, ST_GeomFromText('POLYGON((2270000 640000, 2270000 645000, 2275000 645000, 2275000 640000, 2270000 640000))', 3734)))) INHERITS($SCH.contours);
EOF

if [[ ! -d contours ]]; then
  mkdir ./contours
  unzip contours1 -d contours
#  unzip contours2 -d contours
#  unzip contours3 -d contours
fi

#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2260630 $SCH.contour_N2260630 | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2260635 $SCH.contour_N2260635 | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2260640 $SCH.contour_N2260640 | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2265630 $SCH.contour_N2265630 | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2265635 $SCH.contour_N2265635 | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2265640 $SCH.contour_N2265640 | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2270630 $SCH.contour_N2270630 | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2270635 $SCH.contour_N2270635 | psql -U $USER -d $DB
#shp2pgsql -s 3734 -a -i -I -W LATIN1 -g the_geom contours/N2270640 $SCH.contour_N2270640 | psql -U $USER -d $DB

echo '### 5. Normalizing imports'

if [[ ! -d trails ]]; then
  mkdir ./trails
  unzip trails -d trails
fi

shp2pgsql -s 3734 -d -i -I -W LATIN1 -g the_geom trails/trails $SCH.trails | psql -U $USER -d $DB

cat << EOF | su - vagrant -c "psql -d $DB"
CREATE TABLE $SCH.trails_names AS WITH labellike AS
(SELECT '%' || label_name || '%' AS label_name, label_name as label, res FROM
(SELECT DISTINCT label_name, res FROM $SCH.trails
WHERE label_name NOT LIKE '%&%' ORDER BY label_name, res) AS label)
SELECT t.gid, ll.label, ll.res FROM $SCH.trails AS t, labellike AS ll
WHERE t.label_name LIKE ll.label_name AND t.res = ll.res ORDER BY gid;

CREATE TABLE $SCH.trails_geom AS SELECT gid, the_geom FROM $SCH.trails;

ALTER TABLE $SCH.trails_geom ADD PRIMARY KEY (gid);
ALTER TABLE $SCH.trails_names ADD FOREIGN KEY (gid) REFERENCES $SCH.trails_geom(gid)
EOF

echo '### 6. Normalizing internal overlays'

if [[ ! -d use_area ]]; then
  mkdir ./use_area
  unzip use_area -d use_area
fi

shp2pgsql -s 3734 -d -i -I -W LATIN1 -g the_geom use_area/cm_usearea_polygon $SCH.use_area | psql -U $USER -d $DB

cat << EOF | su - vagrant -c "psql -d $DB"
\i $DIR/polygon_to_line.sql
ALTER FUNCTION polygon_to_line(geometry) OWNER TO $USER;

CREATE TABLE $SCH.use_area_alt AS (
SELECT (ST_Dump(the_geom)).geom AS the_geom FROM (SELECT ST_Polygonize(the_geom) AS the_geom FROM (
SELECT ST_Union(the_geom) AS the_geom FROM (SELECT polygon_to_line(the_geom) AS the_geom FROM
$SCH.use_area) AS unioned) AS polygonized) AS exploded);

CREATE INDEX use_area_alt_the_geom_gist_idx ON $SCH.use_area_alt USING gist(the_geom);

CREATE TABLE $SCH.use_area_alt_p AS SELECT ST_SetSRID(ST_PointOnSurface(the_geom), 3734) AS the_geom FROM $SCH.use_area_alt;
ALTER TABLE $SCH.use_area_alt_p ADD COLUMN gid serial;
ALTER TABLE $SCH.use_area_alt_p ADD PRIMARY KEY (gid);

CREATE INDEX use_area_alt_p_the_geom_gist_idx ON $SCH.use_area_alt_p USING gist(the_geom);
CREATE TABLE $SCH.use_area_alt_relation AS SELECT points.gid, cu.location FROM $SCH.use_area_alt_p AS points, $SCH.use_area AS cu WHERE ST_Intersects(points.the_geom, cu.the_geom);
ALTER TABLE $SCH.use_area_alt_relation ADD FOREIGN KEY (gid) REFERENCES $SCH.use_area_alt_p (gid);
EOF

echo '### 7. Using polygon overlays for proportional census estimates'

if [[ ! -d trail_census ]]; then
  mkdir ./trail_census
  unzip trail_census -d trail_census
fi

shp2pgsql -s 3734 -d -i -I -W LATIN1 -g the_geom trail_census/census $SCH.trail_census | psql -U $USER -d $DB
shp2pgsql -s 3734 -d -i -I -W LATIN1 -g the_geom trail_census/trail_alignment_proposed_buffer $SCH.trail_buffer | psql -U $USER -d $DB
shp2pgsql -s 3734 -d -i -I -W LATIN1 -g the_geom trail_census/trail_alignment_proposed $SCH.trail_alignment_prop | psql -U $USER -d $DB

cat << EOF | su - vagrant -c "psql -d $DB"
\i $DIR/proportional_sum.sql

SELECT ROUND(SUM(proportional_sum(a.the_geom, b.the_geom, b.pop))) FROM
$SCH.trail_buffer AS a, $SCH.trail_census as b
WHERE ST_Intersects(a.the_geom, b.the_geom)
GROUP BY a.gid;

EOF

