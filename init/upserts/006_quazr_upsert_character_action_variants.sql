DROP FUNCTION IF EXISTS quazr_upsert_character_action_variants(
  VARCHAR, UUID, VARCHAR, VARCHAR, JSONB, JSONB, VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR[], VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_character_action_variants(
  p_action                   VARCHAR,
  p_variant                  UUID,
  p_display_name             VARCHAR,
  p_description              VARCHAR,
  p_character_variants       JSONB,
  p_character_item_variants  JSONB,

  p_environment              VARCHAR[],

  p_time                     VARCHAR[],
  p_space                    VARCHAR[],
  p_concept                  VARCHAR[],
  p_function                 VARCHAR[],
  p_ecosystem                VARCHAR[],
  p_settlement               VARCHAR[],
  p_weather                  VARCHAR[],
  p_style                    VARCHAR[],

  p_created_at               TIMESTAMPTZ,
  p_updated_at               TIMESTAMPTZ,
  p_starts_at                TIMESTAMPTZ,
  p_ends_at                  TIMESTAMPTZ,
  p_bundle                   VARCHAR[],
  p_tier                     VARCHAR
)
RETURNS quazr_character_action_variants_wide AS $$
DECLARE
  v_quazr_character_action_variant quazr_character_action_variants;
  v_result quazr_character_action_variants_wide;
  v_created_at timestamptz;
  v_variant UUID;
BEGIN
  v_variant := COALESCE(p_variant, gen_random_uuid());
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_character_action_variants (
    action, variant, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_action, v_variant, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (action, variant) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_character_action_variants.created_at = p_created_at
    AND quazr_character_action_variants.variant = p_variant
  RETURNING * INTO v_quazr_character_action_variant;

  IF v_quazr_character_action_variant IS NULL THEN
    IF p_variant <> v_variant THEN
      RAISE EXCEPTION 'Data integrity violation: Record "v_quazr_character_action_variant.%.%" update rejected due to a UUID collision (Hurray for the cosmically unlikely event of a UUID collision!)',
        p_action, p_variant
      USING ERRCODE = '23514';
    END IF;

    SELECT created_at FROM v_quazr_character_action_variant WHERE action = p_action AND variant = p_variant INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "v_quazr_character_action_variant.%.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_action, p_variant, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  DELETE FROM quazr_character_action_variant_character_variant cv
  WHERE cv.action = p_action AND cv.action_variant = v_variant;
  WITH expanded_char AS (
    SELECT
      p_action AS action,
      v_variant AS action_variant,
      j.key   AS character,
      jsonb_array_elements_text(j.value) AS character_variant_text
    FROM jsonb_each(COALESCE(p_character_variants, '{}'::jsonb)) AS j(key, value)
  )
  INSERT INTO quazr_character_action_variant_character_variant (action, action_variant, character, character_variant)
  SELECT
    ec.action,
    ec.action_variant,
    ec.character,
    ec.character_variant_text::uuid
  FROM expanded_char ec
  ON CONFLICT (action, action_variant, character, character_variant) DO NOTHING;

  DELETE FROM quazr_character_action_variant_character_item_variant cv
  WHERE cv.action = p_action AND cv.action_variant = v_variant;
  WITH expanded_char AS (
    SELECT
      p_action AS action,
      v_variant AS action_variant,
      j.key AS item,
      jsonb_array_elements_text(j.value) AS item_variant_text
    FROM jsonb_each(COALESCE(p_character_item_variants, '{}'::jsonb)) AS j(key, value)
  )
  INSERT INTO quazr_character_action_variant_character_item_variant (action, action_variant, item, item_variant)
  SELECT
    ec.action,
    ec.action_variant,
    ec.item,
    ec.item_variant_text::uuid
  FROM expanded_char ec
  ON CONFLICT (action, action_variant, item, item_variant) DO NOTHING;

  DELETE FROM quazr_character_action_variant_environments e
  WHERE e.action = p_action AND e.variant = v_variant;
  INSERT INTO quazr_character_action_variant_environments (action, variant, environment)
  SELECT
    p_action,
    v_variant,
    unnest(p_environment) AS environment
  WHERE COALESCE(array_length(p_environment, 1), 0) > 0
  ON CONFLICT DO NOTHING;

  DELETE FROM quazr_character_action_variant_attribute_values av
  WHERE av.action = p_action AND av.variant = v_variant;
  INSERT INTO quazr_character_action_variant_attribute_values (action, variant, attribute, value)
  SELECT p_action, v_variant, 'time'::quazr_environment_attribute, unnest(p_time)::quazr_environment_attribute_time::text
  WHERE COALESCE(array_length(p_time, 1), 0) > 0
  UNION ALL
  SELECT p_action, v_variant, 'space'::quazr_environment_attribute, unnest(p_space)::quazr_environment_attribute_space::text
  WHERE COALESCE(array_length(p_space, 1), 0) > 0
  UNION ALL
  SELECT p_action, v_variant, 'concept'::quazr_environment_attribute, unnest(p_concept)::quazr_environment_attribute_concept::text
  WHERE COALESCE(array_length(p_concept, 1), 0) > 0
  UNION ALL
  SELECT p_action, v_variant, 'function'::quazr_environment_attribute, unnest(p_function)::quazr_environment_attribute_function::text
  WHERE COALESCE(array_length(p_function, 1), 0) > 0
  UNION ALL
  SELECT p_action, v_variant, 'ecosystem'::quazr_environment_attribute, unnest(p_ecosystem)::quazr_environment_attribute_ecosystem::text
  WHERE COALESCE(array_length(p_ecosystem, 1), 0) > 0
  UNION ALL
  SELECT p_action, v_variant, 'settlement'::quazr_environment_attribute, unnest(p_settlement)::quazr_environment_attribute_settlement::text
  WHERE COALESCE(array_length(p_settlement, 1), 0) > 0
  UNION ALL
  SELECT p_action, v_variant, 'weather'::quazr_environment_attribute, unnest(p_weather)::quazr_environment_attribute_weather::text
  WHERE COALESCE(array_length(p_weather, 1), 0) > 0
  UNION ALL
  SELECT p_action, v_variant, 'style'::quazr_environment_attribute, unnest(p_style)::quazr_environment_attribute_style::text
  WHERE COALESCE(array_length(p_style, 1), 0) > 0
  ON CONFLICT (action, variant, attribute, value) DO NOTHING;

  DELETE FROM quazr_character_action_variant_r_bundles b
  WHERE b.action = p_action AND b.variant = v_variant;
  INSERT INTO quazr_character_action_variant_r_bundles (action, variant, bundle)
  SELECT
    p_action,
    v_variant,
    unnest(p_bundle) AS bundle
  WHERE COALESCE(array_length(p_bundle, 1), 0) > 0
  ON CONFLICT DO NOTHING;

  --SELECT * INTO v_result FROM quazr_character_action_variants_wide WHERE action = p_action AND variant = v_variant;
  v_result := ROW(
    v_quazr_character_action_variant.action,
    v_quazr_character_action_variant.variant,
    v_quazr_character_action_variant.display_name,
    v_quazr_character_action_variant.description,

    p_character_variants,
    p_character_item_variants,

    p_environment,
    p_time,
    p_space,
    p_concept,
    p_function,
    p_ecosystem,
    p_settlement,
    p_weather,
    p_style,

    v_quazr_character_action_variant.created_at,
    v_quazr_character_action_variant.updated_at,
    v_quazr_character_action_variant.starts_at,
    v_quazr_character_action_variant.ends_at,

    p_bundle,

    v_quazr_character_action_variant.tier
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
