BEGIN;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.quazr_environments (
  environment   text,
  description   text,
  category      text,
  tier          text
);

CREATE TABLE IF NOT EXISTS staging.quazr_environment_styles (
  style         text,
  description   text,
  tier          text
);

CREATE TABLE IF NOT EXISTS staging.quazr_environment_descriptions (
  environment   text,
  style         text,
  description   text,
  tier          text
);

TRUNCATE staging.quazr_environments;
TRUNCATE staging.quazr_environment_styles;
TRUNCATE staging.quazr_environment_descriptions;

\copy staging.quazr_environments FROM '/migrations/data/quazr_environments.csv' WITH (FORMAT csv, HEADER true)
\copy staging.quazr_environment_styles FROM '/migrations/data/quazr_environment_styles.csv' WITH (FORMAT csv, HEADER true)
\copy staging.quazr_environment_descriptions FROM '/migrations/data/quazr_environment_descriptions.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO quazr_environments (environment, description, category, tier)
SELECT
  TRIM(environment),
  TRIM(description),
  category::quazr_onesies_backdrop_category,
  tier::quazr_rewards_rarity_tier
FROM staging.quazr_environments
WHERE environment IS NOT NULL AND environment <> ''
ON CONFLICT (environment) DO UPDATE
  SET description = EXCLUDED.description,
      category    = EXCLUDED.category,
      tier        = EXCLUDED.tier;

INSERT INTO quazr_environment_styles (style, description, tier)
SELECT
  style::quazr_onesies_backdrop_style,
  TRIM(description),
  tier::quazr_rewards_rarity_tier
FROM staging.quazr_environment_styles
WHERE style IS NOT NULL AND style <> ''
ON CONFLICT (style) DO UPDATE
  SET description = EXCLUDED.description,
      tier        = EXCLUDED.tier;

INSERT INTO quazr_environment_descriptions (environment, style, description, tier)
SELECT
  TRIM(environment),
  style::quazr_onesies_backdrop_style,
  TRIM(description),
  tier::quazr_rewards_rarity_tier
FROM staging.quazr_environment_descriptions
WHERE environment IS NOT NULL AND environment <> '' AND style IS NOT NULL AND style <> ''
ON CONFLICT (environment, style) DO UPDATE
  SET description = EXCLUDED.description,
      tier        = EXCLUDED.tier;

COMMIT;