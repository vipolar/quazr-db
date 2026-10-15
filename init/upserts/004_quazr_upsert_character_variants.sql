DROP FUNCTION IF EXISTS quazr_upsert_character_variants(
  VARCHAR, UUID, VARCHAR, VARCHAR, VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], VARCHAR[], TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR[], VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_character_variants(
  p_character     VARCHAR,
  p_variant       UUID,
  p_display_name  VARCHAR,
  p_description   VARCHAR,
  p_environment   VARCHAR[],

  p_time          VARCHAR[],
  p_space         VARCHAR[],
  p_concept       VARCHAR[],
  p_function      VARCHAR[],
  p_ecosystem     VARCHAR[],
  p_settlement    VARCHAR[],
  p_weather       VARCHAR[],
  p_style         VARCHAR[],

  p_created_at    TIMESTAMPTZ,
  p_updated_at    TIMESTAMPTZ,
  p_starts_at     TIMESTAMPTZ,
  p_ends_at       TIMESTAMPTZ,
  p_bundle        VARCHAR[],
  p_tier          VARCHAR
) 
RETURNS quazr_character_variants_wide AS $$
DECLARE
  v_quazr_character_variant quazr_character_variants;
  v_result quazr_character_variants_wide;
  v_created_at timestamptz;
  v_variant UUID;
BEGIN
  v_variant := COALESCE(p_variant, gen_random_uuid());
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_character_variants (
    character, variant, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_character, v_variant, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (character, variant) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_character_variants.created_at = p_created_at
    AND quazr_character_variants.variant = p_variant
  RETURNING * INTO v_quazr_character_variant;

  IF v_quazr_character_variant IS NULL THEN
    IF p_variant <> v_variant THEN
      RAISE EXCEPTION 'Data integrity violation: Record "quazr_character_variants.%.%" update rejected due to a UUID collision (Hurray for the cosmically unlikely event of a UUID collision!)',
        p_character, p_variant
      USING ERRCODE = '23514';
    END IF;

    SELECT created_at FROM quazr_character_variants WHERE character = p_character AND variant = p_variant INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_character_variants.%.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_character, p_variant, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  DELETE FROM quazr_character_variant_environments e
  WHERE e.character = p_character AND e.variant = v_variant;
  IF COALESCE(array_length(p_environment, 1), 0) > 0 THEN
    INSERT INTO quazr_character_variant_environments(
      character, variant, environment
    ) VALUES (
      p_character, v_variant, unnest(p_environment)
    )
    ON CONFLICT (character, variant, environment) DO NOTHING;
  END IF;

  DELETE FROM quazr_character_variant_attribute_values av
  WHERE av.character = p_character AND av.variant = v_variant;
  INSERT INTO quazr_character_variant_attribute_values (character, variant, attribute, value)
  SELECT p_character, v_variant, 'time'::quazr_environment_attribute, unnest(p_time)::quazr_environment_attribute_time::text
  WHERE COALESCE(array_length(p_time, 1), 0) > 0
  UNION ALL
  SELECT p_character, v_variant, 'space'::quazr_environment_attribute, unnest(p_space)::quazr_environment_attribute_space::text
  WHERE COALESCE(array_length(p_space, 1), 0) > 0
  UNION ALL
  SELECT p_character, v_variant, 'concept'::quazr_environment_attribute, unnest(p_concept)::quazr_environment_attribute_concept::text
  WHERE COALESCE(array_length(p_concept, 1), 0) > 0
  UNION ALL
  SELECT p_character, v_variant, 'function'::quazr_environment_attribute, unnest(p_function)::quazr_environment_attribute_function::text
  WHERE COALESCE(array_length(p_function, 1), 0) > 0
  UNION ALL
  SELECT p_character, v_variant, 'ecosystem'::quazr_environment_attribute, unnest(p_ecosystem)::quazr_environment_attribute_ecosystem::text
  WHERE COALESCE(array_length(p_ecosystem, 1), 0) > 0
  UNION ALL
  SELECT p_character, v_variant, 'settlement'::quazr_environment_attribute, unnest(p_settlement)::quazr_environment_attribute_settlement::text
  WHERE COALESCE(array_length(p_settlement, 1), 0) > 0
  UNION ALL
  SELECT p_character, v_variant, 'weather'::quazr_environment_attribute, unnest(p_weather)::quazr_environment_attribute_weather::text
  WHERE COALESCE(array_length(p_weather, 1), 0) > 0
  UNION ALL
  SELECT p_character, v_variant, 'style'::quazr_environment_attribute, unnest(p_style)::quazr_environment_attribute_style::text
  WHERE COALESCE(array_length(p_style, 1), 0) > 0
  ON CONFLICT (character, variant, attribute, value) DO NOTHING;

  DELETE FROM quazr_character_variant_r_bundles b
  WHERE b.character = p_character AND b.variant = v_variant;
  INSERT INTO quazr_character_variant_r_bundles (character, variant, bundle)
  SELECT p_character, v_variant, unnest(p_bundle) AS bundle
  WHERE COALESCE(array_length(p_bundle, 1), 0) > 0
  ON CONFLICT DO NOTHING;

  --SELECT * INTO v_result FROM quazr_character_variants_wide WHERE character = p_character AND variant = v_variant;
  v_result := ROW(
    v_quazr_character_variant.character,
    v_quazr_character_variant.variant,
    v_quazr_character_variant.display_name,
    v_quazr_character_variant.description,

    p_environment,
    p_time,
    p_space,
    p_concept,
    p_function,
    p_ecosystem,
    p_settlement,
    p_weather,
    p_style,

    v_quazr_character_variant.created_at,
    v_quazr_character_variant.updated_at,
    v_quazr_character_variant.starts_at,
    v_quazr_character_variant.ends_at,

    p_bundle,

    v_quazr_character_variant.tier
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
