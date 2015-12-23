import sys
import psycopg2

class OSMGeocoder(object):
    """
    A class to provide geocoding features using an OSM dataset in PostGIS.
    """

    def __init__(self, db_connectionstring):
        # initialize db connection parameters
        self.db_connectionstring = db_connectionstring

    def geocode(self, placename):
        """
        Geocode a given place name.
        """
        # here we create the connection object
        conn = psycopg2.connect(self.db_connectionstring)
        cur = conn.cursor()
        # this is the core sql query, using trigrams to detect streets similiar
        # to a given placename
        sql = """
            SELECT name, name <-> '%s' AS weight,
            ST_AsText(ST_Centroid(the_geom)) as  point
            FROM chp08.osm_roads
            ORDER BY weight LIMIT 10;
        """ % placename
        # here we execute the sql and return all of the results
        cur.execute(sql)
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return rows
        
if __name__ == '__main__':
    # the user must provide at least two parameters, the place name
    # and the connection string to PostGIS
    if len(sys.argv) < 3 or len(sys.argv) > 3:
        print "usage: <placename> <connection string>"
        raise SystemExit
    placename = sys.argv[1]
    db_connectionstring = sys.argv[2]
    # here we instantiate the geocoder, providing the needed PostGIS connection
    # parameters
    geocoder = OSMGeocoder(db_connectionstring)
    # here we query the geocode method, for getting the geocoded points for the
    # given placename
    results = geocoder.geocode(placename)
    print results
    
