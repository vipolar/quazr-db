BEGIN;

CREATE TABLE IF NOT EXISTS staging.quazr_rewards_rarity_tiers (
  tier          text,
  description   text,
  created_at    timestamptz                          NULL,
  updated_at    timestamptz                          NULL,
  starts_at     timestamptz                          NULL,
  ends_at       timestamptz                          NULL
);

DROP TABLE IF EXISTS staging.quazr_rewards_bundles;
CREATE TABLE IF NOT EXISTS staging.quazr_rewards_bundles (
  bundle        text,
  description   text,
  created_at    timestamptz                          NULL,
  updated_at    timestamptz                          NULL,
  starts_at     timestamptz                          NULL,
  ends_at       timestamptz                          NULL,
  tier          text
);

TRUNCATE staging.quazr_rewards_rarity_tiers;
TRUNCATE staging.quazr_rewards_bundles;

\copy staging.quazr_rewards_rarity_tiers FROM '/migrations/data/quazr_rewards_rarity_tiers.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')
\copy staging.quazr_rewards_bundles FROM '/migrations/data/quazr_rewards_bundles.csv' WITH (FORMAT csv, HEADER true, QUOTE '"', NULL 'NULL')

INSERT INTO quazr_rewards_rarity_tiers (tier, description, created_at, updated_at, starts_at, ends_at)
SELECT
  tier::quazr_rewards_rarity_tier,
  TRIM(description),
  COALESCE(created_at, NOW()),
  COALESCE(updated_at, NOW()),
  starts_at,
  ends_at
FROM staging.quazr_rewards_rarity_tiers
ON CONFLICT (tier) DO UPDATE SET
  tier        = EXCLUDED.tier,
  description = EXCLUDED.description,
--created_at  = EXCLUDED.created_at,
--updated_at  = EXCLUDED.updated_at,
  starts_at   = EXCLUDED.starts_at,
  ends_at     = EXCLUDED.ends_at;

INSERT INTO quazr_rewards_bundles (bundle, description, created_at, updated_at, starts_at, ends_at, tier)
SELECT
  bundle,
  TRIM(description),
  COALESCE(created_at, NOW()),
  COALESCE(updated_at, NOW()),
  starts_at,
  ends_at,
  tier::quazr_rewards_rarity_tier
FROM staging.quazr_rewards_bundles
ON CONFLICT (bundle) DO UPDATE SET
  bundle      = EXCLUDED.bundle,
  description = EXCLUDED.description,
--created_at  = EXCLUDED.created_at,
--updated_at  = EXCLUDED.updated_at,
  starts_at   = EXCLUDED.starts_at,
  ends_at     = EXCLUDED.ends_at,
  tier        = EXCLUDED.tier;

COMMIT;