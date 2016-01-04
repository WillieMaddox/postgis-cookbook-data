CREATE OR REPLACE FUNCTION voronoi_fast (inputtext text) RETURNS text AS $$
from pyhull.voronoi import VoronoiTess
import ast
inputpoints = ast.literal_eval(inputtext)
dummylist = ast.literal_eval('[999999999]')
v = VoronoiTess(inputpoints)
return v.vertices + dummylist + v.regions
$$ LANGUAGE plpythonu;
