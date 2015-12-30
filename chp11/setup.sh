#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCH=chp11
DIR=/$USER/$SCH

cd $DIR/

cat << EOF | su - vagrant -c "psql -d $DB"
DROP SCHEMA IF EXISTS $SCH CASCADE;
CREATE SCHEMA $SCH;
EOF

echo '### 1. '

echo '### 2. '

echo '### 3. '

echo '### 4. '

echo '### 5. '

echo '### 6. '

echo '### 7. '

echo '### 8. '

echo '### 9. '


