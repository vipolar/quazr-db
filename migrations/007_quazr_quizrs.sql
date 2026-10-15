BEGIN;

DROP TABLE IF EXISTS staging.quazr_quizrs;
CREATE TABLE IF NOT EXISTS staging.quazr_quizrs (
  quizr         VARCHAR,
  display_name  VARCHAR,
  description   VARCHAR,
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ,
  starts_at     TIMESTAMPTZ,
  ends_at       TIMESTAMPTZ,
  tier          VARCHAR
);

TRUNCATE staging.quazr_quizrs;

\copy staging.quazr_quizrs FROM '/migrations/data/quazr_quizrs.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL');

SELECT u.*
FROM staging.quazr_quizrs s,
LATERAL quazr_upsert_quizrs(
  quizr,
  display_name,
  description,
  created_at,
  updated_at,
  starts_at,
  ends_at,
  tier
) u;

COMMIT;