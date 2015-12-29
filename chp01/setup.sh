#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCMA=chp01
DIR=/vagrant/chp01

cd $DIR/

echo '### 1. Importing nonspatial tabular data (csv) using PostGIS functions'

cat << EOF | su - vagrant -c "psql -d $DB"
CREATE SCHEMA chp01;
CREATE TABLE chp01.firenews(x float8, y float8, place varchar(100), size float8, update date, startdate date, enddate date, title varchar(255), url varchar(255), the_geom geometry(POINT, 4326));
COPY chp01.firenews (x, y, place, size, update, startdate, enddate, title, url) FROM '$DIR/firenews.csv' WITH CSV HEADER;
UPDATE chp01.firenews SET the_geom = ST_SetSRID(ST_MakePoint(x,y), 4326);
CREATE INDEX idx_firenews_geom ON chp01.firenews USING GIST (the_geom);
EOF

echo '### 2. Importing nonspatial tabular data (CSV) using GDAL'

ogr2ogr -f PostgreSQL -t_srs EPSG:3857 PG:"dbname='$DB' user='$USER' password='$PASS'" -lco SCHEMA=chp01 global_24h.vrt -where "satellite='T'" -lco GEOMETRY_NAME=the_geom

echo '### 3. Importing shapefiles with shp2pgsql'

ogr2ogr global_24h.shp global_24h.vrt
shp2pgsql -G -I global_24h.shp chp01.global_24h_geographic | psql -d $DB -U $USER

echo '### 4. Importing and exporting data with the ogr2ogr GDAL command'
ogr2ogr -f PostgreSQL -sql "SELECT ISO2, NAME AS country_name FROM 'TM_WORLD_BORDERS-0.3' WHERE REGION=2" -nlt MULTIPOLYGON PG:"dbname='$DB' user='$USER' password='$PASS'" -nln africa_countries -lco SCHEMA=chp01 -lco GEOMETRY_NAME=the_geom TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp
if [[ -f warmest_hs.geojson ]]; then
    rm warmest_hs.geojson
fi
ogr2ogr -f GeoJSON -t_srs EPSG:4326 warmest_hs.geojson PG:"dbname='$DB' user='$USER' password='$PASS'" -sql "SELECT f.the_geom as the_geom, f.bright_t31, ac.iso2, ac.country_name FROM chp01.global_24h as f JOIN chp01.africa_countries as ac ON ST_Contains(ac.the_geom, ST_Transform(f.the_geom, 4326)) ORDER BY f.bright_t31 DESC LIMIT 100"
if [[ -f warmest_hs.csv ]]; then
    rm warmest_hs.csv
fi
ogr2ogr -f CSV -t_srs EPSG:4326 -lco GEOMETRY=AS_XY -lco SEPARATOR=TAB warmest_hs.csv PG:"dbname='$DB' user='$USER' password='$PASS'" -sql "SELECT f.the_geom, f.bright_t31, ac.iso2, ac.country_name FROM chp01.global_24h as f JOIN chp01.africa_countries as ac ON ST_Contains(ac.the_geom, ST_Transform(f.the_geom, 4326)) ORDER BY f.bright_t31 DESC LIMIT 100"

echo '### 5. Handling batch importing and exporting of datasets'

if [[ -f hs_countries.csv ]]; then
    rm hs_countries.csv
fi
ogr2ogr -f PostgreSQL PG:"dbname='$DB' user='$USER' password='$PASS'" -lco SCHEMA=chp01 -lco OVERWRITE=YES -lco GEOMETRY_NAME=the_geom -nln hotspots global_24h.vrt 
ogr2ogr -f PostgreSQL -sql "SELECT ISO2, NAME AS country_name FROM 'TM_WORLD_BORDERS-0.3'" -nlt MULTIPOLYGON PG:"dbname='$DB' user='$USER' password='$PASS'" -nln countries -lco SCHEMA=chp01 -lco OVERWRITE=YES -lco GEOMETRY_NAME=the_geom TM_WORLD_BORDERS-0.3/TM_WORLD_BORDERS-0.3.shp
#or
cat << EOF | su - vagrant -c "psql -d $DB"
ALTER TABLE chp01.hotspots ALTER COLUMN the_geom SET DATA TYPE geometry(Point, 4326) USING ST_Transform(the_geom, 4326);
EOF
ogr2ogr -f CSV hs_countries.csv PG:"dbname='$DB' user='$USER' password='$PASS'" -lco SCHEMA=chp01 -sql "SELECT c.country_name, MIN(c.iso2) as iso2, count(*) as hs_count FROM chp01.hotspots as hs JOIN chp01.countries as c ON ST_Contains(c.the_geom, hs.the_geom) GROUP BY c.country_name ORDER BY c.country_name"
#or
#cat << EOF | su - vagrant -c "psql -d $DB"
#COPY (SELECT c.country_name, MIN(c.iso2) as
#iso2, count(*) as hs_count
#FROM chp01.hotspots as hs
#JOIN chp01.countries as c
#ON ST_Contains(c.the_geom, hs.the_geom)
#GROUP BY c.country_name
#ORDER BY c.country_name) TO '$DIR/hs_countries.csv' WITH CSV HEADER;
#EOF
if [[ -d out_shapefiles ]]; then
    rm -rf out_shapefiles
fi
mkdir ./out_shapefiles
while IFS="," read country iso2 hs_count
do
 echo "Generating shapefile $iso2.shp for country $country ($iso2) containing $hs_count features."
 ogr2ogr $DIR/out_shapefiles/$iso2.shp PG:"dbname='$DB' user='$USER' password='$PASS'" -lco SCHEMA=chp01 -sql "SELECT ST_Transform(hs.the_geom, 4326), hs.acq_date, hs.acq_time, hs.bright_t31 FROM chp01.hotspots as hs JOIN chp01.countries as c ON ST_Contains(c.the_geom, ST_Transform(hs.the_geom, 4326)) WHERE c.iso2 = '$iso2'"
done < hs_countries.csv
cat << EOF | su - vagrant -c "psql -d $DB"
CREATE TABLE chp01.hs_uploaded
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
 echo "Importing shapefile $f to chp01.hs_uploaded PostGIS table..." #, ${f%.*}"
 ogr2ogr -append -update -f PostgreSQL PG:"dbname='$DB' user='$USER' password='$PASS'" out_shapefiles/$f -nln chp01.hs_uploaded -sql "SELECT acq_date, acq_time, bright_t31, '${f%.*}' AS iso2, '`date`' AS upload_datetime, 'out_shapefiles/$f' as shapefile FROM ${f%.*}"
done

echo '### 6. Exporting data to the shapefile with the pgsql2shp PostGIS command'

shp2pgsql -I -d -s 4326 -W LATIN1 -g the_geom countries.shp chp01.countries > countries.sql
psql -d $DB -U $USER -f countries.sql
#or
#ogr2ogr -f PostgreSQL PG:"dbname='$DB' user='$USER' password='$PASS'" -lco SCHEMA=chp01 countries.shp -nlt MULTIPOLYGON -lco OVERWRITE=YES -lco GEOMETRY_NAME=the_geom
pgsql2shp -f subregions.shp -h localhost -u $USER -P $PASS $DB "SELECT MIN(subregion) AS subregion, ST_Union(the_geom) AS the_geom, SUM(pop2005) AS pop2005 FROM chp01.countries GROUP BY subregion;"

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

echo '### 8. Importing raster data with the raster2pgsql PostGIS command'

if [[ -d worldclim ]]; then
    rm -rf worldclim
fi
mkdir ./worldclim
unzip tmax_10m_bil.zip -d worldclim
#raster2pgsql -I -C -F -t 100x100 -s 4326 worldclim/tmax01.bil chp01.tmax01 > tmax01.sql
raster2pgsql -I -C -F -t 100x100 -s 4326 worldclim/tmax1.bil chp01.tmax01 > tmax01.sql
psql -d $DB -U $USER -f tmax01.sql
#or
#raster2pgsql -I -C -M -F -t 100x100 worldclim/tmax1.bil chp01.tmax01 | psql -d $DB -U $USER -f tmax01.sql
ogr2ogr temp_grid.shp PG:"host=localhost port=5432 dbname='$DB' user='$USER' password='$PASS'" -sql "SELECT rid, filename, ST_Envelope(rast) as the_geom FROM chp01.tmax01"

echo '### 9. Importing multiple rasters at a time'

raster2pgsql -d -I -C -M -F -t 100x100 -s 4326 worldclim/tmax*.bil chp01.tmax_2012 > tmax_2012.sql
psql -d $DB -U $USER -f tmax_2012.sql

echo '### 10. Exporting rasters with the gdal_translate and gdalwarp GDAL commands'

gdalinfo PG:"host=localhost port=5432 dbname='$DB' user='$USER' password='$PASS' schema='chp01' table='tmax_2012_multi' mode='2'"
gdal_translate -b 1 -b 2 -b 3 -b 4 -b 5 -b 6 PG:"host=localhost port=5432 dbname='$DB' user='$USER' password='$PASS' schema='chp01' table='tmax_2012_multi' mode='2'" tmax_2012_multi_123456.tif
cat << EOF | su - vagrant -c "psql -d $DB"
SELECT ST_Extent(the_geom) FROM chp01.countries WHERE name = 'Italy';
EOF
gdal_translate -projwin 6.619 47.095 18.515 36.649 PG:"host=localhost port=5432 dbname='$DB' user='$USER' password='$PASS' schema='chp01' table='tmax_2012_multi' mode='2'" tmax_2012_multi.tif
gdalwarp -t_srs EPSG:3857 PG:"host=localhost port=5432 dbname='$DB' user='$USER' password='$PASS' schema='chp01' table='tmax_2012_multi' mode='2'" tmax_2012_multi_3857.tif


