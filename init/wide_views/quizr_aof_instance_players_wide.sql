CREATE OR REPLACE VIEW quizr_aof_instance_players_wide AS
SELECT 
  s.quizr,
  s.instance,
  s.user_uuid,
  s.playful,
  s.calm,
  s.curious,
  s.bold,
  s.gentle,
  s.independent,
  s.loyal,
  s.silly,
  s.adventurous,
  s.graceful,
  COALESCE(m.matches, '[]'::jsonb) AS matches,
  s.created_at,
  s.updated_at
FROM quizr_aof_characteristic_question_answer_scores s
LEFT JOIN (
  SELECT 
    quizr, 
    instance, 
    user_uuid,
    jsonb_agg(
      jsonb_build_object(
        'animal', animal,
        'match_percentage', match_percentage
      )
      ORDER BY match_percentage DESC
    ) AS matches
  FROM quizr_aof_characteristic_question_answer_score_matches
  GROUP BY quizr, instance, user_uuid
) m ON s.quizr = m.quizr 
  AND s.instance = m.instance AND s.user_uuid = m.user_uuid;