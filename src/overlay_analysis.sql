# Connect to the database, QGIS connection is used

# Create an empty table with the same fields as the csv file

CREATE TABLE public.geocoding_result

(      "OBJECTID" oid,
loc_name character varying,
status character varying,
match_addr character varying,
x double precision,
y double precision,
altpatid double precision,
address character varying,
city character varying,
state character varying,
zip_code character varying   )

WITH (OIDS=FALSE);
ALTER TABLE public.geocoding_result
OWNER TO postgres;

# Import addresses, copy csv file to the table in PostgreSQL

COPY geocoding_result from 'C:\Temp \geocoded_final.csv' DELIMITERS ',' CSV;

# Add Geometry field to the table

ALTER TABLE public.geocoding_result ADD COLUMN geom geometry(Point,4326);

# Update geometry with x,y values

UPDATE public.geocoding_result SET geom = ST_SetSRID(ST_MakePoint(x, y),4326)

#import census block groups from file geodatabase into PostGre

ogr2ogr -overwrite -f "PostgreSQL" PG:"host=localhost user=postgres dbname=postgres password=postgres" "~/Census.gdb" "blkgrp2010"
ogr2ogr -overwrite -f "PostgreSQL" PG:"host=localhost user=postgres dbname=postgres password=postgres" "~/Census.gdb" "blkgrp2000"

# Create (spatial) index (optional as importing will automatically build index) to increase performance

CREATE INDEX geocoding_result_gist
ON geocoding_result
USING GIST (wkb_geometry);

# Intersection for 2010 boundary(Make sure that addresses and block groups are in same coordinate system)

CREATE TABLE geofips AS
SELECT geocoding_result.*,blkgrp2010.fips
FROM geocoding_result,blkgrp2010
WHERE ST_Intersects(geocoding_result.wkb_geometry,blkgrp2010.wkb_geometry);

# Rename new field "fips" to fips 2010

ALTER TABLE geofips RENAME COLUMN fips TO fips2010;

# Intersection for 2000 boundary

CREATE TABLE geofipsall AS
SELECT geofips.*,blkgrp2000.fips
FROM geofips,blkgrp2000
WHERE ST_Intersects(geofips.wkb_geometry,blkgrp2000.wkb_geometry);

# Rename new field "fips" to fips 2000

ALTER TABLE geofipsall RENAME COLUMN fips TO fips2000;

# Add Column fips2010, fips2000 to geocoding_result

ALTER TABLE geocoding_result ADD COLUMN fips2010 varchar(12);
ALTER TABLE geocoding_result ADD COLUMN fips2000 varchar(12);

# Select non-geocoded results

CREATE TABLE Ustatus AS SELECT * FROM geocoding_result WHERE status='U';

# Union two tables together

CREATE TABLE geocoding_final_result AS (SELECT * FROM geofipsall UNION SELECT * FROM ustatus);

# Export result to csv

COPY geocoding_final_result(loc_name,status,x,y,match_addr,altpatid,address,
city,state,zip_code,fips2010,fips2000) TO 'C:\Temp\geocoding_final_result_new.csv' DELIMITER ',' CSV HEADER;

# Export a sample result for reviewing

COPY (SELECT loc_name,status,x,y,match_addr,altpatid,address,city,
state,zip_code,fips2010,fips2000 FROM geocoding_final_result LIMIT 1000) TO 'C:\Temp\geocoding_final_result_1000.csv' DELIMITER ',' CSV HEADER;

# End