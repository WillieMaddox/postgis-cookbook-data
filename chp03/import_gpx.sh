#!/bin/bash
for f in `find runkeeper_gpx -name \*.gpx -printf "%f\n"`
do
    echo "Importing gpx file $f to chp03.rk_track_points PostGIS table..." #, ${f%.*}"
    ogr2ogr -append -update  -f PostgreSQL PG:"dbname='postgis_cookbook' user='me' password='mypassword'" runkeeper_gpx/$f -nln chp03.rk_track_points -sql "SELECT ele, time FROM track_points"
done
