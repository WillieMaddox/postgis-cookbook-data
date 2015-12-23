"""
Script to load the data for the country model from a shapefile.
"""

from django.contrib.gis.utils import mapping, LayerMapping
from models import Country

country_mapping = {
    'isocode' : 'ISO2',
    'name' : 'NAME',
    'geometry' : 'MULTIPOLYGON',
}

country_shp = '../TM_WORLD_BORDERS-0.3.shp'
country_lm =  LayerMapping(Country, country_shp, country_mapping, 
    transform=False, encoding='iso-8859-1')
country_lm.save(verbose=True, progress=True)


