#!/bin/bash
cat << EOF | su - vagrant
psql -d postgis_cookbook -c "CREATE SCHEMA chp01;"
EOF
