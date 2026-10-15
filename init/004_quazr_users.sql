BEGIN;

CREATE TABLE IF NOT EXISTS quazr_users (
  username          varchar(64)                          NOT NULL,
  user_uuid         uuid   DEFAULT   gen_random_uuid()   PRIMARY KEY,
  invited_by        uuid                                 NULL
                    REFERENCES       quazr_users(user_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  account_uuid      uuid                                 NULL,
  created_at        timestamptz                          NOT NULL
                    DEFAULT                              NOW(),
  updated_at        timestamptz                          NOT NULL
                    DEFAULT                              NOW()
);
CREATE INDEX idx_quazr_users_invited_by ON quazr_users(invited_by);

CREATE TABLE IF NOT EXISTS quazr_user_images (
  image_uuid        uuid   DEFAULT   gen_random_uuid()   PRIMARY KEY,
  uploader_uuid     uuid                                 NOT NULL
                    REFERENCES          quazr_users(user_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  uploaded_at       timestamptz                          NOT NULL
                    DEFAULT                              NOW(),
  updated_at        timestamptz                          NOT NULL
                    DEFAULT                              NOW()
);
CREATE INDEX idx_quazr_user_images_uploader ON quazr_user_images(uploader_uuid);

CREATE TABLE IF NOT EXISTS quazr_user_image_user_tags (
  image_uuid        uuid                                 NOT NULL
                    REFERENCES          quazr_user_images(image_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  user_uuid         uuid                                 NOT NULL
                    REFERENCES          quazr_users(user_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  bbox_left         INTEGER                              NOT NULL,
  bbox_top          INTEGER                              NOT NULL,
  bbox_width        INTEGER                              NOT NULL,
  bbox_height       INTEGER                              NOT NULL,
  PRIMARY KEY(image_uuid, user_uuid)
);
CREATE INDEX idx_quazr_user_image_tags_user ON quazr_user_image_user_tags(user_uuid);

CREATE TABLE IF NOT EXISTS quazr_user_image_processing_parameters (
  image_uuid        uuid                                 PRIMARY KEY
                    REFERENCES          quazr_user_images(image_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  scaled_width      INTEGER                              NOT NULL,
  scaled_height     INTEGER                              NOT NULL,
  angle_in_radians  DOUBLE PRECISION                     NOT NULL,
  extract_left      INTEGER                              NOT NULL,
  extract_top       INTEGER                              NOT NULL,
  extract_width     INTEGER                              NOT NULL,
  extract_height    INTEGER                              NOT NULL
);

CREATE TABLE IF NOT EXISTS quazr_user_connections (
  user_uuid         uuid                                 NOT NULL
                    REFERENCES            quazr_users(user_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  target_uuid       uuid                                 NOT NULL
                    REFERENCES            quazr_users(user_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  connected_since   timestamptz                          NOT NULL
                    DEFAULT                              NOW(),
  CONSTRAINT users_cannot_follow_themselves CHECK (user_uuid != target_uuid),
  PRIMARY KEY(user_uuid, target_uuid)
);
CREATE INDEX idx_user_mutual_connections ON quazr_user_connections (user_uuid, target_uuid);
CREATE INDEX idx_user_reverse_connections ON quazr_user_connections (target_uuid, user_uuid);

\ir functions/quazr_user_connections_enforce_claimed_status.sql
DROP TRIGGER IF EXISTS enforce_claimed_status ON quazr_user_connections;
CREATE TRIGGER enforce_claimed_status
BEFORE INSERT OR UPDATE ON quazr_user_connections
FOR EACH ROW EXECUTE FUNCTION quazr_user_connections_enforce_claimed_status();

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quazr_user_setting_type') THEN
    CREATE TYPE quazr_user_setting_type AS ENUM (
      'int','float','boolean','string','blank'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS quazr_user_setting_definitions (
  setting_path      varchar                                       PRIMARY KEY,
  setting_type      quazr_user_setting_type                       NOT NULL,
  display_title     varchar                                       NOT NULL,
  enabling_setting  varchar                                       NULL
                    REFERENCES quazr_user_setting_definitions(setting_path)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  enabling_value    varchar                                       NULL,
  default_value     varchar                                       NULL,
  min_value         varchar                                       NULL,
  max_value         varchar                                       NULL,
  options           varchar[]                                     NULL,
  description       varchar(512)                                  NULL,
  CONSTRAINT setting_value_definitions_options_check CHECK (
    ((setting_type = 'int' OR setting_type = 'float') AND ((options IS NULL AND min_value IS NOT NULL AND max_value IS NOT NULL) OR (options IS NOT NULL AND COALESCE(array_length(options, 1), 0) > 0 AND min_value IS NULL AND max_value IS NULL)) AND default_value IS NOT NULL) OR
    (setting_type = 'string' AND options IS NOT NULL AND COALESCE(array_length(options, 1), 0) > 0 AND min_value IS NULL AND max_value IS NULL AND default_value IS NOT NULL) OR
    (setting_type = 'boolean' AND options IS NULL AND min_value IS NULL AND max_value IS NULL AND default_value IS NOT NULL) OR
    (setting_type = 'blank' AND options IS NULL AND min_value IS NULL AND max_value IS NULL AND default_value IS NULL)
  ),
  CONSTRAINT setting_dependency_is_satisfied CHECK (enabling_setting <> setting_path AND ((enabling_setting IS NULL AND enabling_value IS NULL) OR (enabling_setting IS NOT NULL AND enabling_value IS NOT NULL))),
  CONSTRAINT setting_path_format_check CHECK (setting_path ~ '^([a-z0-9]|_[a-z0-9])([a-zA-Z0-9_-]*[a-zA-Z0-9])?(\.([a-z0-9]|_[a-z0-9])([a-zA-Z0-9_-]*[a-zA-Z0-9])?)*$'),
  CONSTRAINT display_title_is_capitalized_and_clean CHECK (display_title ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT description_is_capitalized_and_clean CHECK (description ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$')
);

\ir functions/quazr_user_settings_validate_setting_definition.sql
DROP TRIGGER IF EXISTS validate_setting_definition ON quazr_user_setting_definitions;
CREATE TRIGGER validate_setting_definition
BEFORE INSERT OR UPDATE OR DELETE ON quazr_user_setting_definitions
FOR EACH ROW EXECUTE FUNCTION quazr_user_settings_validate_setting_definition();

CREATE TABLE IF NOT EXISTS quazr_user_settings (
  user_uuid         uuid                                          NOT NULL
                    REFERENCES quazr_users(user_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  setting_path      varchar                                       NOT NULL
                    REFERENCES quazr_user_setting_definitions(setting_path)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  value             varchar                                       NULL,
  PRIMARY KEY(user_uuid, setting_path)
);

\ir functions/quazr_user_settings_validate_user_submitted.sql
DROP TRIGGER IF EXISTS validate_user_input_value ON quazr_user_settings;
CREATE TRIGGER validate_user_input_value
BEFORE INSERT OR UPDATE ON quazr_user_settings
FOR EACH ROW EXECUTE FUNCTION quazr_user_settings_validate_user_submitted();

\ir wide_views/quazr_user_connections_view.sql

COMMIT;