#!/bin/bash
apt-get -qqy update
apt-get upgrade
apt-get install -qy vim git finger unzip python-dev python-setuptools flex apache2 autoconf
apt-get install -qy postgresql postgresql-client postgresql-common postgresql-contrib postgresql-9.4-dbg postgresql-server-dev-all postgresql-9.4-postgis-2.1 postgresql-plpython-9.4 postgis postgis-doc gdal-bin python-gdal libgdal-dev libgdal1h libproj-dev libpq-dev osm2pgsql 
apt-get install -qy libxml2-dev libxslt1-dev libtiff-dev libtiff5-dev libpng12-dev libpng-dev libjpeg8-dev
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

sed -i  's/md5/trust/' /etc/postgresql/9.4/main/pg_hba.conf
sed -i  's/peer/trust/' /etc/postgresql/9.4/main/pg_hba.conf

service postgresql restart
