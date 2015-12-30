#!/bin/bash

cd /vagrant/chp02

if [[ -d hydrology ]]; then
    rm -rf hydrology
fi

if [[ -d contours ]]; then
    rm -rf contours
fi

if [[ -d trails ]]; then
    rm -rf trails
fi

if [[ -d use_area ]]; then
    rm -rf use_area
fi

if [[ -d trail_census ]]; then
    rm -rf trail_census
fi

