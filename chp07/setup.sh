#!/bin/bash

USER=vagrant
PASS=vagrant0
DB=postgis_cookbook
SCH=chp07
DIR=/$USER/$SCH

cd $DIR/

cat << EOF | su - $USER -c "psql -d $DB"
DROP SCHEMA IF EXISTS $SCH CASCADE;
CREATE SCHEMA $SCH;
EOF

# Importing LiDAR data

cat << EOF | su - $USER -c "psql -d $DB"
CREATE TABLE $SCH.lidar
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

#ALTER TABLE $SCH.lidar OWNER TO $USER;

su - $USER
cd /$USER/$SCH
x=0
total=`ls *.las | wc | awk '{print $1}'`
for f in $( ls *.las); do
 x=`expr $x + 1`
 echo $x of $total started. $f processing.
 las2txt --parse xyzinrcpM --delimiter "," $f $f.csv
done

cat << EOF | su - $USER -c "psql -d $DB"
\copy $SCH.lidar from "/$USER/$SCH/N2210595.las.csv" with csv
\copy $SCH.lidar from "/$USER/$SCH/N2215595.las.csv" with csv
\copy $SCH.lidar from "/$USER/$SCH/N2220595.las.csv" with csv
SELECT AddGeometryColumn('$SCH', 'lidar', 'the_geom', 3734, 'POINT', 3);
UPDATE $SCH.lidar SET the_geom = ST_SetSRID(ST_MakePoint(x, y, z), 3734);
ALTER TABLE $SCH.lidar ADD COLUMN gid serial;
ALTER TABLE $SCH.lidar ADD PRIMARY KEY (gid);
EOF

# Performing 3D queries on a LiDAR point cloud

cat << EOF | su - $USER -c "psql -d $DB"
CREATE INDEX $SCH_lidar_the_geom_3dx ON $SCH.lidar USING gist(the_geom gist_geometry_ops_nd);
EOF

shp2pgsql -s 3734 -d -i -I -W LATIN1 -t 3DZ -g the_geom hydro_line.shp $SCH.hydro | psql -U $USER -d $DB

# Constructing and serving buildings 2.5 D


