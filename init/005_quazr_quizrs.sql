BEGIN;

CREATE TABLE IF NOT EXISTS quazr_quizrs (
  quizr         varchar(32)                          PRIMARY KEY,
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
  CONSTRAINT quizr_is_lowercase_letters_only CHECK (quizr ~ '^[a-z_]+$')
);

CREATE TABLE IF NOT EXISTS quazr_quizr_instances (
  quizr         varchar(32)                          NOT NULL
                REFERENCES quazr_quizrs(quizr)
                ON UPDATE CASCADE ON DELETE CASCADE,
  instance      uuid   DEFAULT   gen_random_uuid()   NOT NULL,
  created_by    uuid                                 NOT NULL
                REFERENCES quazr_users(user_uuid)
                ON UPDATE CASCADE ON DELETE CASCADE,
  created_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  concluded_at  timestamptz                          NULL,
  PRIMARY KEY (quizr, instance)
);
CREATE INDEX idx_quazr_quizr_created_by ON quazr_quizr_instances(created_by);
CREATE INDEX idx_quazr_quizr_quiz_by ON quazr_quizr_instances(quizr, created_by);
CREATE INDEX idx_quazr_quizr_all ON quazr_quizr_instances(quizr, instance, created_by);

CREATE TABLE IF NOT EXISTS quazr_quizr_instance_players (
  quizr         varchar(32)                          NOT NULL,
  instance      uuid                                 NOT NULL,
  user_uuid     uuid                                 NOT NULL
                REFERENCES quazr_users(user_uuid)
                ON UPDATE CASCADE ON DELETE RESTRICT,
  avatar_uuid   uuid                                 NULL
                REFERENCES quazr_user_images(image_uuid)
                ON UPDATE CASCADE ON DELETE RESTRICT,
  image_uuid    uuid                                 NULL
                REFERENCES quazr_user_images(image_uuid)
                ON UPDATE CASCADE ON DELETE RESTRICT,
  nickname      varchar(32)                          NULL,
  descriptor    varchar(64)                          NULL,
  description   varchar(256)                         NULL,
  created_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  updated_at    timestamptz                          NOT NULL
                DEFAULT                              NOW(),
  FOREIGN KEY (quizr, instance)
                REFERENCES quazr_quizr_instances(quizr, instance)
                ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT description_is_clean CHECK (description ~ '^(?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT descriptor_is_clean CHECK (descriptor ~ '^(?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT nickname_is_clean CHECK (nickname ~ '^(?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  PRIMARY KEY (quizr, instance, user_uuid)
);
CREATE INDEX idx_quizr_players_instance ON quazr_quizr_instance_players(instance);
CREATE INDEX idx_quizr_players_user_uuid ON quazr_quizr_instance_players(user_uuid);
CREATE INDEX idx_quizr_players_quizr ON quazr_quizr_instance_players(quizr, user_uuid);
CREATE INDEX idx_quizr_players_player ON quazr_quizr_instance_players(instance, user_uuid);
CREATE INDEX idx_quizr_players_user_image ON quazr_quizr_instance_players(user_uuid, image_uuid);
CREATE INDEX idx_quizr_players_user_avatar ON quazr_quizr_instance_players(user_uuid, avatar_uuid);
CREATE INDEX idx_quizr_players_quizr_user_image ON quazr_quizr_instance_players(quizr, user_uuid, image_uuid);
CREATE INDEX idx_quizr_players_quizr_user_avatar ON quazr_quizr_instance_players(quizr, user_uuid, avatar_uuid);
CREATE INDEX idx_quizr_players_quizr_instance_image ON quazr_quizr_instance_players(quizr, instance, image_uuid);
CREATE INDEX idx_quizr_players_quizr_instance_avatar ON quazr_quizr_instance_players(quizr, instance, avatar_uuid);

COMMIT;
