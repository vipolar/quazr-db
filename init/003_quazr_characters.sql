BEGIN;

CREATE TABLE IF NOT EXISTS quazr_characters (
  character     varchar(32)                          PRIMARY KEY,
  display_name  varchar(64)                          NOT NULL,
  description   varchar(512)                         NOT NULL,
  created_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  updated_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  starts_at     timestamptz                          NULL,
  ends_at       timestamptz                          NULL,
  tier          quazr_rewards_rarity_tier            NOT NULL
                REFERENCES quazr_rewards_rarity_tiers(tier)
                ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT display_name_is_capitalized_and_clean CHECK (display_name ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT character_is_lowercase_letters_only CHECK (character ~ '^[a-z_]+$')
);

CREATE TABLE IF NOT EXISTS quazr_character_variants (
  character     varchar(32)                          NOT NULL
                REFERENCES quazr_characters(character)
                ON UPDATE CASCADE ON DELETE CASCADE,
  variant       uuid   DEFAULT   gen_random_uuid()   NOT NULL,
  display_name  varchar(64)                          NOT NULL,
  description   varchar(512)                         NOT NULL,
  created_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  updated_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  starts_at     timestamptz                          NULL,
  ends_at       timestamptz                          NULL,
  tier          quazr_rewards_rarity_tier            NOT NULL
                REFERENCES quazr_rewards_rarity_tiers(tier)
                ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT display_name_is_capitalized_and_clean CHECK (display_name ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  PRIMARY KEY (character, variant)
);
CREATE INDEX idx_char_variants_tier ON quazr_character_variants (tier);

CREATE TABLE IF NOT EXISTS quazr_character_variant_environments (
  character     varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  environment   varchar(32)                          NOT NULL
                REFERENCES quazr_environments(environment)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (character, variant)
                REFERENCES quazr_character_variants(character, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (character, variant, environment)
);
CREATE INDEX idx_cv_envs_on_env ON quazr_character_variant_environments (environment);

CREATE TABLE IF NOT EXISTS quazr_character_variant_r_bundles (
  character     varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  bundle        varchar(32)                          NOT NULL
                REFERENCES quazr_rewards_bundles(bundle)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (character, variant)
                REFERENCES quazr_character_variants(character, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (character, variant, bundle)
);

CREATE INDEX idx_cv_bundles_on_bundle ON quazr_character_variant_r_bundles (bundle);

CREATE TABLE IF NOT EXISTS quazr_character_variant_attribute_values (
  character     varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  attribute     quazr_environment_attribute          NOT NULL,
  value         varchar(32)                          NOT NULL,
  FOREIGN KEY (character, variant)
                REFERENCES quazr_character_variants(character, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (attribute, value)
                REFERENCES quazr_environment_attribute_definitions(attribute, value)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (character, variant, attribute, value)
);
CREATE INDEX idx_cv_attrs_on_attr_val ON quazr_character_variant_attribute_values (attribute, value);

---          Wide View for Character Variants          ---
\ir wide_views/quazr_character_variants_wide.sql
----------------------------------------------------------

CREATE TABLE IF NOT EXISTS quazr_character_items (
  item          varchar(32)                          PRIMARY KEY,
  display_name  varchar(64)                          NOT NULL,
  description   varchar(512)                         NOT NULL,
  created_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  updated_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  starts_at     timestamptz                          NULL,
  ends_at       timestamptz                          NULL,
  tier          quazr_rewards_rarity_tier            NOT NULL
                REFERENCES quazr_rewards_rarity_tiers(tier)
                ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT display_name_is_capitalized_and_clean CHECK (display_name ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT item_is_lowercase_letters_only CHECK (item ~ '^[a-z_]+$')
);

CREATE TABLE IF NOT EXISTS quazr_character_item_variants (
  item          varchar(32)                          NOT NULL
                REFERENCES quazr_character_items(item)
                ON UPDATE CASCADE ON DELETE CASCADE,
  variant       uuid   DEFAULT   gen_random_uuid()   NOT NULL,
  display_name  varchar(64)                          NOT NULL,
  description   varchar(512)                         NOT NULL,
  created_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  updated_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  starts_at     timestamptz                          NULL,
  ends_at       timestamptz                          NULL,
  tier          quazr_rewards_rarity_tier            NOT NULL
                REFERENCES quazr_rewards_rarity_tiers(tier)
                ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT display_name_is_capitalized_and_clean CHECK (display_name ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  PRIMARY KEY (item, variant)
);
CREATE INDEX idx_char_item_variants_tier ON quazr_character_item_variants (tier);

CREATE TABLE IF NOT EXISTS quazr_character_item_variant_character_variant (
  item                  varchar(32)                          NOT NULL,
  item_variant          uuid                                 NOT NULL,
  character             varchar(32)                          NOT NULL,
  character_variant     uuid                                 NOT NULL,
  FOREIGN KEY (item, item_variant)
                        REFERENCES quazr_character_item_variants(item, variant)
                        ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (character, character_variant)
                        REFERENCES quazr_character_variants(character, variant)
                        ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (item, item_variant, character, character_variant)
);
CREATE INDEX idx_civ_char_var_on_char ON quazr_character_item_variant_character_variant (character, character_variant);

CREATE TABLE IF NOT EXISTS quazr_character_item_variant_environments (
  item          varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  environment   varchar(32)                          NOT NULL
                REFERENCES quazr_environments(environment)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (item, variant)
                REFERENCES quazr_character_item_variants(item, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (item, variant, environment)
);
CREATE INDEX idx_civ_envs_on_env ON quazr_character_item_variant_environments (environment);

CREATE TABLE IF NOT EXISTS quazr_character_item_variant_r_bundles (
  item          varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  bundle        varchar(32)                          NOT NULL
                REFERENCES quazr_rewards_bundles(bundle)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (item, variant)
                REFERENCES quazr_character_item_variants(item, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (item, variant, bundle)
);
CREATE INDEX idx_civ_bundles_on_bundle ON quazr_character_item_variant_r_bundles (bundle);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_character_item_slot') THEN
    CREATE TYPE quazr_character_item_slot AS ENUM (
      'right foot','left foot','feet',
      'right ankle','left ankle','ankles',
      'right leg','left leg','legs',
      'right knee','left knee','knees',
      'right thigh','left thigh','thighs',
      'right hip','left hip','hips',
      'pelvis','waist','torso','chest',
      'right hand','left hand','hands',
      'right wrist','left wrist','wrists',
      'right forearm','left forearm','forearms',
      'right elbow','left elbow','elbows',
      'right upper arm','left upper arm','upper arms',
      'right shoulder','left shoulder','shoulders',
      'neck','chin','lower lip','upper lip','lips',
      'nose','right eye','left eye','eyes',
      'right ear','left ear','ears',
      'forehead','face','head'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS quazr_character_item_variant_slots (
  item              varchar(32)                                 NOT NULL,
  variant           uuid                                        NOT NULL,
  slot              quazr_character_item_slot                   NOT NULL,
  FOREIGN KEY (item, variant)
                    REFERENCES quazr_character_item_variants(item, variant)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (item, variant, slot)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_character_item_slot_preposition') THEN
    CREATE TYPE quazr_character_item_slot_preposition AS ENUM (
      'in','on','above','under','around','over','across','through','between','in front of','behind','to','from','at'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS quazr_character_item_variant_slot_prepositions (
  item              varchar(32)                                 NOT NULL,
  variant           uuid                                        NOT NULL,
  preposition       quazr_character_item_slot_preposition       NOT NULL,
  slot              quazr_character_item_slot                   NOT NULL,
  FOREIGN KEY (item, variant, slot)
                    REFERENCES quazr_character_item_variant_slots(item, variant, slot)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (item, variant, slot, preposition)
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_character_item_slot_attachment_mode') THEN
    CREATE TYPE quazr_character_item_slot_attachment_mode AS ENUM (
      'worn','carried','held','equipped','attached','fastened','tied','hanging','mounted','strapped','pinned','stuck','placed','inserted','sheathed','holstered'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS quazr_character_item_variant_slot_attachment_modes (
  item              varchar(32)                                 NOT NULL,
  variant           uuid                                        NOT NULL,
  attachment_mode   quazr_character_item_slot_attachment_mode   NOT NULL,
  preposition       quazr_character_item_slot_preposition       NOT NULL,
  slot              quazr_character_item_slot                   NOT NULL,
  FOREIGN KEY (item, variant, slot, preposition)
                    REFERENCES quazr_character_item_variant_slot_prepositions(item, variant, slot, preposition)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (item, variant, slot, preposition, attachment_mode)
);

CREATE TABLE IF NOT EXISTS quazr_character_item_variant_attribute_values (
  item          varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  attribute     quazr_environment_attribute          NOT NULL,
  value         varchar(32)                          NOT NULL,
  FOREIGN KEY (item, variant)
                REFERENCES quazr_character_item_variants(item, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (attribute, value)
                REFERENCES quazr_environment_attribute_definitions(attribute, value)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (item, variant, attribute, value)
);
CREATE INDEX idx_civ_attrs_on_attr_val ON quazr_character_item_variant_attribute_values (attribute, value);

---        Wide View for Character Item Variants       ---
\ir wide_views/quazr_character_item_variants_wide.sql
----------------------------------------------------------

CREATE TABLE IF NOT EXISTS quazr_character_actions (
  action        varchar(32)                          PRIMARY KEY,
  display_name  varchar(64)                          NOT NULL,
  description   varchar(512)                         NOT NULL,
  created_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  updated_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  starts_at     timestamptz                          NULL,
  ends_at       timestamptz                          NULL,
  tier          quazr_rewards_rarity_tier            NOT NULL
                REFERENCES quazr_rewards_rarity_tiers(tier)
                ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT display_name_is_capitalized_and_clean CHECK (display_name ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT action_is_lowercase_letters_only CHECK (action ~ '^[a-z_]+$')
);

CREATE TABLE IF NOT EXISTS quazr_character_action_variants (
  action        varchar(32)                          NOT NULL
                REFERENCES quazr_character_actions(action)
                ON UPDATE CASCADE ON DELETE CASCADE,
  variant       uuid   DEFAULT   gen_random_uuid()   NOT NULL,
  display_name  varchar(64)                          NOT NULL,
  description   varchar(512)                         NOT NULL,
  created_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  updated_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  starts_at     timestamptz                          NULL,
  ends_at       timestamptz                          NULL,
  tier          quazr_rewards_rarity_tier            NOT NULL
                REFERENCES quazr_rewards_rarity_tiers(tier)
                ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT display_name_is_capitalized_and_clean CHECK (display_name ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  PRIMARY KEY (action, variant)
);
CREATE INDEX idx_char_action_variants_tier ON quazr_character_action_variants (tier);

CREATE TABLE IF NOT EXISTS quazr_character_action_variant_character_variant (
  action                varchar(32)                          NOT NULL,
  action_variant        uuid                                 NOT NULL,
  character             varchar(32)                          NOT NULL,
  character_variant     uuid                                 NOT NULL,
  FOREIGN KEY (action, action_variant)
                        REFERENCES quazr_character_action_variants(action, variant)
                        ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (character, character_variant)
                        REFERENCES quazr_character_variants(character, variant)
                        ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (action, action_variant, character, character_variant)
);
CREATE INDEX idx_cav_char_var_on_char ON quazr_character_action_variant_character_variant (character, character_variant);

CREATE TABLE IF NOT EXISTS quazr_character_action_variant_character_item_variant (
  action                varchar(32)                          NOT NULL,
  action_variant        uuid                                 NOT NULL,
  item                  varchar(32)                          NOT NULL,
  item_variant          uuid                                 NOT NULL,
  FOREIGN KEY (action, action_variant)
                        REFERENCES quazr_character_action_variants(action, variant)
                        ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (item, item_variant)
                        REFERENCES quazr_character_item_variants(item, variant)
                        ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (action, action_variant, item, item_variant)
);
CREATE INDEX idx_cav_item_var_on_item ON quazr_character_action_variant_character_item_variant (item, item_variant);

CREATE TABLE IF NOT EXISTS quazr_character_action_variant_environments (
  action        varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  environment   varchar(32)                          NOT NULL
                REFERENCES quazr_environments(environment)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (action, variant)
                REFERENCES quazr_character_action_variants(action, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (action, variant, environment)
);
CREATE INDEX idx_cav_envs_on_env ON quazr_character_action_variant_environments (environment);

CREATE TABLE IF NOT EXISTS quazr_character_action_variant_r_bundles (
  action        varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  bundle        varchar(32)                          NOT NULL
                REFERENCES quazr_rewards_bundles(bundle)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (action, variant)
                REFERENCES quazr_character_action_variants(action, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (action, variant, bundle)
);
CREATE INDEX idx_cav_bundles_on_bundle ON quazr_character_action_variant_r_bundles (bundle);

CREATE TABLE IF NOT EXISTS quazr_character_action_variant_attribute_values (
  action        varchar(32)                          NOT NULL,
  variant       uuid                                 NOT NULL,
  attribute     quazr_environment_attribute          NOT NULL,
  value         varchar(32)                          NOT NULL,
  FOREIGN KEY (action, variant)
                REFERENCES quazr_character_action_variants(action, variant)
                ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (attribute, value)
                REFERENCES quazr_environment_attribute_definitions(attribute, value)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (action, variant, attribute, value)
);
CREATE INDEX idx_cav_attrs_on_attr_val ON quazr_character_action_variant_attribute_values (attribute, value);

---       Wide View for Character Action Variants      ---
\ir wide_views/quazr_character_action_variants_wide.sql
----------------------------------------------------------

COMMIT;
