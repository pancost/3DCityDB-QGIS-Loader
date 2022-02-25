-- ****************************************************************************
-- ****************************************************************************
--
--
-- CREATE ENUMERATINS and CODELISTS
--
--
-- ****************************************************************************
-- ****************************************************************************

------------------------------------------------------------------
-- TABLE qgis_pkg.enumeration
------------------------------------------------------------------
DROP TABLE IF EXISTS qgis_pkg.enumeration CASCADE;
CREATE TABLE         qgis_pkg.enumeration (
id 			serial PRIMARY KEY,
data_model	varchar,
name		varchar,
name_space	varchar,
description	text,
CONSTRAINT e_enum_unique UNIQUE (data_model, name, name_space)
);
COMMENT ON TABLE qgis_pkg.enumeration IS 'Contains enumeration metadata';
CREATE INDEX e_data_model_idx  ON qgis_pkg.enumeration (data_model);
CREATE INDEX e_name_idx        ON qgis_pkg.enumeration (name);


------------------------------------------------------------------
-- TABLE qgis_pkg.enumeration_value
------------------------------------------------------------------
DROP TABLE IF EXISTS qgis_pkg.enumeration_value CASCADE;
CREATE TABLE         qgis_pkg.enumeration_value (
id 			serial PRIMARY KEY,
enum_id		integer,
value		varchar,
description	text,
CONSTRAINT ev_value_unique UNIQUE (enum_id, value)
);
COMMENT ON TABLE qgis_pkg.enumeration_value IS 'Contains enumeration values';
CREATE INDEX ev_enum_id_idx  ON qgis_pkg.enumeration_value (enum_id);
CREATE INDEX ev_value_idx    ON qgis_pkg.enumeration_value (value);

------------------------------------------------------------------
-- TABLE qgis_pkg.v_enumeration_values
------------------------------------------------------------------
DROP VIEW IF EXISTS qgis_pkg.v_enumeration_value CASCADE;
CREATE VIEW         qgis_pkg.v_enumeration_value AS
SELECT
	e.data_model,
	e.name,
	ev.value,
	ev.description,
	e.name_space
FROM
	qgis_pkg.enumeration_value AS ev
	INNER JOIN qgis_pkg.enumeration AS e ON (ev.enum_id = e.id);

-- ****************************************************************************
-- ****************************************************************************

------------------------------------------------------------------
-- TABLE qgis_pkg.codelist
------------------------------------------------------------------
DROP TABLE IF EXISTS qgis_pkg.codelist CASCADE;
CREATE TABLE         qgis_pkg.codelist (
id 			serial PRIMARY KEY,
data_model	varchar,
name		varchar,
name_space	varchar,
description	text,
CONSTRAINT cl_unique UNIQUE (data_model, name, name_space)
);
COMMENT ON TABLE qgis_pkg.codelist IS 'Contains codelist metadata';
CREATE INDEX cl_data_model_idx  ON qgis_pkg.codelist (data_model);
CREATE INDEX cl_name_idx        ON qgis_pkg.codelist (name);

------------------------------------------------------------------
-- TABLE qgis_pkg.codelist_value
------------------------------------------------------------------
DROP TABLE IF EXISTS qgis_pkg.codelist_value CASCADE;
CREATE TABLE         qgis_pkg.codelist_value (
id 			serial PRIMARY KEY,
code_id		integer,
value		varchar,
description	text,
CONSTRAINT clv_unique UNIQUE (code_id, value)
);
COMMENT ON TABLE qgis_pkg.codelist_value IS 'Contains codelist values';
CREATE INDEX clv_code_id_idx  ON qgis_pkg.codelist_value (code_id);
CREATE INDEX clv_value_idx    ON qgis_pkg.codelist_value (value);

------------------------------------------------------------------
-- TABLE qgis_pkg.v_codelist_value
------------------------------------------------------------------
DROP VIEW IF EXISTS qgis_pkg.v_codelist_value CASCADE;
CREATE VIEW         qgis_pkg.v_codelist_value AS
SELECT
	c.data_model,
	c.name,
	cv.value,
	cv.description,
	c.name_space
FROM
	qgis_pkg.codelist_value AS cv
	INNER JOIN qgis_pkg.codelist AS c ON (cv.code_id = c.id);

-- ****************************************************************************
-- ****************************************************************************

--TRUNCATE    qgis_pkg.enumeration CASCADE RESTART IDENTITY;
INSERT INTO qgis_pkg.enumeration (data_model, name, name_space)
VALUES
('CityGML 2.0','RelativeToTerrainType','http://schemas.opengis.net/citygml/2.0/cityGMLBase.xsd'),
('CityGML 2.0','RelativeToWaterType'  ,'http://schemas.opengis.net/citygml/2.0/cityGMLBase.xsd'),
('CityGML 2.0','TextureTypeType'      ,'http://schemas.opengis.net/citygml/appearance/2.0/appearance.xsd'),
('CityGML 2.0','WrapModeTypeType'     ,'http://schemas.opengis.net/citygml/appearance/2.0/appearance.xsd')
;

-- ****************************************************************************
-- ****************************************************************************

--TRUNCATE    qgis_pkg.enumeration_value CASCADE RESTART IDENTITY;
WITH em AS (SELECT id FROM qgis_pkg.enumeration	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'RelativeToTerrainType'
) INSERT INTO qgis_pkg.enumeration_value (enum_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES  
('entirelyAboveTerrain'             ,'(City)Object entirely above terrain'               ),
('substantiallyAboveTerrain'        ,'(City)Object substantially above terrain'          ),
('substantiallyAboveAndBelowTerrain','(City)Object substantially above and below terrain'),
('substantiallyBelowTerrain'        ,'(City)Object substantially below terrain'          ),
('entirelyBelowTerrain'             ,'(City)Object entirely below terrain'               )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.enumeration	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'RelativeToWaterType'
) INSERT INTO qgis_pkg.enumeration_value (enum_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES  
('entirelyAboveWaterSurface'             ,'(City)Object entirely above water surface'               ),
('substantiallyAboveWaterSurface'        ,'(City)Object substantially above water surface'          ),
('substantiallyAboveAndBelowWaterSurface','(City)Object substantially above and below water surface'),
('substantiallyBelowWaterSurface'        ,'(City)Object substantially below water surface'          ),
('entirelyBelowWaterSurface'             ,'(City)Object entirely below water surface'               ),
('temporarilyAboveAndBelowWaterSurface'  ,'(City)Object temporarily above and below water surface'  )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.enumeration	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'TextureTypeType'
) INSERT INTO qgis_pkg.enumeration_value (enum_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES  
('specific'  ,'Specific'),
('typical'   ,'Typical' ),
('unknown'   ,'Unknown' )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.enumeration	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'WrapModeTypeType'
) INSERT INTO qgis_pkg.enumeration_value (enum_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES  
('none'  ,'None'  ),
('wrap'  ,'Wrap'  ),
('mirror','Mirror'),
('clamp' ,'Clamp' ),
('border','Border')
) AS v(value, description);

-- ****************************************************************************
-- ****************************************************************************

--TRUNCATE    qgis_pkg.enumeration CASCADE RESTART IDENTITY;
INSERT INTO qgis_pkg.codelist (data_model, name, name_space) VALUES
('CityGML 2.0','MimeType'									,'https://www.sig3d.org/codelists/standard/core/2.0/ImplicitGeometry_mimeType.xml'),
('CityGML 2.0','_AbstractBridgeClass'						,'https://www.sig3d.org/codelists/standard/bridge/2.0/_AbstractBridge_class.xml'),
('CityGML 2.0','_AbstractBridgeFunctionUsage'				,'https://www.sig3d.org/codelists/standard/bridge/2.0/_AbstractBridge_function.xml'),
('CityGML 2.0','_AbstractBuildingClass'						,'https://www.sig3d.org/codelists/standard/building/2.0/_AbstractBuilding_class.xml'),
('CityGML 2.0','_AbstractBuildingFunctionUsage'				,'https://www.sig3d.org/codelists/standard/building/2.0/_AbstractBuilding_function.xml'),
('CityGML 2.0','_AbstractBuildingRoofType'					,'https://www.sig3d.org/codelists/standard/building/2.0/_AbstractBuilding_roofType.xml'),
('CityGML 2.0','RoomClass'									,'https://www.sig3d.org/codelists/standard/building/2.0/Room_class.xml'),
('CityGML 2.0','RoomFunctionUsage'							,'https://www.sig3d.org/codelists/standard/building/2.0/Room_function.xml'),
('CityGML 2.0','BuildingFurnitureClass'						,'https://www.sig3d.org/codelists/standard/building/2.0/BuildingFurniture_class.xml'),
('CityGML 2.0','BuildingFurnitureFunctionUsage'				,'https://www.sig3d.org/codelists/standard/building/2.0/BuildingFurniture_function.xml'),
('CityGML 2.0','BuildingInstallationClass'					,'https://www.sig3d.org/codelists/standard/building/2.0/BuildingInstallation_class.xml'),
('CityGML 2.0','BuildingInstallationFunctionUsage'			,'https://www.sig3d.org/codelists/standard/building/2.0/BuildingInstallation_function.xml'),
('CityGML 2.0','IntBuildingInstallationClass'				,'https://www.sig3d.org/codelists/standard/building/2.0/IntBuildingInstallation_class.xml'),
('CityGML 2.0','IntBuildingInstallationFunctionUsage'		,'https://www.sig3d.org/codelists/standard/building/2.0/IntBuildingInstallation_function.xml'),
('CityGML 2.0','CityFurnitureClass'							,'https://www.sig3d.org/codelists/standard/cityfurniture/2.0/CityFurniture_class.xml'),
('CityGML 2.0','CityFurnitureFunctionUsage'					,'https://www.sig3d.org/codelists/standard/cityfurniture/2.0/CityFurniture_function.xml'),
('CityGML 2.0','CityObjectGroupClass'						,'https://www.sig3d.org/codelists/standard/cityobjectgroup/2.0/CityObjectGroup_class.xml'),
('CityGML 2.0','CityObjectGroupFunctionUsage'				,'https://www.sig3d.org/codelists/standard/cityobjectgroup/2.0/CityObjectGroup_function.xml'),
('CityGML 2.0','LandUseClass'								,'https://www.sig3d.org/codelists/standard/landuse/2.0/LandUse_class.xml'),
('CityGML 2.0','LandUseFunctionUsage'						,'https://www.sig3d.org/codelists/standard/landuse/2.0/LandUse_function.xml'),
('CityGML 2.0','TransportationComplexClass'					,'https://www.sig3d.org/codelists/standard/transportation/2.0/TransportationComplex_class.xml'),
('CityGML 2.0','TransportationComplexFunctionUsage'			,'https://www.sig3d.org/codelists/standard/transportation/2.0/TransportationComplex_function.xml'),
('CityGML 2.0','AuxiliaryTrafficAreaFunction'				,'https://www.sig3d.org/codelists/standard/transportation/2.0/AuxiliaryTrafficArea_function.xm'),
('CityGML 2.0','TrafficAreaFunction'						,'https://www.sig3d.org/codelists/standard/transportation/2.0/TrafficArea_function.xm'),
('CityGML 2.0','TrafficAreaUsage'							,'https://www.sig3d.org/codelists/standard/transportation/2.0/TrafficArea_usage.xm'),
('CityGML 2.0','TrafficAreaSurfaceMaterial'					,'https://www.sig3d.org/codelists/standard/transportation/2.0/TrafficArea_surfaceMaterial.xml'),
('CityGML 2.0','_AbstractTunnelClass'						,'https://www.sig3d.org/codelists/standard/tunnel/2.0/_AbstractTunnel_class.xml'),
('CityGML 2.0','_AbstractTunnelFunctionUsage'				,'https://www.sig3d.org/codelists/standard/tunnel/2.0/_AbstractTunnel_function.xml'),
('CityGML 2.0','PlantCoverClassFunctionUsage'				,'https://www.sig3d.org/codelists/standard/vegetation/2.0/PlantCover_class.xml'),
('CityGML 2.0','SolitaryVegetationObjectClassFunctionUsage'	,'https://www.sig3d.org/codelists/standard/vegetation/2.0/SolitaryVegetationObject_class.xml'),
('CityGML 2.0','SolitaryVegetationObjectSpecies'			,'https://www.sig3d.org/codelists/standard/vegetation/2.0/SolitaryVegetationObject_species.xml'),
('CityGML 2.0','WaterbodyClass'								,'https://www.sig3d.org/codelists/standard/waterbody/2.0/WaterBody_class.xml'),
('CityGML 2.0','WaterbodyFunction'							,'https://www.sig3d.org/codelists/standard/waterbody/2.0/WaterBody_function.xml'),
('CityGML 2.0','WaterbodyUsage'								,'https://www.sig3d.org/codelists/standard/waterbody/2.0/WaterBody_usage.xml'),
('CityGML 2.0','WaterSurfaceWaterLevel'						,'https://www.sig3d.org/codelists/standard/waterbody/2.0/WaterSurface_waterLevel.xml')
--('CityGML 2.0',''			,''),
;

-- ****************************************************************************
-- ****************************************************************************

--TRUNCATE    qgis_pkg.enumeration_value CASCADE RESTART IDENTITY;
WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'MimeType'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES  
('model/vrml'                   , 'VRML97'              ),
('application/x-3ds'            , '3ds max'             ),
('application/dxf'              , 'AutoCad DXF'         ),
('application/x-autocad'        , 'AutoCad DXF'         ),
('application/x-dxf'            , 'AutoCad DXF'         ),
('application/acad'             , 'AutoCad DWG'         ),
('application/x-shockwave-flash', 'Shockwave 3D'        ),
('model/x3d+xml'                , 'X3D'                 ),
('model/x3d+binary'             , 'X3D'                 ),
('image/gif'                    , '*.gif images'        ),
('image/jpeg'                   , '*.jpeg, *.jpg images'),
('image/png'                    , '*.png images'        ),
('image/tiff'                   , '*.tiff, *.tif images'),
('image/bmp'                    , '*.bmp images'        )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = '_AbstractBridgeClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES  
(1000, 'Arced bridge'         ),
(1010, 'Cable-stayed bridge'  ),
(1020, 'Deck bridge'          ),
(1030, 'Cable-stayed overpass'),
(1040, 'Truss bridge'         ),
(1050, 'Pontoon bridge'       ),
(1060, 'Suspension bridge'    )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = '_AbstractBridgeFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Railway bridge'),
(1010, 'Roadway bridge'),
(1030, 'Cable link'    ),
(1040, 'Canal bridge'  ),
(1050, 'Aqueduct'      ),
(1060, 'Foot bridge'   )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = '_AbstractBuildingClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Habitation'                       ),
(1010, 'Sanitation'                       ),
(1020, 'Administration'                   ),
(1030, 'Business, trade'                  ),
(1040, 'Catering'                         ),
(1050, 'Recreation'                       ),
(1060, 'Sport'                            ),
(1070, 'Culture'                          ),
(1080, 'Church institution'               ),
(1090, 'Agriculture, forestry'            ),
(1100, 'Schools, education, research'     ),
(1110, 'Maintainence and waste management'),
(1120, 'Healthcare'                       ),
(1130, 'Communicating'                    ),
(1140, 'Security'                         ),
(1150, 'Storage'                          ),
(1160, 'Industry'                         ),
(1170, 'Traffic'                          ),
(1180, 'Other function'                   ),
(9999, 'Unknown'                          )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = '_AbstractBuildingFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Residential building'                       ),
(1010, 'Tenement'                                   ),
(1020, 'Hostel'                                     ),
(1090, 'Forester''s lodge'                          ),
(1100, 'Holiday house'                              ),
(1110, 'Summer house'                               ),
(1120, 'Office building'                            ),
(1130, 'Credit institution'                         ),
(1140, 'Insurance'                                  ),
(1150, 'Business building'                          ),
(1160, 'Department store'                           ),
(1170, 'Shopping centre'                            ),
(1180, 'Kiosk'                                      ),
(1190, 'Pharmacy'                                   ),
(1200, 'Pavilion'                                   ),
(1210, 'Hotel'                                      ),
(1220, 'Youth hostel'                               ),
(1230, 'Campsite building'                          ),
(1240, 'Restaurant'                                 ),
(1250, 'Cantine'                                    ),
(1260, 'Recreational site'                          ),
(1270, 'Function room'                              ),
(1280, 'Cinema'                                     ),
(1290, 'Bowling alley'                              ),
(1300, 'Casino'                                     ),
(1310, 'Industrial building'                        ),
(1320, 'Factory'                                    ),
(1330, 'Workshop'                                   ),
(1350, 'Washing plant'                              ),
(1360, 'Cold store'                                 ),
(1370, 'Depot'                                      ),
(1380, 'Building for research purposes'             ),
(1390, 'Quarry'                                     ),
(1400, 'Salt works'                                 ),
(1410, 'Miscellaneous industrial building'          ),
(1420, 'Mill'                                       ),
(1430, 'Windmill'                                   ),
(1440, 'Water mill'                                 ),
(1450, 'Bucket elevator'                            ),
(1460, 'Weather station'                            ),
(1470, 'Traffic assets office'                      ),
(1480, 'Street maintenance'                         ),
(1490, 'Waiting hall'                               ),
(1500, 'Signal control box'                         ),
(1510, 'Engine shed'                                ),
(1520, 'Signal box or stop signal'                  ),
(1530, 'Plant building for air traffic'             ),
(1540, 'Hangar'                                     ),
(1550, 'Plant building for shipping'                ),
(1560, 'Shipyard'                                   ),
(1570, 'Dock'                                       ),
(1580, 'Plant building for canal lock'              ),
(1590, 'Boathouse'                                  ),
(1600, 'Plant building for cablecar'                ),
(1610, 'Multi-storey car park'                      ),
(1620, 'Parking level'                              ),
(1630, 'Garage'                                     ),
(1640, 'Vehicle hall'                               ),
(1650, 'Underground garage'                         ),
(1660, 'Building for supply'                        ),
(1670, 'Waterworks'                                 ),
(1680, 'Pump station'                               ),
(1690, 'Water basin'                                ),
(1700, 'Electric power station'                     ),
(1710, 'Transformer station'                        ),
(1720, 'Converter'                                  ),
(1730, 'Reactor'                                    ),
(1740, 'Turbine house'                              ),
(1750, 'Boiler house'                               ),
(1760, 'Building for telecommunications'            ),
(1770, 'Gas works'                                  ),
(1780, 'Heat plant'                                 ),
(1790, 'Pumping station'                            ),
(1800, 'Building for disposal'                      ),
(1810, 'Building for effluent disposal'             ),
(1820, 'Building for filter plant'                  ),
(1830, 'Toilet'                                     ),
(1840, 'Rubbish bunker'                             ),
(1850, 'Building for rubbish incineration'          ),
(1860, 'Building for rubbish disposal'              ),
(1870, 'Building for agrarian and forestry'         ),
(1880, 'Barn'                                       ),
(1890, 'Stall'                                      ),
(1900, 'Equestrian hall'                            ),
(1910, 'Alpine cabin'                               ),
(1920, 'Hunting lodge'                              ),
(1930, 'Arboretum'                                  ),
(1940, 'Glass house'                                ),
(1950, 'Moveable glass house'                       ),
(1960, 'Public building'                            ),
(1970, 'Administration building'                    ),
(1980, 'Parliament'                                 ),
(1990, 'Guildhall'                                  ),
(2000, 'Post office'                                ),
(2010, 'Customs office'                             ),
(2020, 'Court'                                      ),
(2030, 'Embassy or consulate'                       ),
(2040, 'District administration'                    ),
(2050, 'District government'                        ),
(2060, 'Tax office'                                 ),
(2080, 'Comprehensive school'                       ),
(2090, 'Vocational school'                          ),
(2100, 'College or university'                      ),
(2110, 'Research establishment'                     ),
(2120, 'Building for cultural purposes'             ),
(2130, 'Castle'                                     ),
(2140, 'Theatre or opera'                           ),
(2150, 'Concert building'                           ),
(2160, 'Museum'                                     ),
(2170, 'Broadcasting building'                      ),
(2180, 'Activity building'                          ),
(2190, 'Library'                                    ),
(2200, 'Fort'                                       ),
(2210, 'Religious Building'                         ),
(2220, 'Church'                                     ),
(2230, 'Synagogue'                                  ),
(2240, 'Chapel'                                     ),
(2250, 'Community centre'                           ),
(2260, 'Place of worship'                           ),
(2270, 'Mosque'                                     ),
(2280, 'Temple'                                     ),
(2290, 'Convent'                                    ),
(2300, 'Building for health care'                   ),
(2310, 'Hospital'                                   ),
(2320, 'Healing centre or care home'                ),
(2330, 'Health centre or outpatients clinic'        ),
(2340, 'Building for social purposes'               ),
(2350, 'Youth centre'                               ),
(2360, 'Seniors centre'                             ),
(2370, 'Homeless shelter'                           ),
(2380, 'Kindergarten or nursery'                    ),
(2390, 'Asylum seekers home'                        ),
(2400, 'Police station'                             ),
(2410, 'Fire station'                               ),
(2420, 'Barracks'                                   ),
(2430, 'Bunker'                                     ),
(2440, 'Penitentiary or prison'                     ),
(2450, 'Cemetery building'                          ),
(2460, 'Funeral parlor'                             ),
(2470, 'Crematorium'                                ),
(2480, 'Train Station'                              ),
(2490, 'Airport building'                           ),
(2500, 'Building for underground station'           ),
(2510, 'Building for tramway'                       ),
(2520, 'Building for bus station'                   ),
(2530, 'Shipping terminal'                          ),
(2540, 'Building for recuperation purposes'         ),
(1040, 'Residential and office building'            ),
(1050, 'Residential and business building'          ),
(1060, 'Residential and plant building'             ),
(1070, 'Agrarian and forestry building'             ),
(1080, 'Residential and commercial building'        ),
(1340, 'Petrol/Gas station'                         ),
(2550, 'Building for sport purposes'                ),
(2560, 'Sports hall'                                ),
(2570, 'Building for sports field'                  ),
(2580, 'Swimming baths'                             ),
(2590, 'Indoor swimming pool'                       ),
(2600, 'Sanatorium'                                 ),
(2610, 'Zoo building'                               ),
(2620, 'Green house'                                ),
(2630, 'Botanical show house'                       ),
(2640, 'Bothy'                                      ),
(2650, 'Tourist information centre'                 ),
(2700, 'Others'                                     ),
(1030, 'Residential and administration building'    ),
(2070, 'School Building for education and research' )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = '_AbstractBuildingRoofType'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Flat roof'),
(1010, 'Monopitch roof'),
(1020, 'Dual-pent roof'),
(1030, 'Gabled roof'),
(1040, 'Hipped roof'),
(1050, 'Half-hipped roof'),
(1060, 'Mansard roof'),
(1070, 'Pavilion roof'),
(1080, 'Cone roof'),
(1090, 'Cupola roof'),
(1100, 'Sawtooth roof '),
(1110, 'Arch roof'),
(1120, 'Pyramidal broach roof'),
(1130, 'Combination of roof forms')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'RoomClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Habitation'),
(1010, 'Administration'),
(1020, 'Business, trade'),
(1030, 'Catering'),
(1040, 'Recreation'),
(1050, 'Church Institution'),
(1060, 'Agriculture, forestry'),
(1070, 'Schools, education, research'),
(1080, 'Accommodation, waste management'),
(1090, 'Healthcare'),
(1100, 'Communicating'),
(1110, 'Security'),
(1120, 'Store'),
(1130, 'Industry'),
(1140, 'Traffic'),
(1150, 'Function')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'RoomFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Living room'),
(1010, 'Bedroom'),
(1020, 'Kitchen'),
(1030, 'Hall'),
(1040, 'Bath, washroom'),
(1050, 'Toilet'),
(1060, 'Stairs'),
(1070, 'Home office'),
(1080, 'Utility room'),
(1090, 'Dining room'),
(1100, 'Common room'),
(1110, 'Party room'),
(1120, 'Nursery'),
(1130, 'Store room'),
(1140, 'Canteen, common kitchen'),
(1150, 'Storeroom'),
(1160, 'Balcony, gallery'),
(1170, 'Terrace'),
(1180, 'Drying room'),
(1190, 'Heatingroom'),
(1200, 'Fuel depot'),
(1210, 'Hobby room'),
(1220, 'Stable, hovel'),
(1300, 'Cash office'),
(1310, 'Ticket office'),
(1320, 'Conference room'),
(1330, 'Reception'),
(1340, 'Sales room'),
(1350, 'Store room'),
(1360, 'Delivery'),
(1370, 'Lounge, common room'),
(1380, 'Escalator'),
(1390, 'Guest toilet'),
(1400, 'Strong room'),
(1500, 'Office'),
(1510, 'Entrance hall'),
(1520, 'Elevator'),
(1530, 'Canteen'),
(1540, 'Tea Kitchen/Coffee kitchen'),
(1550, 'Archive'),
(1560, 'Citizen office'),
(1570, 'Conference hall'),
(1580, 'Copier room/Blueprint room'),
(1590, 'Information'),
(1600, 'Computer room'),
(1610, 'Printer/Plotter room'),
(1700, 'Reception'),
(1710, 'Guest room'),
(1720, 'Bar'),
(1730, 'Breakfast room'),
(1740, 'Dining room'),
(1750, 'Celebration room'),
(1760, 'Pub'),
(1770, 'Beer garden'),
(1780, 'Restaurant'),
(1790, 'Cool store'),
(1800, 'Bowling alley, shoot alley'),
(1810, 'Lounge'),
(1820, 'Canteen kitchen'),
(1900, 'Stage'),
(1910, 'Auditorium'),
(1920, 'VIP box'),
(1930, 'Projection room'),
(1940, 'Dressing room'),
(1950, 'Cabin'),
(1960, 'Showroom'),
(1970, 'Equipment or props'),
(1980, 'Make-Up room'),
(1990, 'Recording studio'),
(2000, 'Sound studio'),
(2010, 'Music archive'),
(2020, 'Administration'),
(2030, 'Ticket office'),
(2040, 'Library'),
(2050, 'Media room'),
(2060, 'Dressing room'),
(2070, 'Sport poom'),
(2080, 'Equipment poom'),
(2090, 'Platform'),
(2100, 'Swimming pool'),
(2110, 'Slide'),
(2120, 'Relaxation room'),
(2130, 'Sauna'),
(2140, 'Fitness room'),
(2150, 'Solarium'),
(2160, 'Catering'),
(2170, 'Showers'),
(2200, 'Tribune'),
(2210, 'Seating/Standing capacity'),
(2220, 'Cash point'),
(2230, 'Vivarium'),
(2240, 'Enclosure'),
(2250, 'Aquarium'),
(2260, 'Terrarium'),
(2270, 'Aviary'),
(2280, 'Menagerie'),
(2290, 'Stables'),
(2300, 'Greenhouse'),
(2310, 'Food silo'),
(2320, 'Hayloft'),
(2330, 'Motor pool'),
(2340, 'Barn'),
(2350, 'Riding hall'),
(2360, 'Horse box'),
(2370, 'Hunting lodge'),
(2400, 'Waste container'),
(2410, 'Motor pool'),
(2420, 'Washing-bay'),
(2430, 'Installations room'),
(2440, 'Monitoring room'),
(2450, 'Heating system'),
(2460, 'Public utility use'),
(2470, 'Pump room'),
(2480, 'Effluent treatment'),
(2490, 'Treatment installation'),
(2500, 'Recycling installation'),
(2600, 'Chancel'),
(2610, 'Sacristy'),
(2620, 'Bell bower'),
(2630, 'Baptism room'),
(2640, 'Confessional'),
(2650, 'Benches'),
(2660, 'Pulpit'),
(2670, 'Lobby'),
(2680, 'Parish'),
(2690, 'Chapel'),
(2700, 'Police station'),
(2710, 'Headquarters'),
(2720, 'Prison cell'),
(2730, 'Motor pool hall'),
(2740, 'Fire brigade, Emergency vehicle'),
(2750, 'Relaxation room'),
(2760, 'Tool/Pipe store'),
(2770, 'Emergency call centre'),
(2780, 'Arms depot'),
(2790, 'Ammunition dump'),
(2800, 'Vehicle hall'),
(2810, 'Panic room'),
(2900, 'Satellite receiver'),
(2910, 'Communication room'),
(3000, 'Industrial building'),
(3010, 'Production building'),
(3020, 'Factory building'),
(3030, 'Workshop'),
(3040, 'Storage depot'),
(3050, 'Cold storage'),
(3060, 'Store'),
(3100, 'Station concourse'),
(3110, 'Track'),
(3120, 'Ticket office'),
(3130, 'Waiting hall'),
(3140, 'Engine shed'),
(3150, 'Signal box'),
(3160, 'Departure terminal'),
(3170, 'Check-out counter'),
(3180, 'Check-in counter'),
(3190, 'Check'),
(3200, 'Baggage carousel'),
(3210, 'Security check'),
(3300, 'Classroom'),
(3310, 'Staff room'),
(3320, 'Break/Recess hall'),
(3330, 'Laboratory'),
(3340, 'Utility room'),
(3350, 'Media room'),
(3360, 'Science laboratory'),
(3370, 'Sports hall'),
(3380, 'School library'),
(3390, 'Office'),
(3400, 'Lecture theatre'),
(3410, 'Refectory'),
(3420, 'Function room')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'BuildingFurnitureClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Habitation'),
(1010, 'Sanitation'),
(1020, 'Administration'),
(1030, 'Business, trade'),
(1040, 'Catering'),
(1050, 'Recreation'),
(1060, 'Sport'),
(1070, 'Culture'),
(1080, 'Church institution'),
(1090, 'Agriculture, forestry'),
(1100, 'Schools, education, research'),
(1110, 'Maintenance, waste management'),
(1120, 'Healthcare'),
(1130, 'Communicating'),
(1140, 'Security'),
(1150, 'Storage'),
(1160, 'Industry'),
(1170, 'Traffic'),
(1180, 'Function')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'BuildingFurnitureFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Cupboard'),
(1010, 'Wardrobe'),
(1020, 'Cabinet'),
(1030, 'Sideboard'),
(1040, 'Locker'),
(1050, 'Tool cabinet'),
(1100, 'Shelf'),
(1110, 'Rack'),
(1120, 'Coat stand'),
(1200, 'Table'),
(1210, 'Dining table'),
(1220, 'Coffee table'),
(1230, 'Desk'),
(1240, 'Bedside cabinet'),
(1250, 'Baby changing table'),
(1260, 'Bar'),
(1270, 'Pool table'),
(1280, 'Snooker table'),
(1290, 'Roulette table'),
(1370, 'Work bench'),
(1300, 'Chair'),
(1310, 'Bench'),
(1320, 'Office chair'),
(1330, 'Sofa'),
(1340, 'Rocking chair'),
(1350, 'Bar stool'),
(1360, 'Armchair'),
(1400, 'Bed'),
(1410, 'Crib'),
(1420, 'Bunk bed'),
(1430, 'Cradle'),
(1440, 'Cot'),
(1450, 'Stretcher'),
(1500, 'Lighting'),
(1510, 'Standard lamp'),
(1520, 'Ceiling light'),
(1530, 'Spotlight'),
(1600, 'Electric appliances'),
(1610, 'Television set'),
(1620, 'Video recorder '),
(1630, 'Stereo unit'),
(1700, 'Kitchen appliances'),
(1710, 'Cooker'),
(1720, 'Oven'),
(1730, 'Refrigerator'),
(1740, 'Coffee machine'),
(1750, 'Toaster'),
(1760, 'Kettle'),
(1770, 'Microwave'),
(1780, 'Dish washer'),
(1800, 'Laundry equipment'),
(1810, 'Washing machine'),
(1820, 'Ironing machine'),
(1830, 'Rotary iron (Mangle) '),
(1840, 'Laundry tumble drier'),
(1850, 'Spin drier'),
(1900, 'Technical office equipment'),
(1910, 'Copy machine'),
(1920, 'Scanner'),
(1930, 'Plotter'),
(1940, 'Printer'),
(1950, 'Screen'),
(1960, 'Computer'),
(1970, 'Overhead projector'),
(1980, 'Video projector'),
(2000, 'Sanitation equipment'),
(2010, 'Sink, hand-basin'),
(2020, 'Water tap'),
(2030, 'Toilet bowl'),
(2040, 'Bathtub'),
(2050, 'Shower'),
(2060, 'Bidet'),
(2100, 'Animal park'),
(2110, 'Aquarium'),
(2120, 'Cage'),
(2130, 'Birdcage'),
(2200, 'Religious equipment'),
(2300, 'Shop fittings'),
(2310, 'Sales counter'),
(2320, 'Glass cabinet'),
(2330, 'Changing cubicle'),
(2340, 'Refrigerated counter'),
(2350, 'Cash desk/Till/Counter'),
(2360, 'Box office'),
(2400, 'Machines'),
(2410, 'Ticket machine'),
(2420, 'Cigarette machine'),
(2430, 'Cash machine/ATM'),
(2440, 'Vending machine'),
(2450, 'Gambling machine'),
(2500, 'Technical furniture'),
(2510, 'Heating installation'),
(2520, 'Tank'),
(2521, 'Oil tank'),
(2522, 'Water tank'),
(2523, 'Gas tank '),
(2524, 'Fuel tank '),
(2525, 'Milk tank '),
(2526, 'Steel tank '),
(2530, 'Fire protection appliance'),
(2531, 'Fire extinguishing system'),
(2532, 'Fire alarm'),
(2533, 'Fire extinguisher'),
(2540, 'Switch board'),
(2550, 'Lifting platform'),
(2560, 'Compressed air system'),
(2570, 'Loud-speaker'),
(2580, 'Microphone'),
(2600, 'Sports equipment'),
(2610, 'Goal posts'),
(2620, 'Basketball basket'),
(2630, 'Volleyball net'),
(2640, 'Gymnastic apparatus'),
(2650, 'Diving platform '),
(2660, 'Swimming pool'),
(2700, 'Sales promotion furniture'),
(2710, 'Display panel'),
(2720, 'Billboard'),
(2730, 'Display cabinet'),
(2800, 'Functional furniture'),
(2805, 'Ashtray'),
(2810, 'Lectern'),
(2815, 'Stage'),
(2820, 'Blackboard'),
(2825, 'Screen'),
(2830, 'Mapstand'),
(2835, 'Rubbish bin'),
(2840, 'Sauna'),
(2845, 'Carpet'),
(2850, 'Wall clock'),
(2855, 'Curtain'),
(2860, 'Mirror')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'BuildingInstallationClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Outer characteristics'),
(1010, 'Inner characteristics'),
(1020, 'Waste management'     ),
(1030, 'Maintenance'          ),
(1040, 'Communicating'        ),
(1050, 'Security'             ),
(1060, 'Others'               )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'BuildingInstallationFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Balcony'),
(1010, 'Winter garden'),
(1020, 'Arcade'),
(1030, 'Chimney (Part of a building)'),
(1040, 'Tower (Part of a Building)'),
(1050, 'Column'),
(1060, 'Stairs'),
(1070, 'Others')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'IntBuildingInstallationClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Heating, ventilation, climate'),
(2000, 'Safety'),
(3000, 'Illumination'),
(4000, 'Communication'),
(5000, 'Supply and disposal'),
(6000, 'Statics'),
(7000, 'Entertainmant'),
(8000, 'Miscellaneous'),
(9999, 'Unknown')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'IntBuildingInstallationFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1010, 'Radiator'),
(1020, 'Oven'),
(1030, 'Fireside'),
(1040, 'Ventilator'),
(1050, 'Air conditioning'),
(5010, 'Pipe'),
(3010, 'Lamp'),
(3020, 'Light switch'),
(5030, 'Power point'),
(5020, 'Cable'),
(7010, 'Rafter'),
(7020, 'Column'),
(8010, 'Railing'),
(8020, 'Stair')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'CityFurnitureClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Traffic'),
(1010, 'Communication'),
(1020, 'Security'),
(1030, 'Others')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'CityFurnitureFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Communication fixture'),
(1010, 'Telephone box'),
(1020, 'Postbox'),
(1030, 'Emergency call fixture'),
(1040, 'Fire detector'),
(1050, 'Police call post'),
(1060, 'Switching unit'),
(1070, 'Road sign'),
(1080, 'Traffic light'),
(1090, 'Free-standing sign'),
(1100, 'Free-standing warning sign'),
(1110, 'Bus stop'),
(1120, 'Milestone'),
(1130, 'Rail level crossing'),
(1140, 'Gate'),
(1150, 'Streetlamp, latern or candelabra'),
(1160, 'Column'),
(1170, 'Lamp post'),
(1180, 'Flagpole'),
(1190, 'Street sink box'),
(1200, 'Rubbish bin'),
(1210, 'Clock'),
(1220, 'Directional spot light'),
(1230, 'Floodlight mast'),
(1240, 'Windmill'),
(1250, 'Solar cell'),
(1260, 'Water wheel'),
(1270, 'Pole'),
(1280, 'Radio mast'),
(1290, 'Aerial'),
(1300, 'Radio telescope'),
(1310, 'Chimney'),
(1320, 'Marker'),
(1330, 'Hydrant'),
(1340, 'Upper corridor fire-hydrant '),
(1350, 'Lower floor panel fire-hydrant '),
(1360, 'Slidegate valve cap '),
(1370, 'Entrance shaft'),
(1380, 'Converter'),
(1390, 'Stair'),
(1400, 'Outside staircase'),
(1410, 'Escalator'),
(1420, 'Ramp'),
(1430, 'Patio'),
(1440, 'Fence'),
(1450, 'Memorial/monument'),
(1470, 'Wayside shrine'),
(1480, 'Crossroads'),
(1490, 'Cross on the summit of a mountain'),
(1500, 'Fountain'),
(1510, 'Block mark'),
(1520, 'Boundary post'),
(1530, 'Bench'),
(1540, 'Others')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'CityObjectGroupClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Building separation'),
(2000, 'Assembly')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'CityObjectGroupFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Lod1storey'),
(1010, 'Lod2storey'),
(1020, 'Lod3storey'),
(1030, 'Lod4storey')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'LandUseClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Settlement area'),
(1100, 'Undeveloped area'),
(2000, 'Traffic'),
(3000, 'Vegetation'),
(4000, 'Water')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'LandUseFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1010, 'Residential'),
(1020, 'Industry and business'),
(1030, 'Mixed use'),
(1040, 'Special function area'),
(1050, 'Monument'),
(1060, 'Dump'),
(1070, 'Mining'),
(1110, 'Park'),
(1120, 'Cemetary'),
(1130, 'Sports, leisure and recreation'),
(1140, 'Open pit, quarry'),
(2010, 'Road'),
(2020, 'Railway'),
(2030, 'Airfield'),
(2040, 'Shipping'),
(2050, 'Track'),
(2060, 'Square'),
(3010, 'Grassland'),
(3020, 'Agriculture'),
(3030, 'Forest'),
(3040, 'Grove'),
(3050, 'Heath'),
(3060, 'Moor'),
(3070, 'Marsh'),
(3080, 'Untilled land'),
(4010, 'River'),
(4020, 'Standing waterbody'),
(4030, 'Harbour'),
(4040, 'Sea')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'TransportationComplexClass'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Private'),
(1010, 'Common'),
(1020, 'Civil'),
(1030, 'Military'),
(1040, 'Road traffic'),
(1050, 'Air traffic'),
(1060, 'Rail traffic'),
(1070, 'Waterway'),
(1080, 'Subway'),
(1090, 'Others')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'TransportationComplexFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Road'),
(1010, 'Freeway/Motorway'),
(1020, 'Highway/National primary road'),
(1030, 'Land road'),
(1040, 'District road'),
(1050, 'Municipal road'),
(1060, 'Main through-road'),
(1100, 'Freeway interchange/Highway junction'),
(1110, 'Junction'),
(1200, 'Road'),
(1210, 'Driveway'),
(1220, 'Footpath/Footway'),
(1230, 'Hiking trail'),
(1240, 'Bikeway/Cycle path'),
(1250, 'Bridleway/Bridlepath'),
(1260, 'Main agricultural road'),
(1270, 'Agricultural road'),
(1280, 'Bikeway/Footway'),
(1290, 'Access road'),
(1300, 'Dead-end road'),
(1400, 'Lane'),
(1410, 'Lane, One direction'),
(1420, 'Lane, Both directions'),
(1500, 'Pedestrian zone'),
(1600, 'Place'),
(1610, 'Parking area'),
(1620, 'Marketplace'),
(1700, 'Service area'),
(1800, 'Rail transport'),
(1805, 'Rail'),
(1810, 'Urban/City train'),
(1815, 'City railway'),
(1820, 'Tram'),
(1825, 'Subway'),
(1830, 'Funicular/Mountain railway'),
(1835, 'Mountain railway'),
(1840, 'Chairlift'),
(1845, 'Ski-Lift/Ski tow lift'),
(1850, 'Suspension railway'),
(1855, 'Railway track'),
(1860, 'Magnetic levitation train'),
(1900, 'Railway station'),
(1910, 'Stop'),
(1920, 'Station'),
(2000, 'Power-Wheel'),
(2100, 'Airport'),
(2110, 'International airport'),
(2120, 'Regional airport'),
(2130, 'Landing place'),
(2140, 'Heliport'),
--(2150, 'Landing place'),
(2160, 'Gliding airfield'),
(2170, 'Taxiway'),
(2180, 'Apron'),
(2190, 'Runway'),
(2200, 'Canal'),
(2300, 'Harbor'),
(2310, 'Pleasure craft harbour'),
(2400, 'Ferry'),
(2410, 'Car ferry'),
(2420, 'Train ferry'),
(2430, 'Ferry'),
(2500, 'Landing stage'),
(2600, 'Waterway I Order'),
(2610, 'Navigable river'),
(2620, 'Inland navigation waterway 0'),
--(2621, 'Inland navigation waterway 0'),
(2622, 'Inland navigation waterway I'),
(2623, 'Inland navigation waterway II'),
(2624, 'Inland navigation waterway III'),
(2625, 'Inland navigation waterway IV'),
(2626, 'Inland navigation waterway V'),
(2627, 'Inland navigation waterway VI'),
(2628, 'Inland navigation waterway VII'),
(2630, 'Maritime navigation'),
(2640, 'Navigable lake'),
(2700, 'Others')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'AuxiliaryTrafficAreaFunction'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Soft shoulder'        ),
(1010, 'Hard shoulder'        ),
(1020, 'Green area'           ),
(1030, 'Middle lane'          ),
(1040, 'Lay by'               ),
(1100, 'Parking bay'          ),
(1200, 'Ditch'                ),
(1210, 'Drainage'             ),
(1220, 'Kerbstone'            ),
(1230, 'Flower tub'           ),
(1300, 'Traffic island'       ),
(1400, 'Bank'                 ),
(1410, 'Embankment, dike'     ),
(1420, 'Railroad embankment'  ),
(1430, 'Noise protection'     ),
(1440, 'Noise protection wall'),
(1500, 'Noise-guard bar'      ),
(1600, 'Towpath'              ),
(1700, 'Others'               )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'TrafficAreaFunction'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(   1, 'Driving lane'),
(   2, 'Footpath'),
(   3, 'Cyclepath'),
(   4, 'Combined Foot-/Cyclepath'),
(   5, 'Square'),
(   6, 'Car park'),
(   7, 'Parking lay by'),
(   8, 'Rail'),
(   9, 'Rail/Road combined'),
(  10, 'Drainage'),
(  11, 'Road marking'),
(  12, 'Road marking direction'),
(  13, 'Road marking lane'),
(  14, 'Road marking restricted'),
(  15, 'Road marking crosswalk'),
(  16, 'Road marking stop'),
(  17, 'Road marking other'),
(  18, 'Overhead wire (Trolley)'),
(  19, 'Train platform'),
(  20, 'Crosswalk'),
(  21, 'Barrier'),
(  22, 'Stairs'),
(  23, 'Escalator'),
(  24, 'Filtering lane'),
(  25, 'Airport runway'),
(  26, 'Airport taxiway'),
(  27, 'Airport apron'),
(  28, 'Airport heliport'),
(  29, 'Airport runway marking'),
(  30, 'Green spaces'),
(  31, 'Recreation'),
(  32, 'Bus lay by'),
(  33, 'Motorway'),
(  34, 'Motorway entry'),
(  35, 'Motorway exit'),
(  36, 'Motorway emergency lane'),
(  37, 'Private area'),
(9999, 'Unknown')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'TrafficAreaUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(   1, 'Pedestrian'),
(   2, 'Car'),
(   3, 'Truck'),
(   4, 'Bus, Taxi'),
(   5, 'Train'),
(   6, 'Bicycle'),
(   7, 'Motorcycle'),
(   8, 'Tram, Streetcar'),
(   9, 'Boat, Ferry, Ship'),
(  10, 'Teleferic'),
(  11, 'Aeroplane'),
(  12, 'Helicopter'),
(  13, 'Taxi'),
(  14, 'Horse'),
(9999, 'Unknown')
) AS v(value, description);


WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'TrafficAreaSurfaceMaterial'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(   1, 'Asphalt'         ),
(   2, 'Concrete'        ),
(   3, 'Pavement'        ),
(   4, 'Cobblestone'     ),
(   5, 'Gravel'          ),
(   6, 'Rail with bed'   ),
(   7, 'Rail without bed'),
(   8, 'Soil'            ),
(   9, 'Sand'            ),
(  10, 'Grass'           ),
(  11, 'Wood'            ),
(  12, 'Steel'           ),
(  13, 'Marble'          ),
(9999, 'Unknown'         )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'TunnelClassFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Traffic'   ),
(1010, 'Supply'    ),
(1020, 'Historical'),
(1030, 'Others'    )
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'TunnelFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Railway tunnel'),
(1010, 'Roadway tunnel'),
(1020, 'Canal tunnel'),
(1030, 'Pedestrian tunnel')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'PlantCoverClassFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1010, 'Lemnetea'),
(1020, 'Asplenietea Rupestris'),
(1030, 'Adiantetea'),
(1040, 'Thlaspietea Rotundifolii'),
(1050, 'Crithmo-Limonietea'),
(1060, 'Ammophietea'),
(1070, 'Cakiletea Maritimae Halophile'),
(1080, 'Secalinetea'),
(1090, 'Chenopodietea'),
(1100, 'Onopordetea'),
(1110, 'Epilobietea Angustifolii'),
(1120, 'Bidentetea Tripartiti'),
(1130, 'Zoosteretea Marinae Halophile'),
(1140, 'Ruppietea Maritimae'),
(1150, 'Potametea Haftende'),
(1160, 'Litorelletea'),
(1170, 'Plantaginetea Majoris'),
(1180, 'Isoeto-Nanojuncetea'),
(1190, 'Montino-Cardaminetea'),
(1200, 'Corynephoretea'),
(1210, 'Asteretea Tripolium'),
(1220, 'Salicornietea'),
(1230, 'Juncetea Maritimi'),
(1240, 'Phragmitetea'),
(1250, 'Spartinetea'),
(1260, 'Sedo-Scleranthetea'),
(1270, 'Salicetea Herbaceae'),
(1280, 'Arrhenatheretea'),
(1290, 'Molinio-Juncetea'),
(1300, 'Scheuchzerio-Caricetea Fuscae Azidophile'),
(1310, 'Festuco-Brometea'),
(1320, 'Elyno-Seslerietea'),
(1330, 'Caricetea Curvulae Azidophile'),
(1340, 'Calluno-Ulicetea'),
(1350, 'Oxycocco-Sphagnetea'),
(1360, 'Salicetea Purpureae'),
(1370, 'Betulo-Adenostyletea'),
(1380, 'Alnetea Glutinosae'),
(1390, 'Erico-Pinetea'),
(1400, 'Vaccinio-Piceetea'),
(1410, 'Quercetea Robori-Petraeae'),
(1420, 'Querco-Fagetea'),
(1430, 'Crithmo-Staticetea'),
(1440, 'Tuberarietea Guttati'),
(1450, 'Juncetea Maritimae'),
(1460, 'Thero-Brachypodietea'),
(1470, 'Ononido-Rosmarinetea'),
(1480, 'Nerio-Tamaricetea'),
(1490, 'Pegano-Salsoletea'),
(1500, 'Cisto-Lavanduletea'),
(1510, 'Quercetea Ilicis'),
(1520, 'Populetea Albae'),
(9999, 'Unknown')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'SolitaryVegetationObjectClassFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Shrub'),
(1010, 'Low plants'),
(1020, 'Medium high plants'),
(1030, 'High plants'),
(1040, 'Grasses'),
(1050, 'Ferns'),
(1060, 'Coniferous tree'),
(1070, 'Decidous tree'),
(1080, 'Bushes'),
(1090, 'Aquatic plants'),
(1100, 'Climber'),
(9999, 'Unknown')
) AS v(value, description);

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'SolitaryVegetationObjectSpecies'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES
(1000, 'Picea'),
(1010, 'Pinus'),
(1020, 'Larix'),
(1030, 'Quercus'),
(1040, 'Fagus'),
(1050, 'Betula'),
(1060, 'Alnus'),
(1070, 'Populus'),
(1080, 'Salix'),
(1090, 'Acer'),
(1100, 'Fraxinus'),
(1110, 'Arabis'),
(1120, 'Galeobdolon Luteum'),
(1130, 'Campanula Poscharskyana'),
(1140, 'Galium Odoratum'),
(1150, 'Allium Ursinum'),
(1160, 'Helleborus'),
(1170, 'Alchemilla'),
(1180, 'Iris'),
(1190, 'Begonia'),
(1200, 'Ranunculus Asiaticus'),
(1210, 'Geranium Macrorrhizum Ingwersen'),
(1220, 'Pelargonie Burc Double'),
(1230, 'Euphorbia'),
(1240, 'Aqulilegia'),
(1250, 'Symphytum Officinale'),
(1260, 'Sedum Spectabile Und Sedum Telphium'),
(1270, 'Centaurea'),
(1280, 'Centaurea Cysanus'),
(1290, 'Lychnis Coronaria'),
(1300, 'Physalis'),
(1310, 'Coreopsis Verticillata'),
(1320, 'Calendula'),
(1330, 'Phlox Paniculata'),
(1340, 'Dianthus Barbatus'),
(1350, 'Hemerocallis'),
(1360, 'Hemerocallis Flava'),
(1370, 'Lythrum'),
(1380, 'Lysmachia'),
(1390, 'Aster Novae'),
(1400, 'Cardiocrinum Giganteum'),
(1410, 'Delphinium'),
(1420, 'Pteridium'),
(1430, 'Gymnocarpium Dryopteris'),
(1440, 'Matteuccia Struthiopteris'),
(1450, 'Magnolia Elisabeth'),
(1460, 'Hibiskus'),
(1470, 'Hydrangea'),
(1480, 'Cotinus Coggygria'),
(1490, 'Euonymus Europea'),
(1500, 'Rhododendron'),
(1510, 'Pontederia'),
(1520, 'Clematis'),
(1530, 'Tropaeolum'),
(1540, 'Vicia, Lathyrus'),
(1550, 'Plumbago'),
(1560, 'Zantedeschia'),
(1570, 'Fuchsia'),
(1580, 'Gerbera'),
(1590, 'Nopalxochia'),
(1600, 'Hydrangea'),
(1610, 'Cassia'),
(1620, 'Cistus'),
(1630, 'Abienus Festuschristus'),
(1640, 'Abies Alba'),
(1650, 'Abies Cephalonica'),
(1660, 'Abies Concolor'),
(1670, 'Abies Grandis'),
(1680, 'Abies Homolepsis'),
(1690, 'Abies Koreana'),
(1700, 'Abies Lasiocarpa'),
(1710, 'Abies Nordmanniana'),
(1720, 'Abies Pinsapo'),
(1730, 'Abies Procera'),
(1740, 'Abies Procera ''Glauca'''),
(1750, 'Abies Veitchii'),
(1760, 'Acer Campestre'),
(1770, 'Acer Capillipes'),
(1780, 'Acer Cappadocicum'),
(1790, 'Acer Circinatum'),
(1800, 'Acer Davidii'),
(1810, 'Acer Ginnala Maxim'),
(1820, 'Acer Grosserii'),
(1830, 'Acer Monspessulanum'),
(1840, 'Acer Negundo'),
(1850, 'Acer Palmatum'),
(1860, 'Acer Platanoides'),
(1870, 'Acer Platanoides ''Crimson King'''),
(1880, 'Acer Pseudoplatanus'),
(1890, 'Acer Rubrum'),
(1900, 'Acer Saccharinum'),
(1910, 'Acer Saccharum Marsch'),
(1920, 'Acer Tartaricum'),
(1930, 'Aesculus Hippocastanum'),
(1940, 'Aesculus X Carnea'),
(1950, 'Afzelia Africana'),
(1960, 'Ailanthus Altissima'),
(1970, 'Alnus Cordata'),
(1980, 'Alnus Glutinosa'),
(1990, 'Alnus Incana'),
(2000, 'Alnus Viridis'),
(2010, 'Amelanchier Ovalis'),
(2020, 'Anacardium Occidentale'),
(2030, 'Aralia Elata'),
(2040, 'Araucaria Araucana'),
(2050, 'Aucuba Japonica'),
(2060, 'Berberis Julianae'),
(2070, 'Berberis Thunbergii'),
(2080, 'Betula Alnoides'),
(2090, 'Betula Costata'),
(2100, 'Betula Davurica'),
(2110, 'Betula Ermanii'),
(2120, 'Betula Papyrifera'),
(2130, 'Betula Pendula'),
(2140, 'Betula Pubescens'),
(2150, 'Broussonetia Papyrifera'),
(2160, 'Buddleja Davidii'),
(2170, 'Butyrospermum Parkii'),
(2180, 'Buxus Sempervirens'),
(2190, 'Calocedrus Decurrens'),
(2200, 'Calocedrus Decurrens ''Aureovariegata'''),
(2210, 'Calycanthus Floridus'),
(2220, 'Campsis Radicans'),
(2230, 'Caragana Arborescens'),
(2240, 'Carpínus Betulus'),
(2250, 'Cassia Siberiana'),
(2260, 'Castanea Sativa'),
(2270, 'Catalpa Bignonioides'),
(2280, 'Cedrela Sinensis'),
(2290, 'Cedrus Atlantica'),
(2300, 'Cedrus Atlantica ''Glauca'''),
(2310, 'Cedrus Deodara'),
(2320, 'Cedrus Deodara Var Paktia'),
(2330, 'Cedrus Libani'),
(2340, 'Celtis Occidentalis'),
(2350, 'Cercis Siliquastrum'),
(2360, 'Chaenomeles Japonica'),
(2370, 'Chamaecyparis Lawsonia'),
(2380, 'Chamaecyparis Nootkatensis'),
(2390, 'Chionanthus Virginicus'),
(2400, 'Cladrastis Lutea'),
(2410, 'Clematis Montana'),
(2420, 'Clematis Vitalba'),
(2430, 'Colutea Arborescens'),
(2440, 'Cornus Alba'),
(2450, 'Cornus Florida'),
(2460, 'Cornus Mas'),
(2470, 'Cornus Sanguinea'),
(2480, 'Corylus Avellana'),
(2490, 'Corylus Avellana ''Contorta'''),
(2500, 'Corylus Colurna'),
(2510, 'Corylus Maxima'),
(2520, 'Cotinus Coggygria'),
(2530, 'Cotoneaster Frigidus'),
(2540, 'Crataegus Laevigata'),
(2550, 'Crataegus Laevigata ''Paul''s Scarlet'''),
(2560, 'Crataegus Lavallei ''Carrierei'''),
(2570, 'Crataegus Monogyna'),
(2580, 'Cryptomeria Japonica'),
(2590, 'Cupressus Arizonica'),
(2600, 'Cupressus Sempervirens'),
(2610, 'Davidia Involucrata'),
(2620, 'Delonix Regia'),
(2630, 'Deutzia Scabra'),
(2640, 'Dracaena Draco'),
(2650, 'Elaeagnus Angustifolia'),
(2660, 'Elaeagnus Umbellata'),
(2670, 'Euonymus Alatus'),
(2680, 'Euonymus Europaeus'),
(2690, 'Euonymus Planipes'),
(2700, 'Fagus Orientalis'),
(2710, 'Fagus Sylvatica'),
(2720, 'Fagus Sylvatica ''Pendula'''),
(2730, 'Fagus Sylvatica Purpurea'),
(2740, 'Ficus Carica'),
(2750, 'Forsythia X Intermedia'),
(2760, 'Frangula Alnus'),
(2770, 'Fraxínus Excélsior'),
(2780, 'Fraxinus Latifolia'),
(2790, 'Fraxinus Ornus'),
(2800, 'Fraxinus Paxiana'),
(2810, 'Ginkgo Biloba L'),
(2820, 'Gleditsia Triacanthos'),
(2830, 'Halesia Carolina'),
(2840, 'Hamamelis Virginiana'),
(2850, 'Hamamelis X Intermedia'),
(2860, 'Hedera Helix'),
(2870, 'Hibiscus Syriacus'),
(2880, 'Hippophae Rhamnoides'),
(2890, 'Ilex Aquifolium'),
(2900, 'Jasminum Nudiflorum'),
(2910, 'Juglans Nigra'),
(2920, 'Juglans Regia'),
(2930, 'Juniperus Communis'),
(2940, 'Juniperus Sabina'),
(2950, 'Kerria Japonica ''Pleniflora'''),
(2960, 'Khaya Senegalensis'),
(2970, 'Koelreuteria Paniculata'),
(2980, 'Kolkwitzia Amabilis'),
(2990, 'Laburnum Alpinum'),
(3000, 'Laburnum Anagyroides'),
(3010, 'Larix Decidua'),
(3020, 'Larix Kaempferi'),
(3030, 'Ligustrum Vulgare'),
(3040, 'Liquidambar Orientalis'),
(3050, 'Liquidambar Styraciflua'),
(3060, 'Liriodendron Tulipifera'),
(3070, 'Lonicera Maackii'),
(3080, 'Lonicera Tartarica'),
(3090, 'Lonicera X Heckrottii'),
(3100, 'Lonicera Xylosteum'),
(3110, 'Magnolia X Soulangiana'),
(3120, 'Mahonia Aquifolium'),
(3130, 'Malus Floribunda'),
(3140, 'Malus Sylvestris'),
(3150, 'Malus Toringoides'),
(3160, 'Mespilus Germanica'),
(3170, 'Metasequoia Glyptostroboides'),
(3180, 'Ostrya Carpinifolia'),
(3190, 'Parrotia Persica'),
(3200, 'Parthenocissus Quinquefolia'),
(3210, 'Parthenocissus Tricuspidata'),
(3220, 'Paulownia Tomentosa'),
(3230, 'Philadelphus Coronarius'),
(3240, 'Picea Abies'),
(3250, 'Picea Abies ''Inversa'''),
(3260, 'Picea Asperata'),
(3270, 'Picea Engelmanii'),
(3280, 'Picea Glauca'),
(3290, 'Picea Glauca ''Conica'''),
(3300, 'Picea Omorika'),
(3310, 'Picea Orientalis'),
(3320, 'Picea Polita'),
(3330, 'Picea Pungens ''Glauca'''),
(3340, 'Picea Sitchensis'),
(3350, 'Pinus Aristata'),
(3360, 'Pinus Armandii'),
(3370, 'Pinus Cembra'),
(3380, 'Pinus Contorta'),
(3390, 'Pinus Heldreichii'),
(3400, 'Pinus Jeffreyi'),
(3410, 'Pinus Koraiensis'),
(3420, 'Pinus Leucodermis'),
(3430, 'Pinus Mugo'),
(3440, 'Pinus Nigra'),
(3450, 'Pinus Nigra Var'),
--(3460, 'Pinus Nigra Var'),
(3470, 'Pinus Parviflora'),
(3480, 'Pinus Peuce'),
(3490, 'Pinus Ponderosa'),
(3500, 'Pinus Strobus'),
(3510, 'Pinus Sylvestris'),
(3520, 'Pinus Thunbergii'),
(3530, 'Pinus Wallichiana'),
(3540, 'Platanus Acerifolia'),
(3550, 'Platanus Orientalis'),
(3560, 'Platycladus Orientalis'),
(3570, 'Populus Alba'),
(3580, 'Populus Nigra'),
(3590, 'Populus Simonii'),
(3600, 'Populus Tremula'),
(3610, 'Populus X Canadensis'),
(3620, 'Populus X Canescens'),
(3630, 'Prunus Avium'),
(3640, 'Prunus Cerasifera ''Nigra'''),
(3650, 'Prunus Domestica'),
(3660, 'Prunus Domestica Ssp'),
(3670, 'Prunus Dulcis'),
(3680, 'Prunus Laurocerasus'),
(3690, 'Prunus Padus'),
(3700, 'Prunus Sargentii'),
(3710, 'Prunus Serotina'),
(3720, 'Prunus Serrulata'),
(3730, 'Prunus Spinosa'),
(3740, 'Prunus Subhirtella'),
(3750, 'Pseudotsuga Menziesii'),
(3760, 'Ptelea Trifoliata'),
(3770, 'Pterocarya Fraxinifolia'),
(3780, 'Pterocarya Stenoptera'),
(3790, 'Pyracantha Coccinea'),
(3800, 'Pyrus Pyraster'),
(3810, 'Quercus Acutissima'),
(3820, 'Quercus Cerris'),
(3830, 'Quercus Coccinea'),
(3840, 'Quercus Frainetto'),
(3850, 'Quercus Ilex'),
(3860, 'Quercus Libani'),
(3870, 'Quercus Palustris'),
(3880, 'Quercus Petraea'),
(3890, 'Quercus Prinus'),
(3900, 'Quercus Pubescens'),
(3910, 'Quercus Robur'),
(3920, 'Quercus Rubra'),
(3930, 'Quercus Suber'),
(3940, 'Quercus X Hispanica ''Lucombeana'''),
(3950, 'Quercus X Turneri'),
(3960, 'Rhamnus Cathartica'),
(3970, 'Rhamnus Imeretinus'),
(3980, 'Rhodotypos Scandens'),
(3990, 'Rhus Hirta'),
(4000, 'Ribes Aureum'),
(4010, 'Ribes Sanguineum'),
(4020, 'Robinia Pseudoacacia'),
(4030, 'Rosa Canina'),
(4040, 'Rosa Spinosissima'),
(4050, 'Rubus Fruticosus'),
(4060, 'Salix Alba'),
(4070, 'Salix Alba ''Tristis'''),
(4080, 'Salix Aurita'),
(4090, 'Salix Babylonica'),
(4100, 'Salix Caprea'),
(4110, 'Salix Caprea ''Kilmarnock'''),
(4120, 'Salix Cinerea'),
(4130, 'Salix Fragilis'),
(4140, 'Salix Matsudana''Tortuosa'''),
(4150, 'Salix Viminalis'),
(4160, 'Sambucus Nigra'),
(4170, 'Sambucus Racemosa'),
(4180, 'Sciadopitys Verticillata'),
(4190, 'Sequoia Sempervirens'),
(4200, 'Sequoiadendron Giganteum'),
(4210, 'Shepherdia Argentea'),
(4220, 'Sophora Japonica'),
(4230, 'Sorbus Aria'),
(4240, 'Sorbus Aucuparia'),
(4250, 'Sorbus Domestica'),
(4260, 'Sorbus Intermedia'),
(4270, 'Sorbus Torminalis'),
(4280, 'Spiraea X Billardii'),
(4290, 'Spiraea X Vanhouttei'),
(4300, 'Staphylea Pinnata'),
(4310, 'Stranvaesia Davidiana'),
(4320, 'Symphoricarpos Albus'),
(4330, 'Syringa Reflexa'),
(4340, 'Syringa Vulgaris'),
(4350, 'Tamarix Parviflora'),
(4360, 'Taxodium Distichum'),
(4370, 'Taxus Baccata'),
(4380, 'Thuja Occidentalis'),
(4390, 'Thuja Plicata'),
(4400, 'Thujopsis Dolabrata'),
(4410, 'Tilia Cordata'),
(4420, 'Tilia Platyphyllos'),
(4430, 'Tilia Tomentosa'),
(4440, 'Tsuga Canadensis'),
(4450, 'Ulex Europaeus'),
(4460, 'Ulmus Glabra'),
(4470, 'Ulmus Laevis'),
(4480, 'Ulmus Minor'),
(4490, 'Ulmus Pumila'),
(4500, 'Viburnum Farreri'),
(4510, 'Viburnum Lantana'),
(4520, 'Viburnum Lentago'),
(4530, 'Viburnum Opulus'),
(4540, 'Viburnum Rhytidophyllum'),
(4550, 'Viburnum Tinus'),
(4560, 'Viburnum X Bodnantense'),
(4570, 'Viscum Album'),
(4580, 'Vitis Coignetiae'),
(4590, 'Weigela Florida'),
(4600, 'Wisteria Sinensis'),
(4610, 'Zelkova Serrata'),
(4620, 'Acer'),
(4630, 'Actinidia Lind'),
(4640, 'Aeschynanthus Jack'),
(4650, 'Ageratum'),
(4660, 'Agrostemma Githago'),
(4670, 'Agrostis'),
(4680, 'Allium Cepa'),
(4690, 'Allium Fistulosum'),
(4700, 'Allium Porrum'),
(4710, 'Allium Schoenoprasum'),
(4720, 'Aloe'),
(4730, 'Alonsoa Meridionalis (F.) O. Kuntze'),
(4740, 'Alopecurus Pratensis'),
(4750, 'Alstroemeria'),
(4760, 'Amaranthus Blitoides S. Watson'),
(4770, 'Amaranthus Cruentus'),
(4780, 'Anigozanthos Labil'),
(4790, 'Anthriscus Cerefolium () Hoffm.'),
(4800, 'Anthurium Schott'),
(4810, 'Antirrhinum'),
(4820, 'Apium Graveolens'),
(4830, 'Arctium'),
(4840, 'Argyranthemum Frutescens () Schultz Bip.'),
(4850, 'Arnica Montana'),
(4860, 'Aronia Medik.'),
(4870, 'Arrhenatherum Elatius () P.beauv. Ex J.s. Et K.b. Presl'),
(4880, 'Asparagus Officinalis'),
(4890, 'Aster'),
(4900, 'Aubrieta Adans.'),
(4910, 'Avena Sativa'),
--(4920, 'Avena Sativa'),
(4930, 'Begonia X Hiemalis Fotsch'),
(4940, 'Begonia X Tuberhybrida Voss'),
(4950, 'Begonia-Semperflorens-Hybriden'),
(4960, 'Beta Vulgaris Var. Altissima Döll'),
(4970, 'Beta Vulgaris Var. Conditiva Alef.'),
(4980, 'Beta Vulgaris Var. Crassa Mansf.'),
(4990, 'Beta Vulgaris Var. Vulgaris'),
(5000, 'Bidens Ferulifolia (Jacq.) Dc.'),
(5010, 'Brachyscome Cass.'),
(5020, 'Brassica Juncea () Czernj. Et Cosson'),
(5030, 'Brassica Napus (Partim)'),
--(5040, 'Brassica Napus (Partim)'),
(5050, 'Brassica Napus Var. Napobrassica () Rchb.'),
(5060, 'Brassica Oleracea Convar. Acephala (Dc.) Alef. Var. Gongylodes'),
(5070, 'Brassica Oleracea Convar. Acephala (Dc.) Alef. Var. Medullosa Thel Und Var. Viridis'),
(5080, 'Brassica Oleracea Convar. Acephala (Dc.) Alef. Var. Sabellica'),
(5090, 'Brassica Oleracea Convar. Botrytis () Alef. Var. Botrytis'),
(5100, 'Brassica Oleracea Convar. Botrytis () Alef. Var. Cymosa Duch.'),
(5110, 'Brassica Oleracea Convar. Capitata () Alef. Var. Alba Dc.'),
(5120, 'Brassica Oleracea Convar. Capitata () Alef. Var. Rubra Dc.'),
(5130, 'Brassica Oleracea Convar. Capitata () Alef. Var. Sabauda'),
(5140, 'Brassica Oleracea Convar. Oleracea Var. Gemmifera Dc.'),
--(5150, 'Brassica Rapa Var. Rapa'),
(5160, 'Brassica Rapa Var. Rapa'),
--(5170, 'Brassica Rapa Var. Silvestris (Lam.) Briggs'),
(5180, 'Brassica Rapa Var. Silvestris (Lam.) Briggs'),
(5190, 'Bromus'),
(5200, 'Brunnera Macrophylla (Adams) Johnst.'),
(5210, 'Calceolaria'),
(5220, 'Calluna Vulgaris () Hull'),
(5230, 'Camelina Sativa () Crantz'),
(5240, 'Cannabis Sativa'),
(5250, 'Capsicum Annuum'),
(5260, 'Carex'),
(5270, 'Carthamus Tinctorius'),
(5280, 'Celosia'),
(5290, 'Chamomilla Recutita () Rauschert'),
(5300, 'Cichorium Endivia'),
(5310, 'Clematis'),
(5320, 'Convallaria Majalis'),
(5330, 'Coronilla Varia'),
(5340, 'Corylus'),
(5350, 'Crassula Schmidtii Regel'),
(5360, 'Cucumis Sativus'),
(5370, 'Cucurbita'),
(5380, 'Cucurbita Pepo'),
(5390, 'Cuphea P. Br.'),
(5400, 'Cydonia Oblonga Mil'),
(5410, 'Cynara Cardunculus'),
(5420, 'Cynara Scolymus'),
(5430, 'Daboecia Cantabrica (Huds.) K. Koch'),
(5440, 'Dactylis'),
(5450, 'Dahlia Cav.'),
(5460, 'Daucus Carota'),
(5470, 'Daucus Carota'),
(5480, 'Dendranthema X Grandiflorum (Ramat.) Kitam.'),
(5490, 'Deschampsia Cespitosa () P. Beauv.'),
(5500, 'Dianthus'),
(5510, 'Digitalis'),
(5520, 'Dracocephalum Moldavica'),
(5530, 'Echinodorus C. Rich. Ex Engelm.'),
(5540, 'Erica'),
(5550, 'Euonymus Fortunei (Turcz.) Hand.-Mazz.'),
(5560, 'Euphorbia Fulgens Karw. Ex Klotzsch'),
(5570, 'Euphorbia Milii Des Mou Var. Milii'),
(5580, 'Euphorbia Pulcherrima Willd. Ex Klotzsch'),
(5590, 'Fagopyrum Mil'),
(5600, 'Festuca Arundinacea Schreber'),
(5610, 'Festuca Ovina Sensu Lato'),
(5620, 'Festuca Pratensis Hudson'),
(5630, 'Festuca Rubra Sensu Lato'),
(5640, 'Ficus Benjamina'),
(5650, 'Ficus Carica'),
--(5660, 'Foeniculum Vulgare Mil'),
(5670, 'Foeniculum Vulgare Mil'),
(5680, 'Forsythia Vahl'),
(5690, 'Fragaria'),
(5700, 'Fuchsia'),
(5710, 'Gazania-Hybriden'),
(5720, 'Gentiana'),
(5730, 'Gerbera'),
(5740, 'Ginkgo Biloba'),
(5750, 'Glycine Max () Merr.'),
(5760, 'Hebe Comm. Ex Juss.'),
(5770, 'Helianthus Annuus'),
(5780, 'Helianthus Tuberosus'),
(5790, 'Helichrysum Italicum (Roth) Gussone'),
(5800, 'Heliotropium Arborescens'),
(5810, 'Helleborus'),
(5820, 'Hippophae'),
--(5830, 'Hordeum Vulgare Sensu Lato'),
(5840, 'Hordeum Vulgare Sensu Lato'),
(5850, 'Humulus Lupulus'),
(5860, 'Hydrangea'),
(5870, 'Hypericum Androsaemum'),
(5880, 'Hypericum Perforatum'),
(5890, 'Hyssopus Officinalis'),
(5900, 'Ilex'),
(5910, 'Impatiens'),
(5920, 'Impatiens Walleriana Hybriden'),
(5930, 'Juglans-Hybriden'),
(5940, 'Kalanchoe Adans.'),
--(5950, 'Lactuca Sativa'),
(5960, 'Lactuca Sativa'),
(5970, 'Leontopodium Alpinum Cass.'),
(5980, 'Leucanthemum X Superbum (J.W.Ingram) Bergmans Ex Kent'),
(5990, 'Lilium'),
(6000, 'Limonium Mil'),
(6010, 'Linum Usitatissimum'),
(6020, 'Liquidambar Styraciflua'),
(6030, 'Lobelia'),
(6040, 'Lolium (Partim)'),
(6050, 'Lolium Multiflorum Lam.'),
(6060, 'Lolium Perenne'),
(6070, 'Lolium X Boucheanum Kunth'),
(6080, 'Lonicera Nitida Wils.'),
(6090, 'Lotus Corniculatus'),
(6100, 'Lupinus Luteus'),
(6110, 'Lupinus Albus'),
(6120, 'Lupinus Angustifolius'),
(6130, 'Lupinus Mutabilis'),
(6140, 'Lupinus Nanus Douglas'),
(6150, 'Lycopersicon Lycopersicum () Karsten Ex Farw.'),
(6160, 'Malus Mil'),
--(6170, 'Malus Mil'),
--(6180, 'Malus Mil'),
(6190, 'Malva Verticillata'),
(6200, 'Medicago Lupulina'),
(6210, 'Medicago Sativa'),
(6220, 'Melissa Officinalis'),
(6230, 'Nicotiana'),
(6240, 'Ocimum Basilicum'),
(6250, 'Onobrychis Viciifolia Scop.'),
(6260, 'Orchidaceae'),
(6270, 'Origanum Majorana'),
(6280, 'Origanum Vulgare'),
(6290, 'Pelargonium L''herit. ex Ait.'),
(6300, 'Pelargonium-Grandiflorum-Hybriden'),
--(6310, 'Petroselinum Crispum (Miller) Nyman Ex A.w. Hill'),
(6320, 'Petroselinum Crispum (Miller) Nyman Ex A.w. Hill'),
(6330, 'Petunia Juss.'),
(6340, 'Phacelia Juss.'),
(6350, 'Phalaris Arundinacea'),
(6360, 'Phaseolus Coccineus'),
(6370, 'Phaseolus Vulgaris'),
--(6380, 'Phaseolus Vulgaris'),
(6390, 'Phleum'),
(6400, 'Physocarpus (Cambess.) Maxim.'),
(6410, 'Picea A. Dietr.'),
(6420, 'Pinus'),
(6430, 'Pisum Sativum (Partim)'),
--(6440, 'Pisum Sativum (Partim)'),
--(6450, 'Pisum Sativum (Partim)'),
--(6460, 'Pisum Sativum (Partim)'),
(6470, 'Poa'),
(6480, 'Poa Pratensis'),
(6490, 'Populus'),
(6500, 'Prunus'),
--(6510, 'Prunus'),
(6520, 'Prunus Avium ()'),
(6530, 'Prunus Cerasus'),
(6540, 'Prunus Domestica'),
(6550, 'Prunus Persica () Batsch'),
(6560, 'Prunus Spinosa'),
(6570, 'Pyracantha M.J. Roem.'),
(6580, 'Pyrus'),
--(6590, 'Pyrus'),
(6600, 'Quercus'),
(6610, 'Raphanobrassica'),
(6620, 'Raphanus Sativus Var. Niger (Miller) S. Kerner'),
(6630, 'Raphanus Sativus Var. Oleiformis Pers.'),
(6640, 'Raphanus Sativus Var. Sativus'),
(6650, 'Rehmannia Libosch. Ex Fisch. Et C. A. Mey.'),
(6660, 'Rhododendron'),
(6670, 'Rhododendron Simsii Planch.'),
(6680, 'Ribes'),
--(6690, 'Ribes'),
(6700, 'Ribes Nigrum'),
(6710, 'Ribes X Nidigrolaria R. et A. Bauer'),
(6720, 'Rosa'),
(6730, 'Rubus'),
--(6740, 'Rubus'),
(6750, 'Saintpaulia H. Wend'),
(6760, 'Salix'),
(6770, 'Sanvitalia Lam.'),
(6780, 'Satureja Hortensis'),
(6790, 'Scorzonera Hispanica'),
(6800, 'Secale'),
--(6810, 'Secale'),
(6820, 'Silybum Marianum () Gaertn.'),
(6830, 'Sinapis Alba'),
(6840, 'Sinningia Nees'),
(6850, 'Solanum'),
(6860, 'Solanum Tuberosum'),
(6870, 'Spinacia Oleracea'),
(6880, 'Streptocarpus Lind'),
(6890, 'Sutera Roth'),
(6900, 'Symphoricarpos Duham.'),
(6910, 'Syringa'),
(6920, 'Tagetes'),
(6930, 'Tanacetum Parthenium () Schultz Bip.'),
(6940, 'Tilia'),
(6950, 'Trifolium Alexandrinum'),
(6960, 'Trifolium Hybridum'),
(6970, 'Trifolium Incarnatum'),
(6980, 'Trifolium Pratense'),
(6990, 'Trifolium Repens'),
(7000, 'Trifolium Resupinatum'),
(7010, 'Trisetum Flavescens () P. Beauv.'),
(7020, 'Triticum Aestivum Emend. Fiori et Pao'),
--(7030, 'Triticum Aestivum Emend. Fiori et Pao'),
(7040, 'Triticum Durum Desf.'),
(7050, 'Triticum Monococcum'),
(7060, 'Triticum Spelta'),
(7070, 'Tulipa'),
(7080, 'Tussilago Farfara'),
(7090, 'Ulmus'),
(7100, 'Urtica'),
(7110, 'Vaccinium'),
(7120, 'Valeriana Officinalis'),
(7130, 'Valerianella Locusta () Laterr.'),
(7140, 'Vallisneria'),
(7150, 'Vicia (Partim)'),
(7160, 'Vicia Faba (Partim)'),
--(7170, 'Vicia Faba (Partim)'),
(7180, 'Vicia Sativa'),
(7190, 'Vinca Minor'),
(7200, 'Vitex Agnus-Castus'),
(7210, 'Vitis'),
(7220, 'Vitis Vinifera'),
(7230, 'Vriesea Splendens (Brongn.) Lem.'),
(7240, 'Zantedeschia Spreng.'),
(7250, 'Zea Mays'),
(7260, 'X Festulolium'),
(7270, 'X Triticosecale Wittm.'),
--(7280, 'X Triticosecale Wittm.'),
(9999, 'Unknown')
) AS v(value, description);



/* -- TEMPLATE

WITH em AS (SELECT id FROM qgis_pkg.codelist	WHERE
	data_model = 'CityGML 2.0'
	AND
	name = 'xxxxxClassFunctionUsage'
) INSERT INTO qgis_pkg.codelist_value (code_id, value, description) 
SELECT em.id, v.value, v.description FROM em, (VALUES


) AS v(value, description);

*/ --- END TEMPLATE
