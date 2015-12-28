#!/bin/bash

# Getting and loading rasters

cat << EOF | su - vagrant
psql -d postgis_cookbook -c 'CREATE SCHEMA chp05;'
raster2pgsql -s 4322 -t 100x100 -F -I -C -Y /vagrant/chp05/PRISM/us_tmin_2012.*.asc chp05.prism | psql -d postgis_cookbook 
psql -d postgis_cookbook -c "ALTER TABLE chp05.prism ADD COLUMN month_year DATE;"
psql -d postgis_cookbook -c "UPDATE chp05.prism SET month_year = (split_part(split_part(filename, '.', 1), '_', 3) || '-' || split_part(filename, '.', 2) || '-01' )::date;"
raster2pgsql -s 4326 -t 100x100 -F -I -C -Y /vagrant/chp05/SRTM/N37W123.hgt chp05.srtm | psql -d postgis_cookbook
shp2pgsql -s 3310 -I /vagrant/chp05/SFPoly/sfpoly.shp chp05.sfpoly | psql -d postgis_cookbook
EOF

# Performing simple map-algebra operations

cat << EOF | su - vagrant -c "psql -d postgis_cookbook"
WITH stats AS (SELECT 'before' AS state, (ST_SummaryStats(rast, 1)).* FROM chp05.prism WHERE rid = 550 UNION ALL SELECT 'after' AS state, (ST_SummaryStats(ST_MapAlgebra(rast, 1, '32BF', '[rast] / 100.', -9999),1)).* FROM chp05.prism WHERE rid = 550) SELECT state, count, round(sum::numeric, 2) AS sum, round(mean::numeric, 2) AS mean, round(stddev::numeric, 2) AS stddev, round(min::numeric, 2) AS min, round(max::numeric, 2) AS max FROM stats ORDER BY state DESC;
SELECT DropRasterConstraints('chp05', 'prism', 'rast'::name);
UPDATE chp05.prism SET rast = ST_AddBand(rast, ST_MapAlgebra(rast, 1, '32BF', '[rast] / 100.', -9999), 1);
SELECT AddRasterConstraints('chp05', 'prism', 'rast'::name);
EOF

# Processing and loading rasters with GDAL VRT

cat << EOF | su - vagrant
cd /vagrant/chp05/MODIS
psql -d postgis_cookbook -f srs.sql
gdalbuildvrt -separate -input_file_list modis.txt modis.vrt
gdal_translate -of GTiff modis.vrt modis.tif
raster2pgsql -s 96974 -F -I -C -Y modis.tif chp05.modis | psql -d postgis_cookbook
EOF
