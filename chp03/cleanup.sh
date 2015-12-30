#!/bin/bash

USER=vagrant
SCH=chp03
DIR=/$USER/$SCH
cd $DIR/

if [[ -d runkeeper_gpx ]]; then
  rm -rf runkeeper_gpx
fi

if [[ -d TM_WORLD_BORDERS-0.3 ]]; then
  rm -rf TM_WORLD_BORDERS-0.3
fi

if [[ -f 2012_Earthquakes_ALL.kml ]]; then
  rm -f 2012_Earthquakes_ALL.kml
fi

if [[ -d citiesx020 ]]; then
  rm -rf citiesx020
fi

if [[ -d statesp020 ]]; then
  rm -rf statesp020
fi

if [[ -d co2000p020 ]]; then
  rm -rf co2000p020
fi

if [[ -d 10m-rivers-lake-centerlines ]]; then
  rm -rf 10m-rivers-lake-centerlines
fi

if [[ -d rivers ]]; then
  rm -rf rivers
fi

if [[ -d HUN_adm ]]; then
  rm -rf HUN_adm
fi

