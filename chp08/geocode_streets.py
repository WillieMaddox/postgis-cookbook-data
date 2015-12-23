from osmgeocoder import OSMGeocoder
from osgeo import ogr, osr

# here we read the file
f = open('streets.txt')
streets = f.read().splitlines()
f.close()

# here we create the PostGIS layer using gdal/ogr
driver = ogr.GetDriverByName('PostgreSQL')
srs = osr.SpatialReference()
srs.ImportFromEPSG(4326)
pg_ds = ogr.Open(
    "PG:dbname='postgis_cookbook' host='localhost' port='5432' user='me' password='mypassword'",
    update = 1 )
pg_layer = pg_ds.CreateLayer('geocoded_points', srs = srs, geom_type=ogr.wkbPoint,
    options = [
        'GEOMETRY_NAME=the_geom',
        'OVERWRITE=YES', # this will drop and recreate the table every time
        'SCHEMA=chp08',
    ])
# here we add the field to the PostGIS layer
fd_name = ogr.FieldDefn('name', ogr.OFTString)
pg_layer.CreateField(fd_name)
print 'Table created.'

# now we geocode all of the streets in the file using the osmgeocoder class
geocoder = OSMGeocoder('dbname=postgis_cookbook user=me password=mypassword')
for street in streets:
    print street
    geocoded_street = geocoder.geocode(street)[0]
    print geocoded_street
    # format is
    # ('Via delle Sette Chiese', 0.0, 'POINT(12.5002166330412 41.859774874774)')
    point_wkt = geocoded_street[2]
    point = ogr.CreateGeometryFromWkt(point_wkt)
    # we create a LayerDefn for the feature using the one from the layer
    featureDefn = pg_layer.GetLayerDefn()
    feature = ogr.Feature(featureDefn)
    # now we store the feature geometry and the value for the name field
    feature.SetGeometry(point)
    feature.SetField('name', geocoded_street[0])
    # finally we create the feature (an INSERT command is issued only here)
    pg_layer.CreateFeature(feature)
