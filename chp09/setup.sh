#!/bin/bash

apt-get install apache2 default-jre tomcat7

if [[ ! -f /var/lib/tomcat7/webapps/geoserver.war]]; do
  cp /vagrant/geoserver.war /var/lib/tomcat7/webapps/geoserver.war
  service tomcat7 restart
fi


USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCH=chp09
DIR=/$USER/$SCH

cd $DIR/

cat << EOF | su - $USER -c "psql -d $DB"
DROP SCHEMA IF EXISTS $SCH CASCADE;
CREATE SCHEMA $SCH;
EOF

echo '### p326. Creating WMS and WFS services with MapServer'









echo '### p339. Creating WMS and WFS services with GeoServer'

ogr2ogr -f PostgreSQL -a_srs EPSG:4326 -lco GEOMETRY_NAME=the_geom -nln chp09.counties PG:"dbname=$DB user=$USER password=$PASS" co2000p020.shp






echo '### p352. Creating a WMS Time with MapServer'








echo '### p359. Consuming WMS services with OpenLayers'








echo '### p365. Consuming WMS services with Leaflet'








echo '### p369. Consuming WFS-T services with OpenLayers'







echo '### p375. Developing web applications with GeoDjango – part 1'






echo '### p386. Developing web applications with GeoDjango – part 2'







