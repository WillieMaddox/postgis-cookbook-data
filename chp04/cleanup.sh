#!/bin/bash

USER=vagrant
SCH=chp04
DIR=/$USER/$SCH

cd $DIR/

if [[ -d lidar_buildings ]]; then
  rm -rf lidar_buildings
fi

if [[ -d cuy_streets ]]; then
  rm -rf cuy_streets
fi

if [[ -d cuy_address_points ]]; then
  rm -rf cuy_address_points
fi

