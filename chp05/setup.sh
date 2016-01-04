#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCH=chp05
DIR=/$USER/$SCH

cd $DIR/

cat << EOF | su - $USER -c "psql -d $DB"
DROP SCHEMA IF EXISTS $SCH CASCADE;
CREATE SCHEMA $SCH;
EOF

echo '### p174. Getting and loading rasters'

raster2pgsql -s 4322 -t 100x100 -F -I -C -Y PRISM/us_tmin_2012.*.asc $SCH.prism | psql -d $DB -U $USER

cat << EOF | su - $USER -c "psql -d $DB"
ALTER TABLE $SCH.prism ADD COLUMN month_year DATE;
UPDATE $SCH.prism SET month_year = (split_part(split_part(filename, '.', 1), '_', 3) || '-' || split_part(filename, '.', 2) || '-01' )::date;
EOF

raster2pgsql -s 4326 -t 100x100 -F -I -C -Y SRTM/N37W123.hgt $SCH.srtm | psql -d $DB -U $USER
shp2pgsql -s 3310 -I SFPoly/sfpoly.shp $SCH.sfpoly | psql -d $DB -U $USER

echo '### p182. Performing simple map-algebra operations'


cat << EOF | su - $USER -c "psql -d $DB"
WITH stats AS (SELECT 'before' AS state, (ST_SummaryStats(rast, 1)).* FROM $SCH.prism WHERE rid = 550 UNION ALL SELECT 'after' AS state, (ST_SummaryStats(ST_MapAlgebra(rast, 1, '32BF', '[rast] / 100.', -9999),1)).* FROM $SCH.prism WHERE rid = 550) SELECT state, count, round(sum::numeric, 2) AS sum, round(mean::numeric, 2) AS mean, round(stddev::numeric, 2) AS stddev, round(min::numeric, 2) AS min, round(max::numeric, 2) AS max FROM stats ORDER BY state DESC;
SELECT DropRasterConstraints('$SCH', 'prism', 'rast'::name);
UPDATE $SCH.prism SET rast = ST_AddBand(rast, ST_MapAlgebra(rast, 1, '32BF', '[rast] / 100.', -9999), 1);
SELECT AddRasterConstraints('$SCH', 'prism', 'rast'::name);
EOF

echo '### p194. Processing and loading rasters with GDAL VRT'

cat << EOF | su - $USER
cd /$USER/$SCH/MODIS
psql -d $DB -f srs.sql
gdalbuildvrt -separate -input_file_list modis.txt modis.vrt
gdal_translate -of GTiff modis.vrt modis.tif
raster2pgsql -s 96974 -F -I -C -Y modis.tif $SCH.modis | psql -d $DB
EOF
