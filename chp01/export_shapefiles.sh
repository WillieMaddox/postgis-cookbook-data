#!/bin/bash
while IFS="," read country iso2 hs_count
do
 echo "Generating shapefile $iso2.shp for country $country ($iso2) containing $hs_count features."
 ogr2ogr out_shapefiles/$iso2.shp PG:"dbname='postgis_cookbook' user='me' password='mypassword'" -lco SCHEMA=chp01 -sql "SELECT ST_Transform(hs.the_geom, 4326), hs.acq_date, hs.acq_time, hs.bright_t31 FROM chp01.hotspots as hs JOIN chp01.countries as c ON ST_Contains(c.the_geom, ST_Transform(hs.the_geom, 4326)) WHERE c.iso2 = '$iso2'"
done < hs_countries.csv

