-- ****************************************************************************
-- ****************************************************************************
--
--
-- CREATE LAYERS FOR MODULE BUILDING
--
--
-- ****************************************************************************
-- ****************************************************************************

--SELECT qgis_pkg.drop_layers(usr_schema:= 'qgis_user', cdb_schema:= 'citydb', feat_type := 'Building'); 
--DELETE FROM qgis_user.layer_metadata WHERE cdb_schema = 'citydb' AND feature_type = 'Building';

----------------------------------------------------------------
-- Create FUNCTION QGIS_PKG.GENERATE_SQL_LAYERS_BUILDING
----------------------------------------------------------------
DROP FUNCTION IF EXISTS    qgis_pkg.generate_sql_layers_building(varchar, varchar, integer, integer, numeric, geometry, boolean) CASCADE;
CREATE OR REPLACE FUNCTION qgis_pkg.generate_sql_layers_building(
cdb_schema 			varchar,
usr_name            varchar,
perform_snapping 	integer  DEFAULT 0,
digits 				integer	 DEFAULT 3,
area_poly_min 		numeric  DEFAULT 0.0001,
mview_bbox			geometry DEFAULT NULL,
force_layer_creation boolean DEFAULT FALSE  -- to be set to FALSE in normal usage
) 
RETURNS text AS $$

DECLARE
usr_schema      varchar := 'qgis_user';
feature_type 	varchar := 'Building';
srid_id         integer; 
num_features    bigint;
trig_f_suffix   varchar;
mview_bbox_srid integer := ST_SRID(mview_bbox);
mview_bbox_xmin numeric;
mview_bbox_ymin numeric;
mview_bbox_xmax numeric;
mview_bbox_ymax numeric;
r 				RECORD;
s 				RECORD;
t 				RECORD;
u 				RECORD;
tr				RECORD;
l_name 			varchar;
view_name 		varchar;
mview_name 		varchar;
mview_idx_name 	varchar;
mview_spx_name 	varchar;

sql_query		text := NULL;
sql_mview_count text := NULL;
sql_where 		text := NULL;
sql_upd			text := NULL;
sql_ins_part	text := NULL;
sql_ins			text := NULL;
sql_trig_part	text := NULL;
sql_trig		text := NULL;
sql_layer_part	text := NULL;
sql_layer	 	text := NULL;
sql_statement	text := NULL;
qml_file_name 	varchar;
citydb_envelope geometry(Polygon);

sql_co_atts varchar := '
  co.id::bigint,
  co.gmlid,
  co.gmlid_codespace,
  co.name,
  co.name_codespace,
  co.description,
  co.creation_date,
  co.termination_date,
  co.relative_to_terrain,
  co.relative_to_water,
  co.last_modification_date,
  co.updating_person,
  co.reason_for_update,
  co.lineage,';

BEGIN
-- Prepare fixed part of SQL statements
sql_upd := format('
DELETE FROM %I.layer_metadata AS l WHERE l.cdb_schema = %L AND l.feature_type = %L;',usr_schema, cdb_schema, feature_type);
sql_upd := concat(sql_upd,'
INSERT INTO ',usr_schema,'.layer_metadata 
(n_features, cdb_schema, feature_type, qml_file, lod, root_class, layer_name, creation_date, mv_name, v_name)
VALUES');


EXECUTE 'SELECT srid FROM citydb.database_srs LIMIT 1' INTO srid_id;

IF mview_bbox_srid IS NULL OR mview_bbox_srid <> srid_id THEN
	mview_bbox := NULL;
	sql_where := NULL;
ELSE
	mview_bbox_xmin := floor(ST_XMin(mview_bbox));
	mview_bbox_ymin := floor(ST_YMin(mview_bbox));
	mview_bbox_xmax := ceil(ST_XMax(mview_bbox));
	mview_bbox_ymax := ceil(ST_YMax(mview_bbox));
	sql_where := concat('AND ST_MakeEnvelope(',mview_bbox_xmin,', ',mview_bbox_ymin,', ',mview_bbox_xmax,', ',mview_bbox_ymax,', ',srid_id,') && co.envelope');
END IF;

RAISE NOTICE 'Creating in schema "%" layers of module "%" for user "%" and cdb_schema "%"', usr_schema, feature_type, usr_name, cdb_schema;

sql_layer_part	:= NULL;
sql_layer	 	:= NULL;
sql_ins_part	:= NULL;
sql_trig_part	:= NULL;
sql_trig		:= NULL;

FOR r IN 
	SELECT * FROM (VALUES
	('Building'::varchar, 26::integer, 'bdg'::varchar),
	('BuildingPart'     , 25         , 'bdg_part')	
	) AS t(class_name, class_id, class_label)
LOOP

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_LOD0
---------------------------------------------------------------
	FOR t IN 
		SELECT * FROM (VALUES
		('LoD0'::varchar, 'lod0'::varchar)		
		) AS t(lodx_name, lodx_label)
	LOOP

-- First check if there are any features at all in the database schema
sql_mview_count := concat('
SELECT 
	count(foo.n_features) AS n_features 
FROM (
	SELECT o.id AS n_features
	FROM 
		',cdb_schema,'.building AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',r.class_id,' ',sql_where,')
	WHERE
		o.',t.lodx_label,'_footprint_id IS NOT NULL OR o.',t.lodx_label,'_roofprint_id IS NOT NULL
) AS foo;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for % %', num_features, r.class_name, t.lodx_name;

l_name         := concat(r.class_label,'_',t.lodx_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat(r.class_label,'_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		sg.cityobject_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM (
		SELECT
			b1.',t.lodx_label,'_footprint_id AS sg_id
		FROM
			',cdb_schema,'.building AS b1
			INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = b1.id AND b1.objectclass_id = ',r.class_id,' ',sql_where,')
		UNION
		SELECT
			b2.',t.lodx_label,'_roofprint_id AS sg_id
		FROM
			',cdb_schema,'.building AS b2
			INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = b2.id AND b2.objectclass_id = ',r.class_id,' ',sql_where,')
		) AS b
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = b.sg_id AND sg.geometry IS NOT NULL)
	GROUP BY sg.cityobject_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of ',r.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.class,
  o.class_codespace,
  string_to_array(o.function, ''--/\--'')::varchar[] AS function,
  string_to_array(o.function_codespace, ''--/\--'')::varchar[] AS function_codespace,  
  string_to_array(o.usage, ''--/\--'')::varchar[] AS usage,
  string_to_array(o.usage_codespace, ''--/\--'')::varchar[] AS usage_codespace, 
  o.year_of_construction,
  o.year_of_demolition,
  o.roof_type,
  o.roof_type_codespace,
  o.measured_height,
  o.measured_height_unit,
  o.storeys_above_ground,
  o.storeys_below_ground,
  o.storey_heights_above_ground,
  o.storey_heights_ag_unit,
  o.storey_heights_below_ground,
  o.storey_heights_bg_unit,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',r.class_id,')
  	INNER JOIN ',cdb_schema,'.building AS o ON (o.id = co.id AND o.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of ',r.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'building';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_LOD0_FOOTPRINT/ROOFEDGE
---------------------------------------------------------------
		FOR u IN 
			SELECT * FROM (VALUES
			('footprint'::varchar, 'footprint'::varchar),
			('roofedge'          , 'roofprint')   
			) AS t(themsurf_name, themsurf_label)
		LOOP

-- First check if there are any features at all in the database schema
sql_mview_count := concat('
SELECT count(o.id) AS n_features
FROM 
	',cdb_schema,'.building AS o
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',r.class_id,' ',sql_where,')
WHERE
	o.',t.lodx_label,'_',u.themsurf_label,'_id IS NOT NULL;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for % % %', num_features, r.class_name, t.lodx_name, u.themsurf_name;

l_name         := concat(r.class_label,'_',t.lodx_label,'_',u.themsurf_name);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat(r.class_label,'_form.qml');


IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		sg.cityobject_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM
		',cdb_schema,'.building AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',r.class_id,' ',sql_where,') 
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = o.',t.lodx_label,'_',u.themsurf_label,'_id AND sg.geometry IS NOT NULL)
	GROUP BY sg.cityobject_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',t.lodx_name,' ',u.themsurf_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.class,
  o.class_codespace,
  string_to_array(o.function, ''--/\--'')::varchar[] AS function,
  string_to_array(o.function_codespace, ''--/\--'')::varchar[] AS function_codespace,  
  string_to_array(o.usage, ''--/\--'')::varchar[] AS usage,
  string_to_array(o.usage_codespace, ''--/\--'')::varchar[] AS usage_codespace, 
  o.year_of_construction,
  o.year_of_demolition,
  o.roof_type,
  o.roof_type_codespace,
  o.measured_height,
  o.measured_height_unit,
  o.storeys_above_ground,
  o.storeys_below_ground,
  o.storey_heights_above_ground,
  o.storey_heights_ag_unit,
  o.storey_heights_below_ground,
  o.storey_heights_bg_unit,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',r.class_id,')
  	INNER JOIN ',cdb_schema,'.building AS o ON (o.id = co.id AND o.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of ',r.class_name,' ',t.lodx_name,' ',u.themsurf_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'building';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

			END LOOP; -- end loop building lod0 footprint/roofprint
	END LOOP; -- building lod0

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_LOD1
---------------------------------------------------------------
	FOR t IN 
		SELECT * FROM (VALUES
		('LoD1'::varchar, 'lod1'::varchar)		
		) AS t(lodx_name, lodx_label)
	LOOP
	
-- First check if there are any features at all in the database schema
sql_mview_count := concat('
SELECT count(o.id) AS n_features
FROM 
	',cdb_schema,'.building AS o
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',r.class_id,' ',sql_where,')
WHERE
	o.',t.lodx_label,'_multi_surface_id IS NOT NULL OR o.',t.lodx_label,'_solid_id IS NOT NULL
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for % %', num_features, r.class_name, t.lodx_name;

l_name         := concat(r.class_label,'_',t.lodx_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat(r.class_label,'_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		sg.cityobject_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM (
		SELECT
			o.id AS co_id, 	
			CASE
				WHEN o.',t.lodx_label,'_solid_id IS NOT NULL THEN o.lod1_solid_id
				ELSE o.',t.lodx_label,'_multi_surface_id
			END	AS sg_id 
		FROM 
			',cdb_schema,'.building AS o
			INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id=co.id AND o.objectclass_id = ',r.class_id,' ',sql_where,') 
		WHERE			
			o.',t.lodx_label,'_solid_id IS NOT NULL OR o.',t.lodx_label,'_multi_surface_id IS NOT NULL
		) AS foo
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = foo.sg_id AND sg.geometry IS NOT NULL)
	GROUP BY sg.cityobject_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of ',r.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.class,
  o.class_codespace,
  string_to_array(o.function, ''--/\--'')::varchar[] AS function,
  string_to_array(o.function_codespace, ''--/\--'')::varchar[] AS function_codespace,  
  string_to_array(o.usage, ''--/\--'')::varchar[] AS usage,
  string_to_array(o.usage_codespace, ''--/\--'')::varchar[] AS usage_codespace, 
  o.year_of_construction,
  o.year_of_demolition,
  o.roof_type,
  o.roof_type_codespace,
  o.measured_height,
  o.measured_height_unit,
  o.storeys_above_ground,
  o.storeys_below_ground,
  o.storey_heights_above_ground,
  o.storey_heights_ag_unit,
  o.storey_heights_below_ground,
  o.storey_heights_bg_unit,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',r.class_id,')
  	INNER JOIN ',cdb_schema,'.building AS o ON (o.id = co.id AND o.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',t.lodx_name,' ',u.themsurf_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'building';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

	END LOOP; -- building lod1

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_LOD2-4
---------------------------------------------------------------
	FOR t IN 
		SELECT * FROM (VALUES
		('LoD2'::varchar, 'lod2'::varchar),
		('LoD3'			, 'lod3'),
		('LoD4'			, 'lod4')		
		) AS t(lodx_name, lodx_label)
	LOOP

-- First check if there are any features at all in the database schema
sql_mview_count := concat('
SELECT 
	count(foo.n_features) AS n_features 
FROM (
	SELECT o.id AS n_features
	FROM 
		',cdb_schema,'.building AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',r.class_id,' ',sql_where,')
	WHERE
		o.',t.lodx_label,'_multi_surface_id IS NOT NULL OR o.',t.lodx_label,'_solid_id IS NOT NULL
	UNION
	SELECT DISTINCT o.building_id AS n_features
	FROM 
		',cdb_schema,'.thematic_surface AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id ',sql_where,')
		INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')
	WHERE
		o.',t.lodx_label,'_multi_surface_id IS NOT NULL
) AS foo;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for % %', num_features, r.class_name, t.lodx_name;

l_name         := concat(r.class_label,'_',t.lodx_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat(r.class_label,'_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		foo2.co_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM (
		SELECT
			foo.co_id,
			unnest(foo.sg_id_array) AS sg_id
		FROM (
			SELECT
				coalesce(o.id, ts_t.co_id) as co_id,
				--o.id AS co_id,
				CASE 
					WHEN ts_t.sg_id_array IS NOT NULL THEN ts_t.sg_id_array
					WHEN o.',t.lodx_label,'_solid_id IS NOT NULL THEN ARRAY[o.',t.lodx_label,'_solid_id]
					ELSE ARRAY[o.',t.lodx_label,'_multi_surface_id]
				END AS sg_id_array 
			FROM 
				',cdb_schema,'.building AS o
				INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id= ',r.class_id,' ',sql_where,')
				FULL OUTER JOIN (
				--INNER JOIN (
					SELECT ts.building_id AS co_id, array_agg(ts.',t.lodx_label,'_multi_surface_id) AS sg_id_array 
					FROM 
						',cdb_schema,'.thematic_surface AS ts
						INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = ts.id ',sql_where,')
						INNER JOIN ',cdb_schema,'.building AS b1 ON (ts.building_id = b1.id AND b1.objectclass_id = ',r.class_id,')	
					GROUP BY ts.building_id
					) AS ts_t ON (ts_t.co_id = o.id)
			WHERE 
				sg_id_array IS NOT NULL
			) AS foo
		) AS foo2
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = foo2.sg_id AND sg.geometry IS NOT NULL)
	GROUP BY foo2.co_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of ',r.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.class,
  o.class_codespace,
  string_to_array(o.function, ''--/\--'')::varchar[] AS function,
  string_to_array(o.function_codespace, ''--/\--'')::varchar[] AS function_codespace,  
  string_to_array(o.usage, ''--/\--'')::varchar[] AS usage,
  string_to_array(o.usage_codespace, ''--/\--'')::varchar[] AS usage_codespace, 
  o.year_of_construction,
  o.year_of_demolition,
  o.roof_type,
  o.roof_type_codespace,
  o.measured_height,
  o.measured_height_unit,
  o.storeys_above_ground,
  o.storeys_below_ground,
  o.storey_heights_above_ground,
  o.storey_heights_ag_unit,
  o.storey_heights_below_ground,
  o.storey_heights_bg_unit,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',r.class_id,')
  	INNER JOIN ',cdb_schema,'.building AS o ON (o.id = co.id AND o.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of ',r.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'building';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_LOD2-4_THEMATIC SURFACES
---------------------------------------------------------------
		FOR u IN 
			SELECT * FROM (VALUES
			('BuildingRoofSurface'::varchar , 33::integer, 'roofsurf'::varchar),
			('BuildingWallSurface'			, 34		 , 'wallsurf'),
			('BuildingGroundSurface'		, 35		 , 'groundsurf'),
			('BuildingClosureSurface'		, 36		 , 'closuresurf'),
			('OuterBuildingCeilingSurface'	, 60		 , 'outerceilingsurf'),
			('OuterBuildingFloorSurface'	, 61		 , 'outerfloorsurf')
			) AS t(class_name, class_id, class_label)
		LOOP

-- First check if there are any features at all in the database schema
sql_mview_count := concat('
SELECT count(o.id) AS n_features
FROM 
	',cdb_schema,'.thematic_surface AS o
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',u.class_id,' ',sql_where,')
	INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')
WHERE
	o.',t.lodx_label,'_multi_surface_id IS NOT NULL;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for % % %', num_features, r.class_name, t.lodx_name, u.class_name;

l_name         := concat(r.class_label,'_',t.lodx_label,'_',u.class_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_thematic_surface_form.qml');


IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		sg.cityobject_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM
		',cdb_schema,'.thematic_surface AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',u.class_id,' ',sql_where,')		
		INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = o.',t.lodx_name,'_multi_surface_id AND sg.geometry IS NOT NULL)
	GROUP BY sg.cityobject_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',t.lodx_name,' ',u.class_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.building_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',u.class_id,')
  	INNER JOIN ',cdb_schema,'.thematic_surface AS o ON (o.id = co.id AND o.objectclass_id = ',u.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',t.lodx_name,' ',u.class_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'thematic_surface';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

		END LOOP; -- building lod2-4 thematic surfaces
	END LOOP; -- building lod2-4

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_LOD2-4_BUILDING INSTALLATION
---------------------------------------------------------------
	FOR s IN 
		SELECT * FROM (VALUES
		('BuildingInstallation'::varchar, 27::integer, 'out_inst'::varchar)
		) AS t(class_name, class_id, class_label)
	LOOP
		FOR t IN 
			SELECT * FROM (VALUES
			('LoD2'::varchar, 'lod2'::varchar),
			('LoD3'			, 'lod3'),
			('LoD4'			, 'lod4')		
			) AS t(lodx_name, lodx_label)
		LOOP

sql_mview_count := concat('
SELECT 
	count(foo.n_features) AS n_features 
FROM (
	SELECT 
		o.id AS n_features
	FROM 
		',cdb_schema,'.building_installation AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,')
	WHERE
		o.',t.lodx_label,'_brep_id IS NOT NULL OR o.',t.lodx_label,'_implicit_rep_id IS NOT NULL
	UNION
	SELECT DISTINCT 
		o.building_installation_id AS n_features
	FROM 
		',cdb_schema,'.thematic_surface AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id ',sql_where,')
		INNER JOIN ',cdb_schema,'.building_installation AS bi ON (bi.id = o.building_installation_id AND bi.objectclass_id = ',s.class_id,')		
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = bi.building_id AND b.objectclass_id = ',r.class_id,')
	WHERE
		o.',t.lodx_label,'_multi_surface_id IS NOT NULL
) AS foo;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for (%) % %', num_features, r.class_name, s.class_name, t.lodx_name;

l_name         := concat(r.class_label,'_',s.class_label,'_',t.lodx_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_out_installation_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT 
		foo2.co_id AS co_id,
		st_collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM ( 
			SELECT 
				foo.co_id,
				unnest(foo.sg_id_array) AS sg_id
			FROM ( 
					SELECT
						coalesce(o.id, ts_t.co_id) as co_id,
--						o.id AS co_id,
						CASE
							WHEN ts_t.sg_id_array IS NOT NULL THEN ts_t.sg_id_array
							ELSE ARRAY[o.',t.lodx_label,'_brep_id]
						END AS sg_id_array
					FROM 
						',cdb_schema,'.building_installation AS o
						INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
						INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')						
						FULL OUTER JOIN (
							SELECT
								o.building_installation_id AS co_id,
								array_agg(o.',t.lodx_label,'_multi_surface_id) AS sg_id_array
							FROM 
								',cdb_schema,'.thematic_surface AS o
								INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = o.id ',sql_where,')
								INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')
							WHERE 
								o.building_installation_id IS NOT NULL
							GROUP BY o.building_installation_id
						) AS ts_t ON (ts_t.co_id = o.id)
					WHERE
						o.',t.lodx_label,'_implicit_rep_id IS NULL
				) AS foo
	   ) AS foo2
	INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = foo2.sg_id AND sg.geometry IS NOT NULL)
	GROUP BY foo2.co_id
	UNION');
-- the need to split is due to max 100 arguments allowed in the concat function.
sql_layer_part := concat(sql_layer_part,'	
	SELECT
		o.id::bigint AS co_id,
		ST_SetSRID(
			ST_Translate(
				ST_Affine(ST_Collect(sg.implicit_geometry),
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 1)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 2)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 3)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 5)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 6)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 7)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 9)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 10)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 11)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 4)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 8)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 12)::double precision
					),
			   ST_X(o.',t.lodx_label,'_implicit_ref_point)::double precision,
			   ST_Y(o.',t.lodx_label,'_implicit_ref_point)::double precision,
			   ST_Z(o.',t.lodx_label,'_implicit_ref_point)::double precision
			),
			',srid_id,')::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM 
		',cdb_schema,'.building_installation AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,')
		INNER JOIN ',cdb_schema,'.implicit_geometry AS ig ON (ig.id = o.',t.lodx_label,'_implicit_rep_id)
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = ig.relative_brep_id AND sg.implicit_geometry IS NOT NULL)
	WHERE
		o.',t.lodx_label,'_implicit_rep_id IS NOT NULL
	GROUP BY o.id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.class,
  o.class_codespace,
  string_to_array(o.function, ''--/\--'')::varchar[] AS function,
  string_to_array(o.function_codespace, ''--/\--'')::varchar[] AS function_codespace,  
  string_to_array(o.usage, ''--/\--'')::varchar[] AS usage,
  string_to_array(o.usage_codespace, ''--/\--'')::varchar[] AS usage_codespace,
  o.building_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',s.class_id,')
  	INNER JOIN ',cdb_schema,'.building_installation AS o ON (o.id = co.id AND o.objectclass_id = ',s.class_id,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'building_installation';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_LOD2-4_BUILDING INSTALLATION_THEMATIC_SURFACe
---------------------------------------------------------------
			FOR u IN 
				SELECT * FROM (VALUES
				('BuildingRoofSurface'::varchar , 33::integer, 'roofsurf'::varchar),
				('BuildingWallSurface'			, 34		 , 'wallsurf'),
				('BuildingGroundSurface'		, 35		 , 'groundsurf'),
				('BuildingClosureSurface'		, 36		 , 'closuresurf'),
				('OuterBuildingCeilingSurface'	, 60		 , 'outerceilingsurf'),
				('OuterBuildingFloorSurface'	, 61		 , 'outerfloorsurf')
				) AS t(class_name, class_id, class_label)
			LOOP

sql_mview_count := concat('
SELECT 
	count(o.id) AS n_features
FROM 
	',cdb_schema,'.thematic_surface AS o
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',u.class_id,' ',sql_where,')
	INNER JOIN ',cdb_schema,'.building_installation AS bi ON (bi.id = o.building_installation_id AND bi.objectclass_id = ',s.class_id,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,')
WHERE
	o.',t.lodx_label,'_multi_surface_id IS NOT NULL;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for (%) % % %', num_features, r.class_name, s.class_name, t.lodx_name, u.class_name;

l_name         := concat(r.class_label,'_',s.class_label,'_',t.lodx_label,'_',u.class_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_out_installation_thematic_surface_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		sg.cityobject_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ,',srid_id,') AS geom
	FROM
		',cdb_schema,'.thematic_surface AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',u.class_id,' ',sql_where,') 
		INNER JOIN ',cdb_schema,'.building_installation AS bi ON (o.building_installation_id = bi.id AND bi.objectclass_id = ',s.class_id,')
		INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')		
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = o.',t.lodx_name,'_multi_surface_id  AND sg.geometry IS NOT NULL)
	GROUP BY sg.cityobject_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' ',u.class_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.building_installation_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',u.class_id,')
	INNER JOIN ',cdb_schema,'.thematic_surface AS o ON (o.id = co.id AND o.objectclass_id = ',u.class_id,')
  	INNER JOIN ',cdb_schema,'.building_installation AS bi ON (bi.id = o.building_installation_id AND bi.objectclass_id = ',s.class_id,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = bi.building_id AND b.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' ',u.class_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'thematic_surface';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

			END LOOP; -- end loop outer building installation thematic surfaces lod 2-4

		END LOOP; -- building installation lod2-4

	END LOOP; -- building installation

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_OPENING_LOD3-4
---------------------------------------------------------------
	FOR s IN 
		SELECT * FROM (VALUES
		('BuildingWindow'::varchar, 38::integer, 'window'::varchar),
		('BuildingDoor'           , 39         , 'door')		
		) AS t(class_name, class_id, class_label)
	LOOP
		FOR t IN 
			SELECT * FROM (VALUES
			('LoD3'::varchar, 'lod3'::varchar),
			('LoD4'			, 'lod4')		
			) AS t(lodx_name, lodx_label)
		LOOP

sql_mview_count := concat('
	SELECT 
		count(o.id) AS n_features
	FROM 
		',cdb_schema,'.opening AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
		INNER JOIN ',cdb_schema,'.opening_to_them_surface AS ots ON (ots.opening_id = o.id)
		INNER JOIN ',cdb_schema,'.thematic_surface AS ts ON (ts.id = ots.thematic_surface_id)
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = ts.building_id AND b.objectclass_id = ',r.class_id,')
	WHERE
		o.',t.lodx_label,'_multi_surface_id IS NOT NULL OR o.',t.lodx_label,'_implicit_rep_id IS NOT NULL;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for (%) % %', num_features, r.class_name, s.class_name, t.lodx_name;

l_name         := concat(r.class_label,'_',s.class_label,'_',t.lodx_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_opening_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		sg.cityobject_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ,',srid_id,') AS geom
	FROM
		',cdb_schema,'.opening AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
		INNER JOIN ',cdb_schema,'.opening_to_them_surface AS ots ON (ots.opening_id = o.id)
		INNER JOIN ',cdb_schema,'.thematic_surface AS ts ON (ts.id = ots.thematic_surface_id)
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = ts.building_id AND b.objectclass_id = ',r.class_id,')
		INNER JOIN ',cdb_schema,'.surface_geometry sg ON sg.root_id = o.',t.lodx_name,'_multi_surface_id  AND sg.geometry IS NOT NULL
	WHERE
		o.',t.lodx_name,'_implicit_rep_id IS NULL
	GROUP BY sg.cityobject_id
	UNION');
-- the need to split is due to max 100 arguments allowed in the concat function.
sql_layer_part := concat(sql_layer_part,'
	SELECT
		o.id::bigint AS co_id,
		ST_SetSRID(
			ST_Translate(
				ST_Affine(ST_Collect(sg.implicit_geometry),
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 1)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 2)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 3)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 5)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 6)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 7)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 9)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 10)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 11)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 4)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 8)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 12)::double precision
					),
			   ST_X(o.',t.lodx_label,'_implicit_ref_point)::double precision,
			   ST_Y(o.',t.lodx_label,'_implicit_ref_point)::double precision,
			   ST_Z(o.',t.lodx_label,'_implicit_ref_point)::double precision
			),
			',srid_id,')::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM 
		',cdb_schema,'.opening AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')		
		INNER JOIN ',cdb_schema,'.opening_to_them_surface AS ots ON (ots.opening_id = o.id)
		INNER JOIN ',cdb_schema,'.thematic_surface AS ts ON (ts.id = ots.thematic_surface_id)
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = ts.building_id AND b.objectclass_id = ',r.class_id,')	
		INNER JOIN ',cdb_schema,'.implicit_geometry AS ig ON (ig.id = o.',t.lodx_name,'_implicit_rep_id) 
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = ig.relative_brep_id AND sg.implicit_geometry IS NOT NULL)
	WHERE
		o.',t.lodx_name,'_implicit_rep_id IS NOT NULL
	GROUP BY o.id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  ots.thematic_surface_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',s.class_id,')
  	INNER JOIN ',cdb_schema,'.opening_to_them_surface AS ots ON (ots.opening_id = co.id)
--	INNER JOIN ',cdb_schema,'.opening AS o ON (o.id = co.id AND o.objectclass_id = ',s.class_id,')
-- 	INNER JOIN ',cdb_schema,'.opening_to_them_surface AS ots ON (ots.opening_id = o.id)
	INNER JOIN ',cdb_schema,'.thematic_surface AS ts ON (ts.id = ots.thematic_surface_id)
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = ts.building_id AND b.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'opening';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

		END LOOP; -- opening lod3-4

	END LOOP; -- opening

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_ROOM_LOD4
---------------------------------------------------------------
	FOR s IN 
		SELECT * FROM (VALUES
		('Room'::varchar, 41::integer, 'room'::varchar)	
		) AS t(class_name, class_id, class_label)
	LOOP
		FOR t IN 
			SELECT * FROM (VALUES
			('LoD4'::varchar, 'lod4'::varchar)
			) AS t(lodx_name, lodx_label)
		LOOP

sql_mview_count := concat('
SELECT 
	count(o.id) AS n_features
FROM 
	',cdb_schema,'.room AS o
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,')
WHERE
	o.',t.lodx_label,'_multi_surface_id IS NOT NULL OR o.',t.lodx_label,'_solid_id IS NOT NULL;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for (%) % %', num_features, r.class_name, s.class_name, t.lodx_name;

l_name         := concat(r.class_label,'_',s.class_label,'_',t.lodx_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_room_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		foo2.co_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom	
	FROM (
		SELECT
			foo.co_id,
			unnest(foo.sg_id_array) AS sg_id
		FROM (
			SELECT
				coalesce(o.id, ts_t.co_id) as co_id,
				--o.id AS co_id,
				CASE 
					WHEN ts_t.sg_id_array IS NOT NULL THEN ts_t.sg_id_array
					WHEN o.',t.lodx_label,'_solid_id IS NOT NULL THEN ARRAY[o.',t.lodx_label,'_solid_id]
					ELSE ARRAY[o.',t.lodx_label,'_multi_surface_id]
				END AS sg_id_array 
			FROM 
				',cdb_schema,'.room AS o
				INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
				INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,')
				FULL OUTER JOIN (
				--INNER JOIN (
					SELECT ts.room_id AS co_id, array_agg(ts.',t.lodx_label,'_multi_surface_id) AS sg_id_array 
					FROM 
						',cdb_schema,'.thematic_surface AS ts
						INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = ts.id ',sql_where,')
						INNER JOIN ',cdb_schema,'.room AS r ON (ts.room_id = r.id AND r.objectclass_id = ',s.class_id,' ',sql_where,')
						INNER JOIN ',cdb_schema,'.building AS b1 ON (b1.id = r.building_id AND b1.objectclass_id = ',r.class_id,')						
					GROUP BY ts.room_id
					) AS ts_t ON (ts_t.co_id = o.id)
			WHERE 
				sg_id_array IS NOT NULL
			) AS foo
		) AS foo2
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = foo2.sg_id AND sg.geometry IS NOT NULL)
	GROUP BY foo2.co_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.class,
  o.class_codespace,
  string_to_array(o.function, ''--/\--'')::varchar[] AS function,
  string_to_array(o.function_codespace, ''--/\--'')::varchar[] AS function_codespace,  
  string_to_array(o.usage, ''--/\--'')::varchar[] AS usage,
  string_to_array(o.usage_codespace, ''--/\--'')::varchar[] AS usage_codespace,
  o.building_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',s.class_id,')
  	INNER JOIN ',cdb_schema,'.room AS o ON (o.id = co.id AND o.objectclass_id = ',s.class_id,')	
  	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'room';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_ROOM_LOD4_THEMATIC_SURFACES
---------------------------------------------------------------
			FOR u IN 
				SELECT * FROM (VALUES
				('BuildingCeilingSurface'::varchar	, 30::integer	, 'ceilingsurf'::varchar),
				('InteriorBuildingWallSurface'		, 31		 	, 'intwallsurf'),
				('BuildingFloorSurface'				, 32		    , 'floorsurf')
				) AS t(class_name, class_id, class_label)
			LOOP

sql_mview_count := concat('
SELECT
	count(o.id) AS n_features
FROM 
	',cdb_schema,'.thematic_surface AS o
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = o.id AND o.objectclass_id = ',u.class_id,' ',sql_where,')
	INNER JOIN ',cdb_schema,'.room AS r ON (r.id = o.room_id AND r.objectclass_id = ',s.class_id,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = r.building_id AND b.objectclass_id = ',r.class_id,')
WHERE
	o.',t.lodx_label,'_multi_surface_id IS NOT NULL;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for (%) % % %', num_features, r.class_name, s.class_name, t.lodx_name, u.class_label;

l_name         := concat(r.class_label,'_',s.class_label,'_',t.lodx_label,'_',u.class_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_room_thematic_surface_form.qml');


IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		sg.cityobject_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM
		',cdb_schema,'.thematic_surface AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',u.class_id,' ',sql_where,') 
		INNER JOIN ',cdb_schema,'.room AS r ON (r.id = o.room_id AND r.objectclass_id = ',s.class_id,')
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = r.building_id AND b.objectclass_id = ',r.class_id,')		
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = o.',t.lodx_name,'_multi_surface_id  AND sg.geometry IS NOT NULL)
	GROUP BY sg.cityobject_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' ',u.class_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.room_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',u.class_id,')
  	INNER JOIN ',cdb_schema,'.thematic_surface AS o ON (o.id = co.id AND o.objectclass_id = ',u.class_id,')
	INNER JOIN ',cdb_schema,'.room AS r ON (r.id = o.room_id AND r.objectclass_id = ',s.class_id,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = r.building_id AND b.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' ',u.class_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'building';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

			END LOOP; -- room lod4 thematic surfaces
		END LOOP; -- room lod4
	END LOOP; -- room

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_INT_BUILDING_INSTALLATION_LOD4
---------------------------------------------------------------
	FOR s IN 
		SELECT * FROM (VALUES
		('IntBuildingInstallation'::varchar, 28::integer, 'int_inst'::varchar)
		) AS t(class_name, class_id, class_label)
	LOOP
		FOR t IN 
			SELECT * FROM (VALUES
			('LoD4'::varchar, 'lod4'::varchar)
			) AS t(lodx_name, lodx_label)
		LOOP

sql_mview_count := concat('
SELECT 
	count(foo.n_features) AS n_features 
FROM (
	SELECT 
		o.id AS n_features
	FROM 
		',cdb_schema,'.building_installation AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,')
	WHERE
		o.',t.lodx_label,'_brep_id IS NOT NULL OR o.',t.lodx_label,'_implicit_rep_id IS NOT NULL
	UNION
	SELECT DISTINCT 
		o.building_installation_id AS n_features
	FROM 
		',cdb_schema,'.thematic_surface AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id ',sql_where,')
		INNER JOIN ',cdb_schema,'.building_installation AS bi ON (bi.id = o.building_installation_id AND bi.objectclass_id = ',s.class_id,')		
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = bi.building_id AND b.objectclass_id = ',r.class_id,')
	WHERE
		o.',t.lodx_label,'_multi_surface_id IS NOT NULL
) AS foo;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for (%) % %', num_features, r.class_name, s.class_name, t.lodx_name;

l_name         := concat(r.class_label,'_',s.class_label,'_',t.lodx_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_int_installation_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT 
		foo2.co_id AS co_id,
		st_collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM ( 
			SELECT 
				foo.co_id,
				unnest(foo.sg_id_array) AS sg_id
			FROM ( 
					SELECT
						coalesce(o.id, ts_t.co_id) as co_id,
--						o.id AS co_id,
						CASE
							WHEN ts_t.sg_id_array IS NOT NULL THEN ts_t.sg_id_array
							ELSE ARRAY[o.',t.lodx_label,'_brep_id]
						END AS sg_id_array
					FROM 
						',cdb_schema,'.building_installation AS o
						INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
						INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')						
						FULL OUTER JOIN (
							SELECT
								o.building_installation_id AS co_id,
								array_agg(o.',t.lodx_label,'_multi_surface_id) AS sg_id_array
							FROM 
								',cdb_schema,'.thematic_surface AS o
								INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = o.id ',sql_where,')
								INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')
							WHERE 
								o.building_installation_id IS NOT NULL
							GROUP BY o.building_installation_id
						) AS ts_t ON (ts_t.co_id = o.id)
					WHERE
						o.',t.lodx_label,'_implicit_rep_id IS NULL
				) AS foo
	   ) AS foo2
	INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = foo2.sg_id AND sg.geometry IS NOT NULL)
	GROUP BY foo2.co_id
	UNION');
-- the need to split is due to max 100 arguments allowed in the concat function.
sql_layer_part := concat(sql_layer_part,'	
	SELECT
		o.id::bigint AS co_id,
		ST_SetSRID(
			ST_Translate(
				ST_Affine(ST_Collect(sg.implicit_geometry),
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 1)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 2)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 3)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 5)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 6)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 7)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 9)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 10)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 11)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 4)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 8)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 12)::double precision
					),
			   ST_X(o.',t.lodx_label,'_implicit_ref_point)::double precision,
			   ST_Y(o.',t.lodx_label,'_implicit_ref_point)::double precision,
			   ST_Z(o.',t.lodx_label,'_implicit_ref_point)::double precision
			),
			',srid_id,')::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM 
		',cdb_schema,'.building_installation AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,')
		INNER JOIN ',cdb_schema,'.implicit_geometry AS ig ON (ig.id = o.',t.lodx_label,'_implicit_rep_id)
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = ig.relative_brep_id AND sg.implicit_geometry IS NOT NULL)
	WHERE
		o.',t.lodx_label,'_implicit_rep_id IS NOT NULL
	GROUP BY o.id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.class,
  o.class_codespace,
  string_to_array(o.function, ''--/\--'')::varchar[] AS function,
  string_to_array(o.function_codespace, ''--/\--'')::varchar[] AS function_codespace,  
  string_to_array(o.usage, ''--/\--'')::varchar[] AS usage,
  string_to_array(o.usage_codespace, ''--/\--'')::varchar[] AS usage_codespace,
  o.building_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',s.class_id,')
  	INNER JOIN ',cdb_schema,'.building_installation AS o ON (o.id = co.id AND o.objectclass_id = ',s.class_id,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'building_installation';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_INT_BUILDING_INSTALLATION_LOD4_THEMATIC_SURFACES
---------------------------------------------------------------
			FOR u IN 
				SELECT * FROM (VALUES
				('BuildingCeilingSurface'::varchar	, 30::integer	, 'ceilingsurf'::varchar),
				('InteriorBuildingWallSurface'		, 31		 	, 'intwallsurf'),
				('BuildingFloorSurface'				, 32		    , 'floorsurf'),
				('BuildingRoofSurface'				, 33			, 'roofsurf'),
				('BuildingWallSurface'				, 34		 	, 'wallsurf'),
				('BuildingGroundSurface'			, 35		 	, 'groundsurf'),
				('BuildingClosureSurface'			, 36		 	, 'closuresurf'),
				('OuterBuildingCeilingSurface'		, 60		 	, 'outerceilingsurf'),
				('OuterBuildingFloorSurface'		, 61		 	, 'outerfloorsurf')				
				) AS t(class_name, class_id, class_label)
			LOOP

sql_mview_count := concat('
SELECT 
	count(o.id) AS n_features
FROM 
	',cdb_schema,'.thematic_surface AS o
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',u.class_id,' ',sql_where,')
	INNER JOIN ',cdb_schema,'.building_installation AS bi ON (bi.id = o.building_installation_id AND bi.objectclass_id = ',s.class_id,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = o.building_id AND b.objectclass_id = ',r.class_id,')
WHERE
	o.',t.lodx_label,'_multi_surface_id IS NOT NULL;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for (%) % % %', num_features, r.class_name, s.class_name, t.lodx_name, u.class_name;

l_name         := concat(r.class_label,'_',s.class_label,'_',t.lodx_label,'_',u.class_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_int_inst_thematic_surface_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT
		sg.cityobject_id::bigint AS co_id,
		ST_Collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ,',srid_id,') AS geom
	FROM
		',cdb_schema,'.thematic_surface AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',u.class_id,' ',sql_where,') 
		INNER JOIN ',cdb_schema,'.building_installation AS bi ON (o.building_installation_id = bi.id AND bi.objectclass_id = ',s.class_id,')
		INNER JOIN ',cdb_schema,'.building AS b ON (o.building_id = b.id AND b.objectclass_id = ',r.class_id,')		
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = o.',t.lodx_name,'_multi_surface_id  AND sg.geometry IS NOT NULL)
	GROUP BY sg.cityobject_id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' ',u.class_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.building_installation_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',u.class_id,')
	INNER JOIN ',cdb_schema,'.thematic_surface AS o ON (o.id = co.id AND o.objectclass_id = ',u.class_id,')
  	INNER JOIN ',cdb_schema,'.building_installation AS bi ON (bi.id = o.building_installation_id AND bi.objectclass_id = ',s.class_id,')
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = bi.building_id AND b.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' ',u.class_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'thematic_surface';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

			END LOOP; -- int building installation lod4 thematic surfaces
		END LOOP; -- int building installation lod4
	END LOOP; -- int building installation

---------------------------------------------------------------
-- Create LAYER BUILDING(PART)_BUILDING_FURNITURE_LOD4
---------------------------------------------------------------
	FOR s IN 
		SELECT * FROM (VALUES
		('BuildingFurniture'::varchar, 40::integer, 'furniture'::varchar)	
		) AS t(class_name, class_id, class_label)
	LOOP
		FOR t IN 
			SELECT * FROM (VALUES
			('LoD4'::varchar, 'lod4'::varchar)
			) AS t(lodx_name, lodx_label)
		LOOP

sql_mview_count := concat('
SELECT 
	count(o.id) AS n_features
FROM 
	',cdb_schema,'.building_furniture AS o
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (o.id = co.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
	INNER JOIN ',cdb_schema,'.room AS r ON (r.id = o.room_id)
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = r.building_id AND b.objectclass_id = ',r.class_id,')
WHERE
	o.',t.lodx_label,'_brep_id IS NOT NULL OR o.',t.lodx_label,'_implicit_rep_id IS NOT NULL;
');
EXECUTE sql_mview_count INTO num_features;

RAISE NOTICE 'Found % features for (%) % %', num_features, r.class_name, s.class_name, t.lodx_name;

l_name         := concat(r.class_label,'_',s.class_label,'_',t.lodx_label);
view_name      := concat(cdb_schema,'_',l_name);
mview_name     := concat('_g_',view_name);
mview_idx_name := concat(mview_name,'_id_idx');
mview_spx_name := concat(mview_name,'_geom_spx');
qml_file_name  := concat('bdg_furniture_form.qml');

IF (num_features > 0) OR (force_layer_creation IS TRUE) THEN

--------------------
-- MATERIALIZED VIEW
--------------------
sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
CREATE MATERIALIZED VIEW         ',usr_schema,'.',mview_name,' AS
	SELECT 
		sg.cityobject_id::bigint AS co_id,
		st_collect(qgis_pkg.ST_snap_poly_to_grid(sg.geometry,',perform_snapping,',',digits,',',area_poly_min,'))::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM
		',cdb_schema,'.building_furniture AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = o.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
		INNER JOIN ',cdb_schema,'.room AS r ON (r.id = o.room_id)
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = r.building_id AND b.objectclass_id = ',r.class_id,')
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = o.',t.lodx_label,'_brep_id AND sg.geometry IS NOT NULL)
	WHERE
		o.',t.lodx_label,'_brep_id IS NOT NULL
	GROUP BY sg.cityobject_id
	UNION');
-- the need to split is due to max 100 arguments allowed in the concat function.
sql_layer_part := concat(sql_layer_part,'	
	SELECT
		o.id::bigint AS co_id,
		ST_SetSRID(
			ST_Translate(
				ST_Affine(ST_Collect(sg.implicit_geometry),
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 1)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 2)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 3)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 5)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 6)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 7)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 9)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 10)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 11)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 4)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 8)::double precision,
					split_part(',t.lodx_label,'_implicit_transformation, '' '', 12)::double precision
					),
			   ST_X(o.',t.lodx_label,'_implicit_ref_point)::double precision,
			   ST_Y(o.',t.lodx_label,'_implicit_ref_point)::double precision,
			   ST_Z(o.',t.lodx_label,'_implicit_ref_point)::double precision
			),
			',srid_id,')::geometry(MultiPolygonZ, ',srid_id,') AS geom
	FROM 
		',cdb_schema,'.building_furniture AS o
		INNER JOIN ',cdb_schema,'.cityobject AS co ON (co.id = o.id AND o.objectclass_id = ',s.class_id,' ',sql_where,')
		INNER JOIN ',cdb_schema,'.room AS r ON (r.id = o.room_id)		
		INNER JOIN ',cdb_schema,'.building AS b ON (b.id = r.building_id AND b.objectclass_id = ',r.class_id,')
		INNER JOIN ',cdb_schema,'.implicit_geometry AS ig ON (ig.id = o.',t.lodx_label,'_implicit_rep_id)
		INNER JOIN ',cdb_schema,'.surface_geometry AS sg ON (sg.root_id = ig.relative_brep_id AND sg.implicit_geometry IS NOT NULL)
	WHERE
		o.',t.lodx_label,'_brep_id IS NULL AND o.',t.lodx_label,'_implicit_rep_id IS NOT NULL
	GROUP BY o.id
WITH NO DATA;
COMMENT ON MATERIALIZED VIEW ',usr_schema,'.',mview_name,' IS ''Mat. view of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
CREATE INDEX ',mview_idx_name,' ON ',usr_schema,'.',mview_name,' (co_id);
CREATE INDEX ',mview_spx_name,' ON ',usr_schema,'.',mview_name,' USING gist (geom);
ALTER TABLE ',usr_schema,'.',mview_name,' OWNER TO ',usr_name,';
--DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
REFRESH MATERIALIZED VIEW ',usr_schema,'.',mview_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

-------
-- VIEW
-------
sql_layer_part := concat('
DROP VIEW IF EXISTS    ',usr_schema,'.',view_name,' CASCADE;
CREATE OR REPLACE VIEW ',usr_schema,'.',view_name,' AS
SELECT',sql_co_atts,'
  o.class,
  o.class_codespace,
  string_to_array(o.function, ''--/\--'')::varchar[] AS function,
  string_to_array(o.function_codespace, ''--/\--'')::varchar[] AS function_codespace,  
  string_to_array(o.usage, ''--/\--'')::varchar[] AS usage,
  string_to_array(o.usage_codespace, ''--/\--'')::varchar[] AS usage_codespace,
  o.room_id,
  r.building_id,
  g.geom::geometry(MultiPolygonZ,',srid_id,')
FROM
	',usr_schema,'.',mview_name,' AS g 
	INNER JOIN ',cdb_schema,'.cityobject AS co ON (g.co_id = co.id AND co.objectclass_id = ',s.class_id,')
  	INNER JOIN ',cdb_schema,'.building_furniture AS o ON (o.id = co.id AND o.objectclass_id = ',s.class_id,')
  	INNER JOIN ',cdb_schema,'.room AS r ON (r.id = o.room_id)	
	INNER JOIN ',cdb_schema,'.building AS b ON (b.id = r.building_id AND b.objectclass_id = ',r.class_id,');
COMMENT ON VIEW ',usr_schema,'.',view_name,' IS ''View of (',r.class_name,') ',s.class_name,' ',t.lodx_name,' in schema ',cdb_schema,''';
ALTER TABLE ',usr_schema,'.',view_name,' OWNER TO ',usr_name,';
');
sql_layer := concat(sql_layer,sql_layer_part);

trig_f_suffix := 'building_furniture';

SELECT qgis_pkg.generate_sql_triggers(
	view_name 			:= view_name,
	tr_function_suffix	:= trig_f_suffix,
	usr_name			:= usr_name, 
	usr_schema			:= usr_schema
) INTO sql_trig_part;
sql_trig := concat(sql_trig,sql_trig_part);

-- ADD ENTRY TO UPDATE TABLE LAYER_METADATA
sql_ins_part := concat('
(',num_features,',''',cdb_schema,''',''',feature_type,''',''',qml_file_name,''',''',t.lodx_label,''',''',r.class_name,''',''',l_name,''',clock_timestamp(),''',mview_name,''',''',view_name,'''),');
sql_ins := concat(sql_ins,sql_ins_part);

ELSE

sql_layer_part := concat('
DROP MATERIALIZED VIEW IF EXISTS ',usr_schema,'.',mview_name,' CASCADE;
DELETE FROM ',usr_schema,'.layer_metadata WHERE v_name = ''',view_name,''';
');
sql_layer := concat(sql_layer,sql_layer_part);

END IF;

		END LOOP; -- building furniture lod4
	END LOOP; -- building furniture
END LOOP;  -- building

-- substitute last comma with semi-colon
IF sql_ins IS NOT NULL THEN
	sql_ins := concat(sql_upd, substr(sql_ins,1, length(sql_ins)-1), ';');
END IF;
-- create the final sql statement
sql_statement := concat(sql_layer, sql_trig, sql_ins);

RETURN sql_statement;
EXCEPTION
	WHEN QUERY_CANCELED THEN
		RAISE EXCEPTION 'qgis_pkg.generate_sql_layers_building(): Error QUERY_CANCELED';
	WHEN OTHERS THEN
		RAISE EXCEPTION 'qgis_pkg.generate_sql_layers_building(): %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION qgis_pkg.generate_sql_layers_building(varchar, varchar, integer, integer, numeric, geometry, boolean) IS 'Create layers for module Building';

----------------------------------------------------------------
-- Create FUNCTION QGIS_PKG.CREATE_LAYERS_BUILDING
----------------------------------------------------------------
DROP FUNCTION IF EXISTS    qgis_pkg.create_layers_building(varchar, varchar, integer, integer, numeric, numeric[], boolean) CASCADE;
CREATE OR REPLACE FUNCTION qgis_pkg.create_layers_building(
cdb_schema 			varchar,
usr_name            varchar,
perform_snapping 	integer  DEFAULT 0,
digits 				integer	 DEFAULT 3,
area_poly_min 		numeric  DEFAULT 0.0001,
bbox_corners_array	numeric[] DEFAULT NULL, -- can be passed as ARRAY[1,2,3,4] or string '{1,2,3,4}'
force_layer_creation boolean DEFAULT FALSE
)
RETURNS integer AS $$
DECLARE
sql_statement 	text := NULL;
mview_bbox 		geometry(Polygon) := NULL;

BEGIN

SELECT qgis_pkg.generate_mview_bbox_poly(
	bbox_corners_array := bbox_corners_array
) INTO mview_bbox;

SELECT qgis_pkg.generate_sql_layers_building(
	cdb_schema 			 := cdb_schema, 			
	usr_name             := usr_name,            
	perform_snapping 	 := perform_snapping, 	
	digits 				 := digits, 				
	area_poly_min 		 := area_poly_min, 		
	mview_bbox			 := mview_bbox,			
	force_layer_creation := force_layer_creation
) INTO sql_statement;

IF sql_statement IS NOT NULL THEN
--	RAISE NOTICE '
--%
--',sql_statement;
	EXECUTE sql_statement;
END IF;

RETURN 1;

EXCEPTION
	WHEN QUERY_CANCELED THEN
		RAISE EXCEPTION 'qgis_pkg.create_layers_building(): Error QUERY_CANCELED';
	WHEN OTHERS THEN
		RAISE EXCEPTION 'qgis_pkg.create_layers_building(): %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION qgis_pkg.create_layers_building
(varchar, varchar, integer, integer, numeric, numeric[], boolean)
 IS 'Create layers for module Building';

SELECT qgis_pkg.create_layers_building(
	cdb_schema         := 'citydb',
	usr_name           := 'postgres',
	bbox_corners_array := NULL,  -- THIS IS THE DEFAULT
--	bbox_corners_array := ARRAY[220000, 481400, 220900, 482300],
--	bbox_corners_array := '{220177, 481471, 220755, 482133}',
	force_layer_creation := FALSE);
--SELECT qgis_pkg.refresh_mview(usr_schema := 'qgis_user', cdb_schema := 'citydb');

--**************************
DO $MAINBODY$
DECLARE
BEGIN
RAISE NOTICE E'\n\nDone\n\n';
END $MAINBODY$;
--**************************