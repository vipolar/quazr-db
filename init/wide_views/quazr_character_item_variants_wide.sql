BEGIN;

CREATE OR REPLACE VIEW quazr_character_item_variants_wide AS
WITH
attr_arrays AS (
  SELECT
    av.item,
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
  FROM quazr_character_item_variant_attribute_values av
  GROUP BY av.item, av.variant
),

char_kv AS (
  SELECT
    cv.item,
    cv.item_variant,
    cv.character,
    ARRAY_AGG(DISTINCT cv.character_variant ORDER BY cv.character_variant) AS variants
  FROM quazr_character_item_variant_character_variant cv
  GROUP BY cv.item, cv.item_variant, cv.character
),
characters_json AS (
  SELECT
    ck.item,
    ck.item_variant,
    jsonb_object_agg(
      ck.character,
      to_jsonb(ck.variants)
      ORDER BY ck.character
    ) AS character_variants
  FROM char_kv ck
  GROUP BY ck.item, ck.item_variant
),

environments_array AS (
  SELECT
    av.item,
    av.variant,
    ARRAY_AGG(DISTINCT av.environment ORDER BY av.environment) AS environment
  FROM quazr_character_item_variant_environments av
  GROUP BY av.item, av.variant
),

bundles_array AS (
  SELECT
    av.item,
    av.variant,
    ARRAY_AGG(DISTINCT av.bundle ORDER BY av.bundle) AS bundle
  FROM quazr_character_item_variant_r_bundles av
  GROUP BY av.item, av.variant
),

slot_rows AS (
  SELECT
    am.item,
    am.variant,
    am.attachment_mode,
    am.preposition,
    ARRAY_AGG(
      DISTINCT am.slot::quazr_character_item_slot 
      ORDER BY am.slot::quazr_character_item_slot
    ) AS slot_rows
  FROM quazr_character_item_variant_slot_attachment_modes am
  GROUP BY am.item, am.variant, am.attachment_mode, am.preposition
),

slot_level_json AS (
  SELECT
    sr.item,
    sr.variant,
    sr.attachment_mode,
    jsonb_object_agg(
      sr.preposition::quazr_character_item_slot_preposition,
      COALESCE(to_jsonb(sr.slot_rows), '[]'::jsonb)
      ORDER BY sr.preposition::quazr_character_item_slot_preposition
    ) AS preposition_map
  FROM slot_rows sr
  GROUP BY sr.item, sr.variant, sr.attachment_mode
),

slots_json AS (
  SELECT
    slj.item,
    slj.variant,
    jsonb_object_agg(
      slj.attachment_mode::quazr_character_item_slot_attachment_mode,
      COALESCE(slj.preposition_map, '{}'::jsonb)
      ORDER BY slj.attachment_mode::quazr_character_item_slot_attachment_mode
    ) AS slot
  FROM slot_level_json slj
  GROUP BY slj.item, slj.variant
)

SELECT
  v.item,
  v.variant,
  v.display_name,
  v.description,
  COALESCE(cj.character_variants, '{}'::jsonb) AS character,
  COALESCE(ea.environment, ARRAY[]::varchar[]) AS environment,
  COALESCE(aa.time, ARRAY[]::quazr_environment_attribute_time[]) AS time,
  COALESCE(aa.space, ARRAY[]::quazr_environment_attribute_space[]) AS space,
  COALESCE(aa.concept, ARRAY[]::quazr_environment_attribute_concept[]) AS concept,
  COALESCE(aa.function, ARRAY[]::quazr_environment_attribute_function[]) AS function,
  COALESCE(aa.ecosystem, ARRAY[]::quazr_environment_attribute_ecosystem[]) AS ecosystem,
  COALESCE(aa.settlement, ARRAY[]::quazr_environment_attribute_settlement[]) AS settlement,
  COALESCE(aa.weather, ARRAY[]::quazr_environment_attribute_weather[]) AS weather,
  COALESCE(aa.style, ARRAY[]::quazr_environment_attribute_style[]) AS style,
  COALESCE(sj.slot, '{}'::jsonb) AS equipment_slots,
  v.created_at,
  v.updated_at,
  v.starts_at,
  v.ends_at,
  COALESCE(ba.bundle, ARRAY[]::varchar[]) AS bundle,
  v.tier

FROM quazr_character_item_variants v
LEFT JOIN attr_arrays aa ON aa.item = v.item AND aa.variant = v.variant
LEFT JOIN characters_json cj ON cj.item = v.item AND cj.item_variant = v.variant
LEFT JOIN environments_array ea ON ea.item = v.item AND ea.variant = v.variant
LEFT JOIN bundles_array ba ON ba.item = v.item AND ba.variant = v.variant
LEFT JOIN slots_json  sj ON sj.item = v.item AND sj.variant = v.variant;

COMMIT;
