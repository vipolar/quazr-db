BEGIN;

DROP TABLE IF EXISTS staging.quazr_character_variants_wide;
CREATE TABLE IF NOT EXISTS staging.quazr_character_variants_wide (
  character     VARCHAR,
  variant       UUID,
  display_name  VARCHAR,
  description   VARCHAR,
  environment   VARCHAR[],

  time          VARCHAR[],
  space         VARCHAR[],
  concept       VARCHAR[],
  function      VARCHAR[],
  ecosystem     VARCHAR[],
  settlement    VARCHAR[],
  weather       VARCHAR[],
  style         VARCHAR[],

  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ,
  starts_at     TIMESTAMPTZ,
  ends_at       TIMESTAMPTZ,
  bundle        VARCHAR[],
  tier          VARCHAR
);

TRUNCATE staging.quazr_character_variants_wide;
\copy staging.quazr_character_variants_wide FROM '/migrations/data/quazr_character_variants_wide.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL');

SELECT u.*
FROM staging.quazr_character_variants_wide s,
LATERAL quazr_upsert_character_variants(
  s.character,
  s.variant,
  s.display_name,
  s.description,
  s.environment,

  s.time,
  s.space,
  s.concept,
  s.function,
  s.ecosystem,
  s.settlement,
  s.weather,
  s.style,

  s.created_at,
  s.updated_at,
  s.starts_at,
  s.ends_at,
  s.bundle,
  s.tier
) u;

COMMIT;