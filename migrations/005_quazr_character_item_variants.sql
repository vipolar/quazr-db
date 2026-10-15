BEGIN;

DROP TABLE IF EXISTS staging.quazr_character_item_variants_wide;
CREATE TABLE IF NOT EXISTS staging.quazr_character_item_variants_wide (
  item                VARCHAR,
  variant             UUID,
  display_name        VARCHAR,
  description         VARCHAR,
  character_variants  JSONB,

  environment         VARCHAR[],

  time                VARCHAR[],
  space               VARCHAR[],
  concept             VARCHAR[],
  function            VARCHAR[],
  ecosystem           VARCHAR[],
  settlement          VARCHAR[],
  weather             VARCHAR[],
  style               VARCHAR[],

  equipment_slots     JSONB,

  created_at          TIMESTAMPTZ,
  updated_at          TIMESTAMPTZ,
  starts_at           TIMESTAMPTZ,
  ends_at             TIMESTAMPTZ,
  bundle              VARCHAR[],
  tier                VARCHAR
);

TRUNCATE staging.quazr_character_item_variants_wide;
\copy staging.quazr_character_item_variants_wide FROM '/migrations/data/quazr_character_item_variants_wide.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL');

SELECT u.*
FROM staging.quazr_character_item_variants_wide s,
LATERAL quazr_upsert_character_item_variants(
  s.item,
  s.variant,
  s.display_name,
  s.description,
  s.character_variants,

  s.environment,

  s.time,
  s.space,
  s.concept,
  s.function,
  s.ecosystem,
  s.settlement,
  s.weather,
  s.style,

  s.equipment_slots,

  s.created_at,
  s.updated_at,
  s.starts_at,
  s.ends_at,
  s.bundle,
  s.tier
) u;

COMMIT;