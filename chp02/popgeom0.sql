CREATE OR REPLACE FUNCTION chp02.xyz_pop_geom() RETURNS TRIGGER AS $popgeom$
BEGIN
IF(TG_OP='INSERT') THEN
UPDATE chp02.xwhyzed1
SET geom = ST_SetSRID(ST_MakePoint(x, y), 3734) WHERE geom IS NULL;
END IF;
RETURN NEW;
END;
$popgeom$ LANGUAGE plpgsql;
