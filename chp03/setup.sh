#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
DIR=/vagrant/chp03

cd $DIR/

cat << EOF | su - vagrant -c "psql -d $DB"
DROP SCHEMA IF EXISTS chp03 CASCADE;
CREATE SCHEMA chp03;
EOF

echo '### 1. Working with GPS data'

echo '### 2. Fixing invalid geometries'

echo '### 3. GIS analysis with spatial joins'

echo '### 4. Simplifying geometries'

echo '### 5. Measuring distances'

echo '### 6. Merging polygons using a common attribute'

echo '### 7. Computing intersections'

echo '### 8. Clipping geometries to deploy data'

echo '### 9. Simplifying geometries with PostGIS topology'


