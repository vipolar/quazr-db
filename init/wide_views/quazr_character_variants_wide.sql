BEGIN;

DROP VIEW IF EXISTS quazr_character_variants_wide;
CREATE OR REPLACE VIEW quazr_character_variants_wide AS
WITH
attr_arrays AS (
  SELECT
    av.character,
    av.variant,
    ARRAY_AGG(DISTINCT av.value::quazr_environment_attribute_time ORDER BY av.value::quazr_environment_attribute_time)
      FILTER (WHERE av.attribute = 'time') AS time,
    ARRAY_AGG(DISTINCT av.value::quazr_environment_attribute_space ORDER BY av.value::quazr_environment_attribute_space)
      FILTER (WHERE av.attribute = 'space') AS space,
    ARRAY_AGG(DISTINCT av.value::quazr_environment_attribute_concept ORDER BY av.value::quazr_environment_attribute_concept)
      FILTER (WHERE av.attribute = 'concept') AS concept,
    ARRAY_AGG(DISTINCT av.value::quazr_environment_attribute_function ORDER BY av.value::quazr_environment_attribute_function)
      FILTER (WHERE av.attribute = 'function') AS function,
    ARRAY_AGG(DISTINCT av.value::quazr_environment_attribute_ecosystem ORDER BY av.value::quazr_environment_attribute_ecosystem)
      FILTER (WHERE av.attribute = 'ecosystem') AS ecosystem,
    ARRAY_AGG(DISTINCT av.value::quazr_environment_attribute_settlement ORDER BY av.value::quazr_environment_attribute_settlement)
      FILTER (WHERE av.attribute = 'settlement') AS settlement,
    ARRAY_AGG(DISTINCT av.value::quazr_environment_attribute_weather ORDER BY av.value::quazr_environment_attribute_weather)
      FILTER (WHERE av.attribute = 'weather') AS weather,
    ARRAY_AGG(DISTINCT av.value::quazr_environment_attribute_style ORDER BY av.value::quazr_environment_attribute_style)
      FILTER (WHERE av.attribute = 'style') AS style
  FROM quazr_character_variant_attribute_values av
  GROUP BY av.character, av.variant
),

environments_array AS (
  SELECT
    av.character,
    av.variant,
    ARRAY_AGG(DISTINCT av.environment ORDER BY av.environment) AS environment
  FROM quazr_character_variant_environments av
  GROUP BY av.character, av.variant
),

bundles_array AS (
  SELECT
    av.character,
    av.variant,
    ARRAY_AGG(DISTINCT av.bundle ORDER BY av.bundle) AS bundle
  FROM quazr_character_variant_r_bundles av
  GROUP BY av.character, av.variant
)

SELECT
  v.character,
  v.variant,
  v.display_name,
  v.description,
  COALESCE(ea.environment, ARRAY[]::varchar[]) AS environment,
  COALESCE(aa.time, ARRAY[]::quazr_environment_attribute_time[]) AS time,
  COALESCE(aa.space, ARRAY[]::quazr_environment_attribute_space[]) AS space,
  COALESCE(aa.concept, ARRAY[]::quazr_environment_attribute_concept[]) AS concept,
  COALESCE(aa.function, ARRAY[]::quazr_environment_attribute_function[]) AS function,
  COALESCE(aa.ecosystem, ARRAY[]::quazr_environment_attribute_ecosystem[]) AS ecosystem,
  COALESCE(aa.settlement, ARRAY[]::quazr_environment_attribute_settlement[]) AS settlement,
  COALESCE(aa.weather, ARRAY[]::quazr_environment_attribute_weather[]) AS weather,
  COALESCE(aa.style, ARRAY[]::quazr_environment_attribute_style[]) AS style,
  v.created_at,
  v.updated_at,
  v.starts_at,
  v.ends_at,
  COALESCE(ba.bundle, ARRAY[]::varchar[]) AS bundle,
  v.tier

FROM quazr_character_variants v
LEFT JOIN attr_arrays aa ON aa.character = v.character AND aa.variant = v.variant
LEFT JOIN environments_array ea ON ea.character = v.character AND ea.variant = v.variant
LEFT JOIN bundles_array ba ON ba.character = v.character AND ba.variant = v.variant;

COMMIT;
