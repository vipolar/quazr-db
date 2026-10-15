BEGIN;

CREATE OR REPLACE VIEW quazr_quizr_instances_wide AS
WITH
players AS (
  SELECT 
    quizr, 
    instance, 
    jsonb_agg(to_jsonb(p)) AS players_array
  FROM quazr_quizr_instance_players p
  GROUP BY quizr, instance
)

SELECT
  i.quizr,
  i.instance,
  i.created_by,
  COALESCE(p.players_array, '[]'::jsonb) AS players,
  i.created_at,
  i.concluded_at
FROM quazr_quizr_instances i
LEFT JOIN players p
  ON i.quizr = p.quizr AND i.instance = p.instance;

COMMIT;
