#!/bin/bash
apt-get -qqy update
apt-get upgrade
apt-get install -qy apache2 vim git finger unzip
apt-get install -qy postgresql postgresql-client postgresql-common postgresql-contrib postgresql-9.3-dbg postgresql-server-dev-all postgresql-9.3-postgis-2.1 postgis postgis-doc gdal-bin libgdal-dev libproj-dev libpq-dev
# LIDAR
apt-get install -qy liblas2 liblas-bin liblas-dev
