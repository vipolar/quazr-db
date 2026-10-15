DROP FUNCTION IF EXISTS quazr_upsert_characters(
  VARCHAR, VARCHAR, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_characters(
  p_character      VARCHAR,
  p_display_name   VARCHAR,
  p_description    VARCHAR,
  p_created_at     TIMESTAMPTZ,
  p_updated_at     TIMESTAMPTZ,
  p_starts_at      TIMESTAMPTZ,
  p_ends_at        TIMESTAMPTZ,
  p_tier           VARCHAR
) 
RETURNS quazr_characters AS $$
DECLARE
  v_result quazr_characters;
  v_created_at timestamptz;
BEGIN
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_characters (
    character, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_character, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (character) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_characters.created_at = p_created_at
  RETURNING * INTO v_result;

  IF v_result IS NULL THEN
    SELECT created_at FROM quazr_characters WHERE character = p_character INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_characters.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_character, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

--ITEMS
DROP FUNCTION IF EXISTS quazr_upsert_character_items(
  VARCHAR, VARCHAR, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_character_items(
  p_item           VARCHAR,
  p_display_name   VARCHAR,
  p_description    VARCHAR,
  p_created_at     TIMESTAMPTZ,
  p_updated_at     TIMESTAMPTZ,
  p_starts_at      TIMESTAMPTZ,
  p_ends_at        TIMESTAMPTZ,
  p_tier           VARCHAR
) 
RETURNS quazr_character_items AS $$
DECLARE
  v_result quazr_character_items;
  v_created_at timestamptz;
BEGIN
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_character_items (
    item, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_item, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (item) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_character_items.created_at = p_created_at
  RETURNING * INTO v_result;

  IF v_result IS NULL THEN
    SELECT created_at FROM quazr_character_items WHERE item = p_item INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_character_items.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_item, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

--ACTIONS
DROP FUNCTION IF EXISTS quazr_upsert_character_actions(
  VARCHAR, VARCHAR, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_character_actions(
  p_action         VARCHAR,
  p_display_name   VARCHAR,
  p_description    VARCHAR,
  p_created_at     TIMESTAMPTZ,
  p_updated_at     TIMESTAMPTZ,
  p_starts_at      TIMESTAMPTZ,
  p_ends_at        TIMESTAMPTZ,
  p_tier           VARCHAR
) 
RETURNS quazr_character_actions AS $$
DECLARE
  v_result quazr_character_actions;
  v_created_at timestamptz;
BEGIN
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_character_actions (
    action, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_action, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (action) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_character_actions.created_at = p_created_at
  RETURNING * INTO v_result;

  IF v_result IS NULL THEN
    SELECT created_at FROM quazr_character_actions WHERE action = p_action INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_character_actions.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_action, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
