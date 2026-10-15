BEGIN;

CREATE OR REPLACE VIEW quizr_aof_players_wide AS
SELECT
  p.quizr,
  p.instance,
  p.user_uuid,
  p.avatar_uuid,
  p.image_uuid,
  p.nickname,

  c.playful,
  c.calm,
  c.curious,
  c.bold,
  c.gentle,
  c.independent,
  c.loyal,
  c.silly,
  c.adventurous,
  c.graceful,

  p.descriptor,
  p.description,
  c.created_at,
  c.updated_at
FROM quazr_quizr_instance_players p
LEFT JOIN quizr_aof_characteristic_question_answers c
  ON p.quizr = c.quizr AND p.instance = c.instance AND p.user_uuid = c.user_uuid;

COMMIT;