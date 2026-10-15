CREATE OR REPLACE FUNCTION quizr_upsert_aof_instance_player_characteristics_scores(
  p_quizr varchar,
  p_instance uuid,
  p_user_uuid uuid,
  p_playful integer,
  p_calm integer,
  p_curious integer,
  p_bold integer,
  p_gentle integer,
  p_independent integer,
  p_loyal integer,
  p_silly integer,
  p_adventurous integer,
  p_graceful integer,
  p_created_at timestamptz,
  p_updated_at timestamptz
)
RETURNS quizr_aof_instance_players_wide AS $$
DECLARE
  v_scores quizr_aof_characteristic_question_answer_scores;
  v_result quizr_aof_instance_players_wide;
  v_created_at timestamptz;
  v_matches jsonb;
BEGIN
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quizr_aof_characteristic_question_answer_scores (
    quizr, instance, user_uuid, playful, calm, curious, bold, gentle, independent, loyal, silly, adventurous, graceful, created_at, updated_at
  ) VALUES (
    p_quizr, p_instance, p_user_uuid, p_playful, p_calm, p_curious, p_bold, p_gentle, p_independent, p_loyal, p_silly, p_adventurous, p_graceful, v_created_at, NOW()
  )
  ON CONFLICT (quizr, instance, user_uuid) DO UPDATE SET
    playful = EXCLUDED.playful,
    calm = EXCLUDED.calm,
    curious = EXCLUDED.curious,
    bold = EXCLUDED.bold,
    gentle = EXCLUDED.gentle,
    independent = EXCLUDED.independent,
    loyal = EXCLUDED.loyal,
    silly = EXCLUDED.silly,
    adventurous = EXCLUDED.adventurous,
    graceful = EXCLUDED.graceful,
    updated_at = NOW()
  WHERE quizr_aof_characteristic_question_answer_scores.created_at = p_created_at
  RETURNING * INTO v_scores;

  IF v_scores IS NULL THEN
    SELECT created_at FROM quizr_aof_characteristic_question_answer_scores WHERE quizr = p_quizr AND instance = p_instance AND user_uuid = p_user_uuid INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quizr_aof_characteristic_question_answer_scores.%.%.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_quizr, p_instance, p_user_uuid, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  WITH calculated_matches AS (
    SELECT 
      c.animal,
      (1.0 - ((
        ABS(c.playful::smallint - p_playful::smallint) +
        ABS(c.calm::smallint - p_calm::smallint) +
        ABS(c.curious::smallint - p_curious::smallint) +
        ABS(c.bold::smallint - p_bold::smallint) +
        ABS(c.gentle::smallint - p_gentle::smallint) +
        ABS(c.independent::smallint - p_independent::smallint) +
        ABS(c.loyal::smallint - p_loyal::smallint) +
        ABS(c.silly::smallint - p_silly::smallint) +
        ABS(c.adventurous::smallint - p_adventurous::smallint) +
        ABS(c.graceful::smallint - p_graceful::smallint)
      )::numeric / 20.0)) * 100 AS base_percentage
    FROM quizr_aof_characteristics c
  ),
  jittered_matches AS (
    SELECT 
      cm.animal,
      ROUND(cm.base_percentage + ((('x' || SUBSTR(md5(cm.animal || cm.base_percentage::text), 1, 8))::bit(32)::int::numeric / 2147483647.0 ) * 4.0) - 2.0, 2) AS match_percentage
    FROM calculated_matches cm
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'animal', top_m.animal,
        'match_percentage', top_m.match_percentage
      ) ORDER BY top_m.match_percentage DESC
    ), '[]'::jsonb) INTO v_matches
  FROM (
    --LIMIT 3 is a placeholder and should be replaces by player choice?? or whatever...
    SELECT animal, match_percentage FROM jittered_matches ORDER BY match_percentage DESC LIMIT 3
  ) top_m;

  --THIS NEEDS TO BE REMOVED AND REPLACED WITH SOME SORT OF SOMETHING....
  DELETE FROM quizr_aof_characteristic_question_answer_score_matches
    WHERE quizr = p_quizr 
      AND instance = p_instance 
      AND user_uuid = p_user_uuid;

  INSERT INTO quizr_aof_characteristic_question_answer_score_matches(
    quizr, instance, user_uuid, animal, match_percentage
  ) SELECT 
    p_quizr, p_instance, p_user_uuid, m.animal, m.match_percentage
  FROM jsonb_to_recordset(v_matches) AS m(animal varchar(32), match_percentage numeric);

  v_result := (
    v_scores.quizr,
    v_scores.instance,
    v_scores.user_uuid,
    v_scores.playful,
    v_scores.calm,
    v_scores.curious,
    v_scores.bold,
    v_scores.gentle,
    v_scores.independent,
    v_scores.loyal,
    v_scores.silly,
    v_scores.adventurous,
    v_scores.graceful,
    v_matches,
    v_scores.created_at,
    v_scores.updated_at
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
