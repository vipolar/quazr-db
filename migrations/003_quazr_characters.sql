BEGIN; --CHARACTERS

DROP TABLE IF EXISTS staging.quazr_characters;
CREATE TABLE IF NOT EXISTS staging.quazr_characters (
  character     VARCHAR,
  display_name  VARCHAR,
  description   VARCHAR,
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ,
  starts_at     TIMESTAMPTZ,
  ends_at       TIMESTAMPTZ,
  tier          VARCHAR
);

TRUNCATE staging.quazr_characters;
\copy staging.quazr_characters FROM '/migrations/data/quazr_characters.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')

SELECT u.*
FROM staging.quazr_characters s,
LATERAL quazr_upsert_characters(
  character,
  display_name,
  description,
  created_at,
  updated_at,
  starts_at,
  ends_at,
  tier
) u;

COMMIT;

BEGIN; -- ITEMS

DROP TABLE IF EXISTS staging.quazr_character_items;
CREATE TABLE IF NOT EXISTS staging.quazr_character_items (
  item          VARCHAR,
  display_name  VARCHAR,
  description   VARCHAR,
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ,
  starts_at     TIMESTAMPTZ,
  ends_at       TIMESTAMPTZ,
  tier          VARCHAR
);

TRUNCATE staging.quazr_character_items;
\copy staging.quazr_character_items FROM '/migrations/data/quazr_character_items.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')

SELECT u.*
FROM staging.quazr_character_items s,
LATERAL quazr_upsert_character_items(
  item,
  display_name,
  description,
  created_at,
  updated_at,
  starts_at,
  ends_at,
  tier
) u;

COMMIT;

BEGIN; -- ACTIONS

DROP TABLE IF EXISTS staging.quazr_character_actions;
CREATE TABLE IF NOT EXISTS staging.quazr_character_actions (
  action        VARCHAR,
  display_name  VARCHAR,
  description   VARCHAR,
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ,
  starts_at     TIMESTAMPTZ,
  ends_at       TIMESTAMPTZ,
  tier          VARCHAR
);

TRUNCATE staging.quazr_character_actions;
\copy staging.quazr_character_actions FROM '/migrations/data/quazr_character_actions.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')

SELECT u.*
FROM staging.quazr_character_actions s,
LATERAL quazr_upsert_character_actions(
  action,
  display_name,
  description,
  created_at,
  updated_at,
  starts_at,
  ends_at,
  tier
) u;

COMMIT;