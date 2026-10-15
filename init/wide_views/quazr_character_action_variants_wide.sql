BEGIN;

CREATE OR REPLACE VIEW quazr_character_action_variants_wide AS
WITH
attr_arrays AS (
  SELECT
    av.action,
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
  FROM quazr_character_action_variant_attribute_values av
  GROUP BY av.action, av.variant
),

char_kv AS (
  SELECT
    cv.action,
    cv.action_variant,
    cv.character,
    ARRAY_AGG(DISTINCT cv.character_variant ORDER BY cv.character_variant) AS variants
  FROM quazr_character_action_variant_character_variant cv
  GROUP BY cv.action, cv.action_variant, cv.character
),
characters_json AS (
  SELECT
    ck.action,
    ck.action_variant,
    jsonb_object_agg(
      ck.character,
      to_jsonb(ck.variants)
      ORDER BY ck.character
    ) AS character_variants
  FROM char_kv ck
  GROUP BY ck.action, ck.action_variant
),

char_item_kv AS (
  SELECT
    cv.action,
    cv.action_variant,
    cv.item,
    ARRAY_AGG(DISTINCT cv.item_variant ORDER BY cv.item_variant) AS variants
  FROM quazr_character_action_variant_character_item_variant cv
  GROUP BY cv.action, cv.action_variant, cv.item
),
character_items_json AS (
  SELECT
    ck.action,
    ck.action_variant,
    jsonb_object_agg(
      ck.item,
      to_jsonb(ck.variants)
      ORDER BY ck.item
    ) AS character_item_variants
  FROM char_item_kv ck
  GROUP BY ck.action, ck.action_variant
),

environments_array AS (
  SELECT
    av.action,
    av.variant,
    ARRAY_AGG(DISTINCT av.environment ORDER BY av.environment) AS environment
  FROM quazr_character_action_variant_environments av
  GROUP BY av.action, av.variant
),

bundles_array AS (
  SELECT
    av.action,
    av.variant,
    ARRAY_AGG(DISTINCT av.bundle ORDER BY av.bundle) AS bundle
  FROM quazr_character_action_variant_r_bundles av
  GROUP BY av.action, av.variant
)

SELECT
  v.action,
  v.variant,
  v.display_name,
  v.description,
  COALESCE(cj.character_variants, '{}'::jsonb) AS character,
  COALESCE(cij.character_item_variants, '{}'::jsonb) AS item,
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

FROM quazr_character_action_variants v
LEFT JOIN attr_arrays aa ON aa.action = v.action AND aa.variant = v.variant
LEFT JOIN characters_json cj ON cj.action = v.action AND cj.action_variant = v.variant
LEFT JOIN character_items_json cij ON cij.action = v.action AND cij.action_variant = v.variant
LEFT JOIN environments_array ea ON ea.action = v.action AND ea.variant = v.variant
LEFT JOIN bundles_array ba ON ba.action = v.action AND ba.variant = v.variant;

COMMIT;
