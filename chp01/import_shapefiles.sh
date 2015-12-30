#!/bin/bash
for f in `find out_shapefiles -name \*.shp -printf "%f\n"`
do
 echo "Importing shapefile $f to chp01.hs_uploaded PostGIS table..." #, ${f%.*}"
 ogr2ogr -append -update -f PostgreSQL PG:"dbname='postgis_cookbook' user='me' password='mypassword'" out_shapefiles/$f -nln chp01.hs_uploaded -sql "SELECT acq_date, acq_time, bright_t31, '${f%.*}' AS iso2, '`date`' AS upload_datetime, 'out_shapefiles/$f' as shapefile FROM ${f%.*}"
done
