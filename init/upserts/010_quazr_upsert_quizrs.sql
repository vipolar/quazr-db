DROP FUNCTION IF EXISTS quazr_upsert_quizrs(
  VARCHAR, VARCHAR, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, VARCHAR
);
CREATE OR REPLACE FUNCTION quazr_upsert_quizrs(
  p_quizr          VARCHAR,
  p_display_name   VARCHAR,
  p_description    VARCHAR,
  p_created_at     TIMESTAMPTZ,
  p_updated_at     TIMESTAMPTZ,
  p_starts_at      TIMESTAMPTZ,
  p_ends_at        TIMESTAMPTZ,
  p_tier           VARCHAR
) 
RETURNS quazr_quizrs AS $$
DECLARE
  v_created_at timestamptz;
  v_result quazr_quizrs;
BEGIN
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_quizrs (
    quizr, display_name, description, created_at, starts_at, ends_at, tier
  ) VALUES (
    p_quizr, p_display_name, p_description, v_created_at, p_starts_at, p_ends_at, p_tier::quazr_rewards_rarity_tier
  )
  ON CONFLICT (quizr) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description  = EXCLUDED.description,
    starts_at    = EXCLUDED.starts_at,
    ends_at      = EXCLUDED.ends_at,
    tier         = EXCLUDED.tier,
    updated_at   = NOW()
  WHERE quazr_quizrs.created_at = p_created_at
  RETURNING * INTO v_result;

  IF v_result IS NULL THEN
    SELECT created_at FROM quazr_quizrs WHERE quizr = p_quizr INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_quizrs.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_quizr, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

--INSTANCES --WIP (NEEDS TO BE BETTER UNDERSTOOD WHAT WE ARE ACTUALLY TRYING TO ACHIEVE HERE (FOR NOW IT WORKS BUT IT IS NOT IDEAL))
DROP FUNCTION IF EXISTS quazr_upsert_quizr_instances(
  VARCHAR, UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ
);
CREATE OR REPLACE FUNCTION quazr_upsert_quizr_instances(
  p_quizr          VARCHAR,
  p_instance       UUID,
  p_created_by     UUID,
  p_created_at     TIMESTAMPTZ,
  p_concluded_at   TIMESTAMPTZ
)
RETURNS quazr_quizr_instances_wide AS $$
DECLARE
  v_quizr_instance_player quazr_quizr_instance_players;
  v_quizr_instance_players_json_array jsonb;
  v_quizr_instance quazr_quizr_instances;
  v_result quazr_quizr_instances_wide;
  v_created_by uuid;
  v_instance uuid;
BEGIN
  IF p_created_by IS NOT NULL THEN
    v_created_by := p_created_by;
  ELSE
    INSERT INTO quazr_users(
      username
    ) VALUES (
      'New Player'
    )
    RETURNING user_uuid INTO v_created_by;
  END IF;

  IF p_created_at IS NULL THEN
    INSERT INTO quazr_quizr_instances (
      quizr, created_by
    ) VALUES (
      p_quizr, v_created_by
    )
    RETURNING * INTO v_quizr_instance;
  ELSE
    INSERT INTO quazr_quizr_instances (
      quizr, instance, created_by, created_at, concluded_at
    ) VALUES (
      p_quizr, p_instance, v_created_by, p_created_at, p_concluded_at
    )
    ON CONFLICT (quizr, instance) DO NOTHING
    RETURNING * INTO v_quizr_instance;
  END IF;

  IF v_quizr_instance IS NULL THEN
    SELECT * FROM quazr_quizr_instances WHERE quizr = p_quizr AND instance = p_instance INTO v_quizr_instance;
  END IF;

  v_instance := v_quizr_instance.instance;
  IF p_created_at IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(to_jsonb(p)), '[]'::jsonb) INTO v_quizr_instance_players_json_array
      FROM quazr_quizr_instance_players p WHERE quizr = p_quizr AND instance = v_instance;
  ELSE
    INSERT INTO quazr_quizr_instance_players (
      quizr, instance, user_uuid
    ) VALUES (
      p_quizr, v_instance, v_created_by
    )
    RETURNING * INTO v_quizr_instance_player;
    v_quizr_instance_players_json_array := jsonb_build_array(to_jsonb(v_quizr_instance_player));
  END IF;

  --SELECT * FROM quazr_quizr_instances_wide WHERE quizr = p_quizr AND instance = v_instance INTO v_result;
  v_result := ROW(
    v_quizr_instance.quizr,
    v_quizr_instance.instance,
    v_quizr_instance.created_by,
    v_quizr_instance_players_json_array,
    v_quizr_instance.created_at,
    v_quizr_instance.concluded_at
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

--PLAYERS
DROP FUNCTION IF EXISTS quazr_upsert_quizr_instance_players(
  VARCHAR, UUID, UUID, UUID, UUID, UUID, VARCHAR, VARCHAR, VARCHAR, TIMESTAMPTZ, TIMESTAMPTZ
);
CREATE OR REPLACE FUNCTION quazr_upsert_quizr_instance_players(
  p_quizr             VARCHAR,
  p_instance          UUID,
  p_user_uuid         UUID,
  p_invited_by        UUID,
  p_avatar_uuid       UUID,
  p_image_uuid        UUID,
  p_nickname          VARCHAR,
  p_descriptor        VARCHAR,
  p_description       VARCHAR,
  p_created_at        TIMESTAMPTZ,
  p_updated_at        TIMESTAMPTZ
) 
RETURNS quazr_quizr_instance_players AS $$
DECLARE
  v_result quazr_quizr_instance_players;
  v_created_at timestamptz;
  v_user_uuid uuid;
BEGIN
  IF p_invited_by IS NULL OR NOT EXISTS (SELECT created_by FROM quazr_quizr_instances WHERE quizr = p_quizr AND instance = p_instance AND created_by = p_invited_by) THEN
    RAISE EXCEPTION 'Permissions violation: Record "quazr_quizr_instances.%.%" and its subsidiaries cannot be update by "%" user',
      p_quizr, p_instance, COALESCE(p_invited_by::text, 'UNAUTHORIZED')
    USING ERRCODE = '23514';
  END IF;

  IF p_user_uuid IS NOT NULL THEN
    v_user_uuid := p_user_uuid;
  ELSE
    INSERT INTO quazr_users (
      username, invited_by
    ) VALUES (
      p_nickname, p_invited_by
    )
    RETURNING user_uuid INTO v_user_uuid;
  END IF;

  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_quizr_instance_players (
    quizr, instance, user_uuid, avatar_uuid, image_uuid, nickname, descriptor, description, created_at
  ) VALUES (
    p_quizr, p_instance, v_user_uuid, p_avatar_uuid, p_image_uuid, p_nickname, p_descriptor, p_description, v_created_at
  )
  ON CONFLICT (quizr, instance, user_uuid) DO UPDATE SET
    avatar_uuid = EXCLUDED.avatar_uuid,
    image_uuid = EXCLUDED.image_uuid,
    nickname = EXCLUDED.nickname,
    descriptor = EXCLUDED.descriptor,
    description = EXCLUDED.description,
    updated_at = NOW()
  WHERE quazr_quizr_instance_players.created_at = p_created_at
  RETURNING * INTO v_result;

  IF v_result IS NULL THEN
    SELECT created_at FROM quazr_quizr_instance_players WHERE quizr = p_quizr AND instance = p_instance AND user_uuid = p_user_uuid INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_quizr_instance_players.%.%.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_quizr, p_instance, p_user_uuid, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
