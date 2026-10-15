BEGIN; --ENVIRONMENTS

DROP TABLE IF EXISTS staging.quazr_environments;
CREATE TABLE IF NOT EXISTS staging.quazr_environments (
  environment     VARCHAR,
  display_name    VARCHAR,
  time            VARCHAR,
  space           VARCHAR,
  concept         VARCHAR,
  function        VARCHAR,
  ecosystem       VARCHAR,
  settlement      VARCHAR,
  weather         VARCHAR,
  default_style   VARCHAR,
  description     VARCHAR,
  created_at      TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ,
  starts_at       TIMESTAMPTZ,
  ends_at         TIMESTAMPTZ,
  tier            VARCHAR
);

TRUNCATE staging.quazr_environments;
\copy staging.quazr_environments FROM '/migrations/data/quazr_environments.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')

SELECT u.*
FROM staging.quazr_environments s,
LATERAL quazr_upsert_environments(
  environment,
  display_name,
  time,
  space,
  concept,
  function,
  ecosystem,
  settlement,
  weather,
  default_style,
  description,
  created_at,
  updated_at,
  starts_at,
  ends_at,
  tier
) u;

COMMIT;

BEGIN; --STYLES

DROP TABLE IF EXISTS staging.quazr_environment_styles;
CREATE TABLE IF NOT EXISTS staging.quazr_environment_styles (
  style         VARCHAR,
  display_name  VARCHAR,
  description   VARCHAR,
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ,
  starts_at     TIMESTAMPTZ,
  ends_at       TIMESTAMPTZ,
  tier          VARCHAR
);

TRUNCATE staging.quazr_environment_styles;
\copy staging.quazr_environment_styles FROM '/migrations/data/quazr_environment_styles.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')

SELECT u.*
FROM staging.quazr_environment_styles s,
LATERAL quazr_upsert_environment_styles(
  style,
  display_name,
  description,
  created_at,
  updated_at,
  starts_at,
  ends_at,
  tier
) u;

COMMIT;

BEGIN; --DESCRIPTIONS

DROP TABLE IF EXISTS staging.quazr_environment_descriptions;
CREATE TABLE IF NOT EXISTS staging.quazr_environment_descriptions (
  environment   VARCHAR,
  style         VARCHAR,
  description   VARCHAR,
  created_at    TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ,
  starts_at     TIMESTAMPTZ,
  ends_at       TIMESTAMPTZ,
  tier          VARCHAR
);

TRUNCATE staging.quazr_environment_descriptions;
\copy staging.quazr_environment_descriptions FROM '/migrations/data/quazr_environment_descriptions.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')

SELECT u.*
FROM staging.quazr_environment_descriptions s,
LATERAL quazr_upsert_environment_descriptions(
  environment,
  style,
  description,
  created_at,
  updated_at,
  starts_at,
  ends_at,
  tier
) u;

COMMIT;
