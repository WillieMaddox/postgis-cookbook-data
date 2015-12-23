#!/bin/bash 
for f in `ogrinfo PG:"dbname='postgis_cookbook' user='me' password='mypassword'" -sql "SELECT DISTINCT(iso2) FROM chp03.countries ORDER BY iso2" | grep iso2 | awk '{print $4}'` 
do 
    echo "Exporting river shapefile for $f country..." 
    ogr2ogr rivers/rivers_$f.shp PG:"dbname='postgis_cookbook' user='me' password='mypassword'" -sql "SELECT * FROM chp03.rivers_clipped_by_country WHERE iso2 = '$f'" 
done
