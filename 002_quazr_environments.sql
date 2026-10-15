BEGIN;

--DROP TABLE IF EXISTS staging.quazr_environments;
CREATE TABLE IF NOT EXISTS staging.quazr_environments (
  environment varchar(32),
  display_name varchar(64),
  bundle varchar(32),
  time varchar(32),
  space varchar(32),
  concept varchar(32),
  function varchar(32),
  ecosystem varchar(32),
  settlement varchar(32),
  weather varchar(32),
  style varchar(32),
  description varchar(512),
  created_at timestamptz,
  updated_at timestamptz,
  starts_at timestamptz,
  ends_at timestamptz,
  tier varchar(32)
);

--DROP TABLE IF EXISTS staging.quazr_environment_styles;
CREATE TABLE IF NOT EXISTS staging.quazr_environment_styles (
  style         varchar(32),
  display_name  varchar(64),
  bundle        varchar(32),
  description   varchar(512),
  created_at    timestamptz,
  updated_at    timestamptz,
  starts_at     timestamptz,
  ends_at       timestamptz,
  tier          varchar(32)
);

--DROP TABLE IF EXISTS staging.quazr_environment_descriptions;
CREATE TABLE IF NOT EXISTS staging.quazr_environment_descriptions (
  environment   varchar(32),
  style         varchar(32),
  bundle        varchar(32),
  description   varchar(512),
  created_at    timestamptz,
  updated_at    timestamptz,
  starts_at     timestamptz,
  ends_at       timestamptz,
  tier          varchar(32)
);

TRUNCATE staging.quazr_environments;
TRUNCATE staging.quazr_environment_styles;
TRUNCATE staging.quazr_environment_descriptions;

\copy staging.quazr_environments FROM '/migrations/data/quazr_environments.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')
\copy staging.quazr_environment_styles FROM '/migrations/data/quazr_environment_styles.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')
\copy staging.quazr_environment_descriptions FROM '/migrations/data/quazr_environment_descriptions.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')

INSERT INTO quazr_environments (environment, display_name, bundle, description, created_at, updated_at, starts_at, ends_at, tier)
SELECT
  environment,
  display_name,
  bundle,
  description,
  COALESCE(created_at, NOW()),
  COALESCE(updated_at, NOW()),
  starts_at,
  ends_at,
  tier::quazr_rewards_rarity_tier
FROM staging.quazr_environments
ON CONFLICT (environment)
DO UPDATE SET
  environment  = EXCLUDED.environment,
  display_name = EXCLUDED.display_name,
  bundle       = EXCLUDED.bundle,
  description  = EXCLUDED.description,
--created_at   = EXCLUDED.created_at,
--updated_at   = EXCLUDED.updated_at,
  starts_at    = EXCLUDED.starts_at,
  ends_at      = EXCLUDED.ends_at,
  tier         = EXCLUDED.tier;

INSERT INTO quazr_environment_attribute_values (environment, attribute, value)
SELECT environment, 'time'::quazr_environment_attribute, time FROM staging.quazr_environments
UNION ALL
SELECT environment, 'space'::quazr_environment_attribute, space FROM staging.quazr_environments
UNION ALL
SELECT environment, 'concept'::quazr_environment_attribute, concept FROM staging.quazr_environments
UNION ALL
SELECT environment, 'function'::quazr_environment_attribute, function FROM staging.quazr_environments
UNION ALL
SELECT environment, 'ecosystem'::quazr_environment_attribute, ecosystem FROM staging.quazr_environments
UNION ALL
SELECT environment, 'settlement'::quazr_environment_attribute, settlement FROM staging.quazr_environments
UNION ALL
SELECT environment, 'weather'::quazr_environment_attribute, weather FROM staging.quazr_environments
UNION ALL
SELECT environment, 'style'::quazr_environment_attribute, style FROM staging.quazr_environments
ON CONFLICT (environment, attribute) DO UPDATE SET
  value = EXCLUDED.value;

INSERT INTO quazr_environment_styles (style, display_name, bundle, description, created_at, updated_at, starts_at, ends_at, tier)
SELECT
  style,
  display_name,
  bundle,
  TRIM(description),
  COALESCE(created_at, NOW()),
  COALESCE(updated_at, NOW()),
  starts_at,
  ends_at,
  tier::quazr_rewards_rarity_tier
FROM staging.quazr_environment_styles
ON CONFLICT (style) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  bundle       = EXCLUDED.bundle,
  description  = EXCLUDED.description,
--created_at   = EXCLUDED.created_at,
--updated_at   = EXCLUDED.updated_at,
  starts_at    = EXCLUDED.starts_at,
  ends_at      = EXCLUDED.ends_at,
  tier         = EXCLUDED.tier;

INSERT INTO quazr_environment_descriptions (environment, style, bundle, description, created_at, updated_at, starts_at, ends_at, tier)
SELECT
  environment,
  style,
  bundle,
  TRIM(description),
  COALESCE(created_at, NOW()),
  COALESCE(updated_at, NOW()),
  starts_at,
  ends_at,
  tier::quazr_rewards_rarity_tier
FROM staging.quazr_environment_descriptions
ON CONFLICT (environment, style) DO UPDATE SET
  environment = EXCLUDED.environment,
  style       = EXCLUDED.style,
  bundle      = EXCLUDED.bundle,
  description = EXCLUDED.description,
--created_at  = EXCLUDED.created_at,
--updated_at  = EXCLUDED.updated_at,
  starts_at   = EXCLUDED.starts_at,
  ends_at     = EXCLUDED.ends_at,
  tier        = EXCLUDED.tier;

COMMIT;