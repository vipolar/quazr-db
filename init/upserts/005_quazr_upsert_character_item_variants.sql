DROP FUNCTION IF EXISTS quazr_upsert_character_item_variants(
  VARCHAR, UUID, VARCHAR, VARCHAR, JSONB, VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], JSONB, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR[], VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_character_item_variants(
  p_item                  VARCHAR,
  p_variant               UUID,
  p_display_name          VARCHAR,
  p_description           VARCHAR,
  p_character_variants    JSONB,

  p_environment           VARCHAR[],

  p_time                  VARCHAR[],
  p_space                 VARCHAR[],
  p_concept               VARCHAR[],
  p_function              VARCHAR[],
  p_ecosystem             VARCHAR[],
  p_settlement            VARCHAR[],
  p_weather               VARCHAR[],
  p_style                 VARCHAR[],

  p_equipment_slots       JSONB,

  p_created_at            TIMESTAMPTZ,
  p_updated_at            TIMESTAMPTZ,
  p_starts_at             TIMESTAMPTZ,
  p_ends_at               TIMESTAMPTZ,
  p_bundle                VARCHAR[],
  p_tier                  VARCHAR
)
RETURNS quazr_character_item_variants_wide AS $$
DECLARE
  v_quazr_character_item_variant quazr_character_item_variants;
  v_result quazr_character_item_variants_wide;
  v_created_at timestamptz;
  v_variant UUID;
BEGIN
  v_variant := COALESCE(p_variant, gen_random_uuid());
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_character_item_variants (
    item, variant, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_item, v_variant, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (item, variant) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_character_item_variants.created_at = p_created_at
    AND quazr_character_item_variants.variant = p_variant
  RETURNING * INTO v_quazr_character_item_variant;

  IF v_quazr_character_item_variant IS NULL THEN
    IF p_variant <> v_variant THEN
      RAISE EXCEPTION 'Data integrity violation: Record "v_quazr_character_item_variant.%.%" update rejected due to a UUID collision (Hurray for the cosmically unlikely event of a UUID collision!)',
        p_item, p_variant
      USING ERRCODE = '23514';
    END IF;

    SELECT created_at FROM v_quazr_character_item_variant WHERE item = p_item AND variant = p_variant INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "v_quazr_character_item_variant.%.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_item, p_variant, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  DELETE FROM quazr_character_item_variant_character_variant cv
  WHERE cv.item = p_item AND cv.item_variant = v_variant;
  WITH expanded_char AS (
    SELECT
      p_item AS item,
      v_variant AS item_variant,
      j.key   AS character,
      jsonb_array_elements_text(j.value) AS character_variant_text
    FROM jsonb_each(COALESCE(p_character_variants, '{}'::jsonb)) AS j(key, value)
  )
  INSERT INTO quazr_character_item_variant_character_variant (item, item_variant, character, character_variant)
  SELECT
    ec.item,
    ec.item_variant,
    ec.character,
    ec.character_variant_text::uuid
  FROM expanded_char ec
  ON CONFLICT (item, item_variant, character, character_variant) DO NOTHING;

  DELETE FROM quazr_character_item_variant_environments e
  WHERE e.item = p_item AND e.variant = v_variant;
  INSERT INTO quazr_character_item_variant_environments (item, variant, environment)
  SELECT
    p_item,
    v_variant,
    unnest(p_environment) AS environment
  WHERE COALESCE(array_length(p_environment, 1), 0) > 0
  ON CONFLICT DO NOTHING;

  DELETE FROM quazr_character_item_variant_attribute_values av
  WHERE av.item = p_item AND av.variant = v_variant;
  INSERT INTO quazr_character_item_variant_attribute_values (item, variant, attribute, value)
  SELECT p_item, v_variant, 'time'::quazr_environment_attribute, unnest(p_time)::quazr_environment_attribute_time::text
  WHERE COALESCE(array_length(p_time, 1), 0) > 0
  UNION ALL
  SELECT p_item, v_variant, 'space'::quazr_environment_attribute, unnest(p_space)::quazr_environment_attribute_space::text
  WHERE COALESCE(array_length(p_space, 1), 0) > 0
  UNION ALL
  SELECT p_item, v_variant, 'concept'::quazr_environment_attribute, unnest(p_concept)::quazr_environment_attribute_concept::text
  WHERE COALESCE(array_length(p_concept, 1), 0) > 0
  UNION ALL
  SELECT p_item, v_variant, 'function'::quazr_environment_attribute, unnest(p_function)::quazr_environment_attribute_function::text
  WHERE COALESCE(array_length(p_function, 1), 0) > 0
  UNION ALL
  SELECT p_item, v_variant, 'ecosystem'::quazr_environment_attribute, unnest(p_ecosystem)::quazr_environment_attribute_ecosystem::text
  WHERE COALESCE(array_length(p_ecosystem, 1), 0) > 0
  UNION ALL
  SELECT p_item, v_variant, 'settlement'::quazr_environment_attribute, unnest(p_settlement)::quazr_environment_attribute_settlement::text
  WHERE COALESCE(array_length(p_settlement, 1), 0) > 0
  UNION ALL
  SELECT p_item, v_variant, 'weather'::quazr_environment_attribute, unnest(p_weather)::quazr_environment_attribute_weather::text
  WHERE COALESCE(array_length(p_weather, 1), 0) > 0
  UNION ALL
  SELECT p_item, v_variant, 'style'::quazr_environment_attribute, unnest(p_style)::quazr_environment_attribute_style::text
  WHERE COALESCE(array_length(p_style, 1), 0) > 0
  ON CONFLICT (item, variant, attribute, value) DO NOTHING;

  DELETE FROM quazr_character_item_variant_slot_attachment_modes m
  WHERE m.item = p_item AND m.variant = v_variant;
  WITH expanded AS (
    SELECT
      p_item AS item,
      v_variant AS variant,
      am.key::quazr_character_item_slot_attachment_mode AS attachment_mode,
      am.value::jsonb AS preposition_map
    FROM jsonb_each(COALESCE(p_equipment_slots, '{}'::jsonb)) AS am(key, value)
  ),
  expanded2 AS (
    SELECT
      e.item,
      e.variant,
      e.attachment_mode,
      p.key::quazr_character_item_slot_preposition AS preposition,
      p.value AS slots_array
    FROM expanded e
    CROSS JOIN LATERAL jsonb_each(e.preposition_map) AS p(key, value)
  ),
  expanded3 AS (
    SELECT
      e2.item,
      e2.variant,
      e2.attachment_mode,
      e2.preposition,
      jsonb_array_elements_text(e2.slots_array) AS slot_text
    FROM expanded2 e2
  ),
  tmp_expanded_cast AS (
    SELECT
      item,
      variant,
      attachment_mode,
      preposition,
      slot_text::quazr_character_item_slot AS slot
    FROM expanded3
    WHERE slot_text IS NOT NULL AND slot_text <> ''
  ),
  insert_slots AS (
    INSERT INTO quazr_character_item_variant_slots (item, variant, slot)
    SELECT DISTINCT item, variant, slot FROM tmp_expanded_cast
    ON CONFLICT DO NOTHING
    RETURNING 1
  ),
  insert_preps AS (
    INSERT INTO quazr_character_item_variant_slot_prepositions (item, variant, slot, preposition)
    SELECT DISTINCT item, variant, slot, preposition FROM tmp_expanded_cast
    ON CONFLICT DO NOTHING
    RETURNING 1
  )
  INSERT INTO quazr_character_item_variant_slot_attachment_modes (item, variant, slot, preposition, attachment_mode)
  SELECT DISTINCT item, variant, slot, preposition, attachment_mode FROM tmp_expanded_cast
  ON CONFLICT DO NOTHING;

  DELETE FROM quazr_character_item_variant_r_bundles b
  WHERE b.item = p_item AND b.variant = v_variant;
  INSERT INTO quazr_character_item_variant_r_bundles (item, variant, bundle)
  SELECT
    p_item,
    v_variant,
    unnest(p_bundle) AS bundle
  WHERE COALESCE(array_length(p_bundle, 1), 0) > 0
  ON CONFLICT DO NOTHING;

  --SELECT * INTO v_result FROM quazr_character_item_variants_wide WHERE item = p_item AND variant = v_variant;
  v_result := ROW(
    v_quazr_character_item_variant.item,
    v_quazr_character_item_variant.variant,
    v_quazr_character_item_variant.display_name,
    v_quazr_character_item_variant.description,

    p_character_variants,

    p_environment,
    p_time,
    p_space,
    p_concept,
    p_function,
    p_ecosystem,
    p_settlement,
    p_weather,
    p_style,

    p_equipment_slots,

    v_quazr_character_item_variant.created_at,
    v_quazr_character_item_variant.updated_at,
    v_quazr_character_item_variant.starts_at,
    v_quazr_character_item_variant.ends_at,

    p_bundle,

    v_quazr_character_item_variant.tier
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
