#!/bin/bash
apt-get -qqy update
apt-get upgrade
apt-get install -qy vim git finger unzip python-dev python-setuptools
apt-get install -qy postgresql postgresql-client postgresql-common postgresql-contrib postgresql-9.3-dbg postgresql-server-dev-all postgresql-9.3-postgis-2.1 postgresql-plpython-9.3 postgis postgis-doc gdal-bin libgdal-dev libproj-dev libpq-dev osm2pgsql 
# LIDAR
apt-get install -qy liblas2 liblas-bin liblas-dev libfreetype6-dev
# python
easy_install pip
pip install urllib3[secure]
pip install pyhull
pip install django==1.8
pip install vectorformats
pip install geojson
pip install psycopg2
pip install Pillow

sed -i  's/md5/trust/' /etc/postgresql/9.3/main/pg_hba.conf
sed -i  's/peer/trust/' /etc/postgresql/9.3/main/pg_hba.conf

service postgresql restart
