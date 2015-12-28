#!/bin/bash

# Importing LiDAR data

cat << EOF | su - vagrant
psql -d postgis_cookbook -c 'CREATE SCHEMA chp07;'
EOF

cat << EOF | su - vagrant -c 'psql -d postgis_cookbook'
CREATE TABLE chp07.lidar
(
x numeric,
y numeric,
z numeric,
intensity integer,
tnumber integer,
number integer,
class integer,
id integer,
vnum integer
)
WITH (OIDS=FALSE);
EOF

#ALTER TABLE chp07.lidar OWNER TO vagrant;

su - vagrant
cd /vagrant/chp07
x=0
total=`ls *.las | wc | awk '{print $1}'`
for f in $( ls *.las); do
 x=`expr $x + 1`
 echo $x of $total started. $f processing.
 las2txt --parse xyzinrcpM --delimiter "," $f $f.csv
done

cat << EOF | su - vagrant -c 'psql -d postgis_cookbook'
\copy chp07.lidar from '/vagrant/chp07/N2210595.las.csv' with csv
\copy chp07.lidar from '/vagrant/chp07/N2215595.las.csv' with csv
\copy chp07.lidar from '/vagrant/chp07/N2220595.las.csv' with csv
SELECT AddGeometryColumn('chp07', 'lidar', 'the_geom', 3734, 'POINT', 3);
UPDATE chp07.lidar SET the_geom = ST_SetSRID(ST_MakePoint(x, y, z), 3734);
ALTER TABLE chp07.lidar ADD COLUMN gid serial;
ALTER TABLE chp07.lidar ADD PRIMARY KEY (gid);
EOF

# Performing 3D queries on a LiDAR point cloud

cat << EOF | su - vagrant -c 'psql -d postgis_cookbook'
CREATE INDEX chp07_lidar_the_geom_3dx ON chp07.lidar USING gist(the_geom gist_geometry_ops_nd);
EOF

cat << EOF | su - vagrant
cd /vagrant/chp07
shp2pgsql -s 3734 -d -i -I -W LATIN1 -t 3DZ -g the_geom hydro_line.shp chp07.hydro | psql -U vagrant -d postgis_cookbook
EOF

# Constructing and serving buildings 2.5 D


