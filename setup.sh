#!/bin/bash

cat << EOF | su - postgres -c psql
CREATE USER vagrant WITH SUPERUSER PASSWORD 'vagrant0';
EOF

cat << EOF | su - vagrant
createdb -O vagrant -E UTF8 postgis_cookbook
psql -d postgis_cookbook -c 'CREATE EXTENSION postgis;'
psql -d postgis_cookbook -c 'CREATE EXTENSION postgis_topology;'
EOF

