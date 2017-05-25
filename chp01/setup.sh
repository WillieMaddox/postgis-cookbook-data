#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCH=chp01
DIR=/vagrant/$SCH

cd $DIR/

cat << EOF | su - vagrant -c "psql -d $DB"
DROP SCHEMA IF EXISTS $SCH CASCADE;
CREATE SCHEMA $SCH;
EOF

echo '### 1. Importing nonspatial tabular data (csv) using PostGIS functions'

cat << EOF | su - vagrant -c "psql -d $DB"
CREATE TABLE $SCH.firenews(x float8, y float8, place varchar(100), size float8, update date, startdate date, enddate date, title varchar(255), url varchar(255), the_geom geometry(POINT, 4326));
COPY $SCH.firenews (x, y, place, size, update, startdate, enddate, title, url) FROM "$DIR/firenews.csv" WITH CSV HEADER;
UPDATE $SCH.firenews SET the_geom = ST_SetSRID(ST_MakePoint(x,y), 4326);
CREATE INDEX idx_firenews_geom ON $SCH.firenews USING GIST (the_geom);
EOF

echo '### 2. Importing nonspatial tabular data (CSV) using GDAL'

echo '-----. BEGIN ogr2ogr PG: global_24h.vrt'
ogr2ogr -f PostgreSQL -t_srs EPSG:3857 PG:"dbname=$DB user=$USER password=$PASS" -lco SCHEMA=$SCH global_24h.vrt -where "satellite='T'" -lco GEOMETRY_NAME=the_geom

echo '### 3. Importing shapefiles with shp2pgsql'

echo '-----. BEGIN ogr2ogr global_24h.shp global_24h.vrt'
ogr2ogr global_24h.shp global_24h.vrt
echo '-----. BEGIN shp2pgsql global_24h.shp $SCH.global_24h_geographic'
shp2pgsql -G -I global_24h.shp $SCH.global_24h_geographic | psql -d $DB -U $USER

echo '### 4. Importing and exporting data with the ogr2ogr GDAL command'

if [[ ! -d TM_WORLD_BORDERS-0.3 ]]; then
  mkdir ./TM_WORLD_BORDERS-0.3
  unzip TM_WORLD_BORDERS-0.3 -d TM_WORLD_BORDERS-0.3
fi

echo '-----. BEGIN ogr2ogr PG: TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp'
ogr2ogr -f PostgreSQL -sql "SELECT ISO2, NAME AS country_name FROM 'TM_WORLD_BORDERS-0.3' WHERE REGION=2" -nlt MULTIPOLYGON PG:"dbname=$DB user=$USER password=$PASS" -nln africa_countries -lco SCHEMA=$SCH -lco GEOMETRY_NAME=the_geom TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp

if [[ -f warmest_hs.geojson ]]; then
    rm warmest_hs.geojson
fi

echo '-----. BEGIN ogr2ogr warmest_hs.geojson PG:'
ogr2ogr -f GeoJSON -t_srs EPSG:4326 warmest_hs.geojson PG:"dbname=$DB user=$USER password=$PASS" -sql "SELECT f.the_geom as the_geom, f.bright_t31, ac.iso2, ac.country_name FROM $SCH.global_24h as f JOIN $SCH.africa_countries as ac ON ST_Contains(ac.the_geom, ST_Transform(f.the_geom, 4326)) ORDER BY f.bright_t31 DESC LIMIT 100"

if [[ -f warmest_hs.csv ]]; then
    rm warmest_hs.csv
fi

echo '-----. BEGIN ogr2ogr warmest_hs.csv PG:'
ogr2ogr -f CSV -t_srs EPSG:4326 -lco GEOMETRY=AS_XY -lco SEPARATOR=TAB warmest_hs.csv PG:"dbname=$DB user=$USER password=$PASS" -sql "SELECT f.the_geom, f.bright_t31, ac.iso2, ac.country_name FROM $SCH.global_24h as f JOIN $SCH.africa_countries as ac ON ST_Contains(ac.the_geom, ST_Transform(f.the_geom, 4326)) ORDER BY f.bright_t31 DESC LIMIT 100"

echo '### 5. Handling batch importing and exporting of datasets'

if [[ -f hs_countries.csv ]]; then
    rm hs_countries.csv
fi

echo '-----. BEGIN ogr2ogr PG: global_24h.vrt'
ogr2ogr -f PostgreSQL PG:"dbname=$DB user=$USER password=$PASS" -lco SCHEMA=$SCH -lco OVERWRITE=YES -lco GEOMETRY_NAME=the_geom -nln hotspots global_24h.vrt

echo '-----. BEGIN ogr2ogr PG: TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp'
ogr2ogr -f PostgreSQL -sql "SELECT ISO2, NAME AS country_name FROM 'TM_WORLD_BORDERS-0.3'" -nlt MULTIPOLYGON PG:"dbname=$DB user=$USER password=$PASS" -nln countries -lco SCHEMA=$SCH -lco OVERWRITE=YES -lco GEOMETRY_NAME=the_geom TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp

cat << EOF | su - vagrant -c "psql -d $DB"
ALTER TABLE $SCH.hotspots ALTER COLUMN the_geom SET DATA TYPE geometry(Point, 4326) USING ST_Transform(the_geom, 4326);
EOF

echo '-----. BEGIN ogr2ogr hs_countries.csv PG:'
ogr2ogr -f CSV hs_countries.csv PG:"dbname=$DB user=$USER password=$PASS" -lco SCHEMA=$SCH -sql "SELECT c.country_name, MIN(c.iso2) as iso2, count(*) as hs_count FROM $SCH.hotspots as hs JOIN $SCH.countries as c ON ST_Contains(c.the_geom, hs.the_geom) GROUP BY c.country_name ORDER BY c.country_name"
#or
#cat << EOF | su - vagrant -c "psql -d $DB"
#COPY (SELECT c.country_name, MIN(c.iso2) as
#iso2, count(*) as hs_count
#FROM $SCH.hotspots as hs
#JOIN $SCH.countries as c
#ON ST_Contains(c.the_geom, hs.the_geom)
#GROUP BY c.country_name
#ORDER BY c.country_name) TO '$DIR/hs_countries.csv' WITH CSV HEADER;
#EOF
if [[ ! -d out_shapefiles ]]; then
  mkdir ./out_shapefiles
fi
while IFS="," read country iso2 hs_count
do
 echo "Generating shapefile $iso2.shp for country $country ($iso2) containing $hs_count features."
 ogr2ogr $DIR/out_shapefiles/$iso2.shp PG:"dbname=$DB user=$USER password=$PASS" -lco SCHEMA=$SCH -sql "SELECT ST_Transform(hs.the_geom, 4326), hs.acq_date, hs.acq_time, hs.bright_t31 FROM $SCH.hotspots as hs JOIN $SCH.countries as c ON ST_Contains(c.the_geom, ST_Transform(hs.the_geom, 4326)) WHERE c.iso2 = '$iso2'"
done < hs_countries.csv
cat << EOF | su - vagrant -c "psql -d $DB"
CREATE TABLE $SCH.hs_uploaded
(
ogc_fid serial NOT NULL,
acq_date character varying(80),
acq_time character varying(80),
bright_t31 character varying(80),
iso2 character varying,
upload_datetime character varying,
shapefile character varying,
the_geom geometry(POINT, 4326),
CONSTRAINT hs_uploaded_pk PRIMARY KEY (ogc_fid)
);
EOF
for f in `find ./out_shapefiles -name \*.shp -printf "%f\n"`
do
 echo "Importing shapefile $f to $SCH.hs_uploaded PostGIS table..." #, ${f%.*}"
 ogr2ogr -append -update -f PostgreSQL PG:"dbname=$DB user=$USER password=$PASS" out_shapefiles/$f -nln $SCH.hs_uploaded -sql "SELECT acq_date, acq_time, bright_t31, '${f%.*}' AS iso2, '`date`' AS upload_datetime, 'out_shapefiles/$f' as shapefile FROM ${f%.*}"
done

echo '### 6. Exporting data to the shapefile with the pgsql2shp PostGIS command'

echo '-----. BEGIN shp2pgsql countries.shp $SCH.countries'
shp2pgsql -I -d -s 4326 -W LATIN1 -g the_geom countries.shp $SCH.countries > countries.sql
echo '-----. BEGIN psql countries.sql'
psql -d $DB -U $USER -f countries.sql
#or
#echo '-----. BEGIN ogr2ogr PG: countries.shp'
#ogr2ogr -f PostgreSQL PG:"dbname=$DB user=$USER password=$PASS" -lco SCHEMA=$SCH countries.shp -nlt MULTIPOLYGON -lco OVERWRITE=YES -lco GEOMETRY_NAME=the_geom
echo '-----. BEGIN pgsql2shp subregions.shp'
pgsql2shp -f subregions.shp -h localhost -u $USER -P $PASS $DB "SELECT MIN(subregion) AS subregion, ST_Union(the_geom) AS the_geom, SUM(pop2005) AS pop2005 FROM $SCH.countries GROUP BY subregion;"

echo '### 7. Importing OpenStreetMap data with the osm2pgsql command'

cat << EOF | su - postgres -c psql
CREATE DATABASE rome OWNER $USER;
\connect rome;
CREATE EXTENSION postgis;
CREATE EXTENSION hstore;
EOF
#psql -d rome -U $USER
#rome=# CREATE EXTENSION hstore;
osm2pgsql -d rome -U $USER --hstore map.osm

icat << EOF | su - postgres -c psql -d rome
CREATE VIEW rome_trees AS
SELECT way, tags FROM planet_osm_polygon
WHERE (tags -> 'landcover') = 'trees';
EOF

echo '### 8. Importing raster data with the raster2pgsql PostGIS command'

if [[ ! -d worldclim ]]; then
  mkdir ./worldclim
  unzip tmax_10m_bil.zip -d worldclim
fi
echo '-----. BEGIN raster2pgsql worldclim/tmax1.bil tmax1.sql'
raster2pgsql -I -C -F -t 100x100 -s 4326 worldclim/tmax1.bil $SCH.tmax1 > tmax1.sql
echo '-----. BEGIN psql tmax1.sql'
psql -d $DB -U $USER -f tmax1.sql
#or
#echo '-----. BEGIN raster2pgsql worldclim/tmax1.bil tmax1.sql'
#raster2pgsql -I -C -M -F -t 100x100 worldclim/tmax1.bil $SCH.tmax1 | psql -d $DB -U $USER -f tmax1.sql
echo '-----. BEGIN ogr2ogr temp_grid.shp PG:'
ogr2ogr temp_grid.shp PG:"host=localhost port=5432 dbname=$DB user=$USER password=$PASS" -sql "SELECT rid, filename, ST_Envelope(rast) as the_geom FROM $SCH.tmax1"

echo '### 9. Importing multiple rasters at a time'

echo '-----. BEGIN raster2pgsql worldclim/tmax*.bil tmax_2012.sql'
raster2pgsql -d -I -C -M -F -t 100x100 -s 4326 worldclim/tmax*.bil $SCH.tmax_2012 > tmax_2012.sql
echo '-----. BEGIN psql tmax_2012.sql'
psql -d $DB -U $USER -f tmax_2012.sql

gdalbuildvrt -separate tmax_2012.vrt worldclim/tmax*.bil
raster2pgsql -d -I -C -M -F -t 100x100 -s 4326 tmax_2012.vrt $SCH.tmax_2012_multi > tmax_2012_multi.sql
psql -d $DB -U $USER -f tmax_2012_multi.sql

echo '### 10. Exporting rasters with the gdal_translate and gdalwarp GDAL commands'

gdalinfo PG:"host=localhost port=5432 dbname=$DB user=$USER password=$PASS schema='$SCH' table='tmax_2012_multi' mode='2'"
gdal_translate -b 1 -b 2 -b 3 -b 4 -b 5 -b 6 PG:"host=localhost port=5432 dbname=$DB user=$USER password=$PASS schema='$SCH' table='tmax_2012_multi' mode='2'" tmax_2012_multi_123456.tif
cat << EOF | su - vagrant -c "psql -d $DB"
SELECT ST_Extent(the_geom) FROM $SCH.countries WHERE name = 'Italy';
EOF
gdal_translate -projwin 6.619 47.095 18.515 36.649 PG:"host=localhost port=5432 dbname=$DB user=$USER password=$PASS schema='$SCH' table='tmax_2012_multi' mode='2'" tmax_2012_multi.tif
gdalwarp -t_srs EPSG:3857 PG:"host=localhost port=5432 dbname=$DB user=$USER password=$PASS schema='$SCH' table='tmax_2012_multi' mode='2'" tmax_2012_multi_3857.tif


