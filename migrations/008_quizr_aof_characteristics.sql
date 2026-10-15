BEGIN;

CREATE TABLE IF NOT EXISTS staging.quizr_aof_characteristics (
  animal          text,
  characteristic  text,
  score           smallint
);

CREATE TABLE IF NOT EXISTS staging.quizr_aof_characteristic_questions (
  characteristic  text,
  position        smallint,
  question        text
);

CREATE TABLE IF NOT EXISTS staging.quizr_aof_characteristic_question_options (
  characteristic  text,
  position        smallint,
  option          text,
  value           smallint
);

TRUNCATE staging.quizr_aof_characteristics;
TRUNCATE staging.quizr_aof_characteristic_questions;
TRUNCATE staging.quizr_aof_characteristic_question_options;

\copy staging.quizr_aof_characteristics FROM '/migrations/data/quizr_aof_characteristics.csv' WITH (FORMAT csv, HEADER true)
\copy staging.quizr_aof_characteristic_questions FROM '/migrations/data/quizr_aof_characteristic_questions.csv' WITH (FORMAT csv, HEADER true)
\copy staging.quizr_aof_characteristic_question_options FROM '/migrations/data/quizr_aof_characteristic_question_options.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO quizr_aof_characteristics (
  animal, playful, calm, curious, bold, gentle, independent, loyal, silly, adventurous, graceful
)
SELECT 
  animal,
  MAX(score) FILTER (WHERE characteristic = 'playful'),
  MAX(score) FILTER (WHERE characteristic = 'calm'),
  MAX(score) FILTER (WHERE characteristic = 'curious'),
  MAX(score) FILTER (WHERE characteristic = 'bold'),
  MAX(score) FILTER (WHERE characteristic = 'gentle'),
  MAX(score) FILTER (WHERE characteristic = 'independent'),
  MAX(score) FILTER (WHERE characteristic = 'loyal'),
  MAX(score) FILTER (WHERE characteristic = 'silly'),
  MAX(score) FILTER (WHERE characteristic = 'adventurous'),
  MAX(score) FILTER (WHERE characteristic = 'graceful')
FROM staging.quizr_aof_characteristics
GROUP BY animal;

INSERT INTO quizr_aof_characteristic_questions (characteristic, position, question)
SELECT
  characteristic::quizr_aof_characteristic,
  position,
  TRIM(question)
FROM staging.quizr_aof_characteristic_questions
WHERE characteristic IS NOT NULL AND question IS NOT NULL
ON CONFLICT (characteristic) DO UPDATE
  SET position = EXCLUDED.position,
      question = EXCLUDED.question;

INSERT INTO quizr_aof_characteristic_question_options (characteristic, position, option, value)
SELECT
  characteristic::quizr_aof_characteristic,
  position,
  TRIM(option),
  value
FROM staging.quizr_aof_characteristic_question_options
WHERE characteristic IS NOT NULL AND option IS NOT NULL
ON CONFLICT (characteristic, value) DO UPDATE
  SET position = EXCLUDED.position,
      option   = EXCLUDED.option;

COMMIT;