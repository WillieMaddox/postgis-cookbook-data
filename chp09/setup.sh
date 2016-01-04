#!/bin/bash

apt-get install apache2

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








echo '### p352. Creating a WMS Time with MapServer'








echo '### p359. Consuming WMS services with OpenLayers'








echo '### p365. Consuming WMS services with Leaflet'








echo '### p369. Consuming WFS-T services with OpenLayers'







echo '### p375. Developing web applications with GeoDjango – part 1'






echo '### p386. Developing web applications with GeoDjango – part 2'







