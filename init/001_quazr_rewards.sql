BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_rewards_rarity_tier') THEN
    CREATE TYPE quazr_rewards_rarity_tier AS ENUM (
      'common','uncommon','rare','epic','mythical','legendary','celestial','ethereal','transcendent','empyrean'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS quazr_rewards_rarity_tiers (
  tier          quazr_rewards_rarity_tier         PRIMARY KEY,
  description   varchar(512)                      NOT NULL,
  created_at    timestamptz                       NOT NULL
                DEFAULT                           NOW(),
  updated_at    timestamptz                       NOT NULL
                DEFAULT                           NOW(),
  starts_at     timestamptz                       NULL,
  ends_at       timestamptz                       NULL,
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$')
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_tier ON quazr_rewards_rarity_tiers;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_tier
AFTER INSERT OR UPDATE OR DELETE ON quazr_rewards_rarity_tiers
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'tier', 'quazr_rewards_rarity_tier'
);

CREATE TABLE IF NOT EXISTS quazr_rewards_bundles (
  bundle        varchar(32)                       PRIMARY KEY,
  description   varchar(512)                      NOT NULL,
  created_at    timestamptz                       NOT NULL
                DEFAULT                           NOW(),
  updated_at    timestamptz                       NOT NULL
                DEFAULT                           NOW(),
  starts_at     timestamptz                       NULL,
  ends_at       timestamptz                       NULL,
  tier          quazr_rewards_rarity_tier         NOT NULL
                REFERENCES quazr_rewards_rarity_tiers(tier)
                ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT bundle_is_lowercase_letters_only CHECK (bundle ~ '^[a-z_]+$')
);

COMMIT;
