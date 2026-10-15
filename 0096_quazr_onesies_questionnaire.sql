BEGIN;

-- Create a view to see the questionnaire in wide format
CREATE OR REPLACE VIEW quizr_aof_characteristic_questions_wide_view AS
SELECT
  q.characteristic,
  q.position,
  q.question,
  MAX(o.option) FILTER (WHERE o.value = 0) AS option_val_0,
  MAX(o.option) FILTER (WHERE o.value = 1) AS option_val_1,
  MAX(o.option) FILTER (WHERE o.value = 2) AS option_val_2,
  q.is_active
FROM quizr_aof_characteristic_questions q
LEFT JOIN quizr_aof_characteristic_question_options o
  USING (characteristic)
GROUP BY q.characteristic, q.position, q.question, q.is_active;

-- Create an ordered JSON view for frontend consumption
CREATE MATERIALIZED VIEW quizr_aof_questionnaire_json AS
SELECT 1 AS id, -- Static ID to allow a unique index for concurrent refreshes
  jsonb_agg(
    jsonb_build_object(
      'characteristic', q.characteristic::text,
      'position', q.position,
      'question', q.question,
      'options', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'position', o.position,
            'option', o.option,
            'value', o.value
            )
          ORDER BY o.value
        )
        FROM quizr_aof_characteristic_question_options o
        WHERE o.characteristic = q.characteristic
      )
    ) ORDER BY q.position
  ) AS questionnaire
FROM quizr_aof_characteristic_questions q;

CREATE UNIQUE INDEX quizr_aof_questionnaire_json_id_idx 
ON quizr_aof_questionnaire_json (id);

--REFRESH MATERIALIZED VIEW CONCURRENTLY quizr_aof_questionnaire_json;

COMMIT;

