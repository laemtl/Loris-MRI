INSERT INTO mri_scan_type (Scan_type) VALUES
  ("rsfmriAPecho1"),
  ("rsfmriAPecho2"),
  ("rsfmriAPecho3"),
  ("rsfmriAPse"),
  ("rsfmriPAse"),
  ("mpmMTonEcho1"),
  ("mpmMTonEcho2"),
  ("mpmMTonEcho3"),
  ("mpmMTonEcho4"),
  ("mpmMTonEcho5"),
  ("mpmMTonEcho6"),
  ("mpmMToffEcho1"),
  ("mpmMToffEcho2"),
  ("mpmMToffEcho3"),
  ("mpmMToffEcho4"),
  ("mpmMToffEcho5"),
  ("mpmMToffEcho6"),
  ("mpmMToffEcho7"),
  ("mpmMToffEcho8"),
  ("mpmT1wEcho1"),
  ("mpmT1wEcho2"),
  ("mpmT1wEcho3"),
  ("mpmT1wEcho4"),
  ("mpmT1wEcho5"),
  ("mpmT1wEcho6"),
  ("dwiPA"),
  ("dwiAPb0"),
  ("SEpCASL"),
  ("SEpCASLm0"),
  ("NeuromelT1"),
  ("axialFLAIR"),
  ("QSM"),
  ("meFieldmapEcho1"),
  ("meFieldmapEcho2"),
  ("meFieldmapEcho3");

UPDATE mri_protocol 
  SET TE_range="2-3" WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="adniT1");
  
UPDATE mri_protocol 
  SET series_description_regex="mp2rage-wip900_UNI_Images|MP2RAGE_1mm_UNI_Images" WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="MP2RAGEuni");
UPDATE mri_protocol 
  SET series_description_regex="mp2rage-wip900_T1_Images|MP2RAGE_1mm_T1_Images"   WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="MP2RAGEt1map");
UPDATE mri_protocol 
  SET series_description_regex="mp2rage-wip900_INV1|MP2RAGE_1mm_INV1"             WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="MP2RAGEinv1");
UPDATE mri_protocol 
  SET series_description_regex="mp2rage-wip900_INV2|MP2RAGE_1mm_INV2"             WHERE Scan_type=(SELECT ID FROM mri_scan_type WHERE Scan_type="MP2RAGEinv2");

INSERT INTO mri_protocol
  ( Center_name, ScannerID, Scan_type,                                                        TR_range, TE_range, TI_range, slice_thickness_range, time_range, series_description_regex) 
  VALUES
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriAPecho1"),   1000,     "12",     NULL,     3,                     604,        NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriAPecho2"),   1000,     "30-31",  NULL,     3,                     604,        NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriAPecho3"),   1000,     "48-49",  NULL,     3,                     604,        NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriAPse"),      NULL,     NULL,     NULL,     NULL,                  NULL,       "rsfmri-3mm-se-AP" ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="rsfmriPAse"),      NULL,     NULL,     NULL,     NULL,                  NULL,       "rsfmri-3mm-se-PA" ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho1"),     18,       "2-3",    NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho2"),     18,       "4-5",    NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho3"),     18,       "7-8",    NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho4"),     18,       "9-10",   NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho5"),     18,       "12-13",  NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="mpmT1wEcho6"),     18,       "14-15",  NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="dwiPA"),           3000,     "66",     NULL,     2,                     109,        NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="dwiAPb0"),         3000,     "66",     NULL,     2,                     5,          NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="SEpCASL"),         4400,     "7.8",    NULL,     7,                     40,         NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="SEpCASLm0"),       10000,    "10",     NULL,     7,                     4,          NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="NeuromelT1"),      600,      "10",     NULL,     1.8,                   NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="axialFLAIR"),      6000,     "356",    2200,     3,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="QSM"),             20,       "7-8",    NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho1"), 20,       "4-5",    NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho2"), 20,       "9-10",   NULL,     1,                     NULL,       NULL ),
  ( "ZZZZ",      0          (SELECT ID FROM mri_scan_type WHERE Scan_type="meFieldmapEcho3"), 20,       "15",     NULL,     1,                     NULL,       NULL );

-- add a check in MRI protocol check to make sure the PA and AP are respected for dwiAPb0 >  
