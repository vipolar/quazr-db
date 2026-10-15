DROP FUNCTION IF EXISTS quazr_upsert_environments(
  VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_environments(
  p_environment     VARCHAR,
  p_display_name    VARCHAR,
  p_time            VARCHAR,
  p_space           VARCHAR,
  p_concept         VARCHAR,
  p_function        VARCHAR,
  p_ecosystem       VARCHAR,
  p_settlement      VARCHAR,
  p_weather         VARCHAR,
  p_default_style   VARCHAR,
  p_description     VARCHAR,
  p_created_at      TIMESTAMPTZ,
  p_updated_at      TIMESTAMPTZ,
  p_starts_at       TIMESTAMPTZ,
  p_ends_at         TIMESTAMPTZ,
  p_tier            VARCHAR
)
RETURNS quazr_environments_wide AS $$
DECLARE
  v_quazr_environment quazr_environments;
  v_result quazr_environments_wide;
  v_created_at timestamptz;
BEGIN
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_environments (
    environment, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_environment, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (environment) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_environments.created_at = p_created_at
  RETURNING * INTO v_quazr_environment;

  IF v_quazr_environment IS NULL THEN
    SELECT created_at FROM quazr_environments WHERE environment = p_environment INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_environments.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_environment, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  INSERT INTO quazr_environment_attribute_values (environment, attribute, value)
  SELECT p_environment, 'time'::quazr_environment_attribute, p_time::quazr_environment_attribute_time::text
  UNION ALL
  SELECT p_environment, 'space'::quazr_environment_attribute, p_space::quazr_environment_attribute_space::text
  UNION ALL
  SELECT p_environment, 'concept'::quazr_environment_attribute, p_concept::quazr_environment_attribute_concept::text
  UNION ALL
  SELECT p_environment, 'function'::quazr_environment_attribute, p_function::quazr_environment_attribute_function::text
  UNION ALL
  SELECT p_environment, 'ecosystem'::quazr_environment_attribute, p_ecosystem::quazr_environment_attribute_ecosystem::text
  UNION ALL
  SELECT p_environment, 'settlement'::quazr_environment_attribute, p_settlement::quazr_environment_attribute_settlement::text
  UNION ALL
  SELECT p_environment, 'weather'::quazr_environment_attribute, p_weather::quazr_environment_attribute_weather::text
  UNION ALL
  SELECT p_environment, 'style'::quazr_environment_attribute, p_default_style::quazr_environment_attribute_style::text
  ON CONFLICT (environment, attribute) DO UPDATE SET
    value = EXCLUDED.value;

  --SELECT * INTO v_result FROM quazr_environments_wide WHERE environment = p_environment;
  v_result := ROW(
    v_quazr_environment.environment,
    v_quazr_environment.display_name,

    p_time,
    p_space,
    p_concept,
    p_function,
    p_ecosystem,
    p_settlement,
    p_weather,
    p_default_style,

    v_quazr_environment.description,
    v_quazr_environment.created_at,
    v_quazr_environment.updated_at,
    v_quazr_environment.starts_at,
    v_quazr_environment.ends_at,
    v_quazr_environment.tier
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

--STYLES
DROP FUNCTION IF EXISTS quazr_upsert_environment_styles(
  VARCHAR, VARCHAR, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_environment_styles(
  p_style           VARCHAR,
  p_display_name    VARCHAR,
  p_description     VARCHAR,
  p_created_at      TIMESTAMPTZ,
  p_updated_at      TIMESTAMPTZ,
  p_starts_at       TIMESTAMPTZ,
  p_ends_at         TIMESTAMPTZ,
  p_tier            VARCHAR
)
RETURNS quazr_environment_styles AS $$
DECLARE
  v_result quazr_environment_styles;
  v_created_at timestamptz;
BEGIN
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_environment_styles (
    style, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_style, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (style) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_environment_styles.created_at = p_created_at
  RETURNING * INTO v_result;

  IF v_result IS NULL THEN
    SELECT created_at FROM quazr_environment_styles WHERE style = p_style INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_environment_styles.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_style, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

--DESCRIPTIONS
DROP FUNCTION IF EXISTS quazr_upsert_environment_descriptions(
  VARCHAR, VARCHAR, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_environment_descriptions(
  p_environment     VARCHAR,
  p_style           VARCHAR,
  p_description     VARCHAR,
  p_created_at      TIMESTAMPTZ,
  p_updated_at      TIMESTAMPTZ,
  p_starts_at       TIMESTAMPTZ,
  p_ends_at         TIMESTAMPTZ,
  p_tier            VARCHAR
)
RETURNS quazr_environment_descriptions AS $$
DECLARE
  v_result quazr_environment_descriptions;
  v_created_at timestamptz;
BEGIN
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_environment_descriptions (
    environment, style, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_environment, p_style, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (environment, style) DO UPDATE SET
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_environment_descriptions.created_at = p_created_at
  RETURNING * INTO v_result;

  IF v_result IS NULL THEN
    SELECT created_at FROM quazr_environment_descriptions WHERE environment = p_environment AND style = p_style INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_environment_descriptions.%.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_environment, p_style, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
