BEGIN;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.quazr_onesies_questions (
  characteristic  text,
  position        smallint,
  question        text,
  is_active       boolean
);

CREATE TABLE IF NOT EXISTS staging.quazr_onesies_question_options (
  characteristic  text,
  value           smallint,
  label           text
);

TRUNCATE staging.quazr_onesies_questions;
TRUNCATE staging.quazr_onesies_question_options;

\copy staging.quazr_onesies_questions FROM '/migrations/data/quazr_onesies_questions.csv' WITH (FORMAT csv, HEADER true)
\copy staging.quazr_onesies_question_options FROM '/migrations/data/quazr_onesies_question_options.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO quazr_onesies_questions (characteristic, position, question, is_active)
SELECT
  characteristic::quazr_onesies_animal_characteristic,
  position,
  TRIM(question),
  COALESCE(is_active, true)
FROM staging.quazr_onesies_questions
ON CONFLICT (characteristic) DO UPDATE SET
  position  = EXCLUDED.position,
  question  = EXCLUDED.question,
  is_active = EXCLUDED.is_active;

INSERT INTO quazr_onesies_question_options (characteristic, value, label)
SELECT
  characteristic::quazr_onesies_animal_characteristic,
  value,
  TRIM(label)
FROM staging.quazr_onesies_question_options
ON CONFLICT (characteristic, value) DO UPDATE SET
  label = EXCLUDED.label;

COMMIT;