--INSTANCES --WIP (NEEDS TO BE BETTER UNDERSTOOD WHAT WE ARE ACTUALLY TRYING TO ACHIEVE HERE (FOR NOW IT WORKS BUT IT IS NOT IDEAL))
DROP FUNCTION IF EXISTS quazr_create_quizr_instances(
  VARCHAR, UUID
);
CREATE OR REPLACE FUNCTION quazr_create_quizr_instances(
  p_quizr          VARCHAR,
  p_created_by     UUID
)
RETURNS quazr_quizr_instances_wide AS $$
DECLARE
  v_quizr_instance_player quazr_quizr_instance_players;
  v_quizr_instance_players_json_array jsonb;

  v_quizr_instance quazr_quizr_instances;
  v_result quazr_quizr_instances_wide;
  v_quazr_user quazr_users;

  v_username varchar;
  v_created_by uuid;
  v_instance uuid;
BEGIN
  IF p_created_by IS NOT NULL THEN
    SELECT username, user_uuid FROM quazr_users WHERE user_uuid = p_created_by INTO v_quazr_user;

    IF v_quazr_user IS NULL THEN
      RAISE EXCEPTION 'Data integrity violation: No user found for the provided UUID: %',
        p_created_by
      USING ERRCODE = '23514';
    END IF;
  ELSE
    INSERT INTO quazr_users(
      username
    ) VALUES (
      'New Player'
    )
    RETURNING username, user_uuid INTO v_quazr_user;
  END IF;

  v_created_by := v_quazr_user.user_uuid;
  v_username := v_quazr_user.username;
  INSERT INTO quazr_quizr_instances (
    quizr, created_by
  ) VALUES (
    p_quizr, v_created_by
  )
  RETURNING * INTO v_quizr_instance;

  v_instance := v_quizr_instance.instance;
  INSERT INTO quazr_quizr_instance_players (
    quizr, instance, user_uuid
  ) VALUES (
    p_quizr, v_instance, v_created_by
  )
  RETURNING * INTO v_quizr_instance_player;

  --We will add player pulling logic here later.
  --If they have a template we use it.
  --If they have preferences we use it.
  v_quizr_instance_players_json_array := jsonb_build_array(
    to_jsonb(v_quizr_instance_player) || jsonb_build_object('nickname', to_jsonb(v_username))
  );

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
