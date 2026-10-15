BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute') THEN
    CREATE TYPE quazr_environment_attribute AS ENUM (
      'time','space','concept','function','ecosystem','settlement','weather','style'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute_time') THEN
    CREATE TYPE quazr_environment_attribute_time AS ENUM (
      'dawn','morning','day','afternoon','dusk','night','timeless'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute_space') THEN
    CREATE TYPE quazr_environment_attribute_space AS ENUM (
      'indoors','outdoors','underground','openwaters','underwater','aerial','cosmic','virtual'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute_concept') THEN
    CREATE TYPE quazr_environment_attribute_concept AS ENUM (
      'realistic','surreal','abstract','fantastical','futuristic','historical','mythical','dreamlike','psychedelic','extraterrestrial','postapocalyptic'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute_function') THEN
    CREATE TYPE quazr_environment_attribute_function AS ENUM (
      'untamed','residential','recreational','transportation','agricultural','military','scientific','medical','entertainment','ceremonial','industrial','institutional','commercial'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute_ecosystem') THEN
    CREATE TYPE quazr_environment_attribute_ecosystem AS ENUM (
      'tundra','coastal','saltwater','freshwater','desert','rainforest','mountainous','highland','woodland','shrubland','grassland','wetland','farmland','grove','special'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute_settlement') THEN
    CREATE TYPE quazr_environment_attribute_settlement AS ENUM (
      'natural','urban','suburban','rural','wilderness','forlorn'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute_weather') THEN
    CREATE TYPE quazr_environment_attribute_weather AS ENUM (
      'clear','sunny','scorching','cloudy','foggy','rainy','sleeting','snowy','hailing','freezing','icy','lightning','windy','stormy','tornado'
    );
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_environment_attribute_style') THEN
    CREATE TYPE quazr_environment_attribute_style AS ENUM (
      'realistic','vangogh','anime','popart','baroque','futuristic','cyberpunk'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS quazr_environment_attribute_definitions (
  attribute     quazr_environment_attribute          NOT NULL,
  value         varchar(32)                          NOT NULL,
  PRIMARY KEY (attribute, value)
);

INSERT INTO quazr_environment_attribute_definitions (attribute, value)
SELECT 'time'::quazr_environment_attribute, unnest(enum_range(NULL::quazr_environment_attribute_time))::text
UNION ALL
SELECT 'space'::quazr_environment_attribute, unnest(enum_range(NULL::quazr_environment_attribute_space))::text
UNION ALL
SELECT 'concept'::quazr_environment_attribute, unnest(enum_range(NULL::quazr_environment_attribute_concept))::text
UNION ALL
SELECT 'function'::quazr_environment_attribute, unnest(enum_range(NULL::quazr_environment_attribute_function))::text
UNION ALL
SELECT 'ecosystem'::quazr_environment_attribute, unnest(enum_range(NULL::quazr_environment_attribute_ecosystem))::text
UNION ALL
SELECT 'settlement'::quazr_environment_attribute, unnest(enum_range(NULL::quazr_environment_attribute_settlement))::text
UNION ALL
SELECT 'weather'::quazr_environment_attribute, unnest(enum_range(NULL::quazr_environment_attribute_weather))::text
UNION ALL
SELECT 'style'::quazr_environment_attribute, unnest(enum_range(NULL::quazr_environment_attribute_style))::text
ON CONFLICT DO NOTHING;

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'attribute', 'quazr_environment_attribute'
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute_time ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute_time
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'value', 'quazr_environment_attribute_time', 'attribute'
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute_space ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute_space
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'value', 'quazr_environment_attribute_space', 'attribute'
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute_concept ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute_concept
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'value', 'quazr_environment_attribute_concept', 'attribute'
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute_function ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute_function
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'value', 'quazr_environment_attribute_function', 'attribute'
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute_ecosystem ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute_ecosystem
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'value', 'quazr_environment_attribute_ecosystem', 'attribute'
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute_settlement ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute_settlement
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'value', 'quazr_environment_attribute_settlement', 'attribute'
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute_weather ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute_weather
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'value', 'quazr_environment_attribute_weather', 'attribute'
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute_style ON quazr_environment_attribute_definitions;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute_style
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_definitions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'value', 'quazr_environment_attribute_style', 'attribute'
);

CREATE TABLE IF NOT EXISTS quazr_environments (
  environment   varchar(32)                          PRIMARY KEY,
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
  CONSTRAINT environment_is_lowercase_letters_only CHECK (environment ~ '^[a-z_]+$')
);

CREATE TABLE IF NOT EXISTS quazr_environment_styles (
  style         varchar(32)                          PRIMARY KEY,
  attribute     quazr_environment_attribute          NOT NULL
                GENERATED ALWAYS AS ('style') STORED,
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
  FOREIGN KEY (attribute, style)
                REFERENCES quazr_environment_attribute_definitions(attribute, value)
                ON DELETE CASCADE,
  CONSTRAINT display_name_is_capitalized_and_clean CHECK (display_name ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$')
);

DROP TRIGGER IF EXISTS require_full_enum_set_in_style ON quazr_environment_styles;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_style
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_styles
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'style', 'quazr_environment_attribute_style'
);

CREATE TABLE IF NOT EXISTS quazr_environment_descriptions (
  environment   varchar(32)                          NOT NULL
                REFERENCES quazr_environments(environment)
                ON UPDATE CASCADE ON DELETE CASCADE,
  style         varchar(32)                          NOT NULL
                REFERENCES quazr_environment_styles(style)
                ON UPDATE CASCADE ON DELETE CASCADE,
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
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  PRIMARY KEY (environment, style)
);

CREATE TABLE IF NOT EXISTS quazr_environment_attribute_values (
  environment   varchar(32)                          NOT NULL
                REFERENCES quazr_environments(environment)
                ON UPDATE CASCADE ON DELETE CASCADE,
  attribute     quazr_environment_attribute          NOT NULL,
  value         varchar(32)                          NOT NULL,
  FOREIGN KEY (attribute, value)
                REFERENCES quazr_environment_attribute_definitions(attribute, value)
                ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (environment, attribute)
);
CREATE INDEX idx_env_attr_vals_on_attr_val ON quazr_environment_attribute_values (attribute, value);

DROP TRIGGER IF EXISTS require_full_enum_set_in_attribute ON quazr_environment_attribute_values;
CREATE CONSTRAINT TRIGGER require_full_enum_set_in_attribute
AFTER INSERT OR UPDATE OR DELETE ON quazr_environment_attribute_values
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'attribute', 'quazr_environment_attribute', 'environment'
);

---              Wide View for Environments            ---
\ir wide_views/quazr_environments_wide.sql
----------------------------------------------------------

COMMIT;