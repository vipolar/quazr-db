BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quizr_aof_characteristic') THEN
    CREATE TYPE quizr_aof_characteristic AS ENUM (
      'playful','calm','curious','bold','gentle','independent','loyal','silly','adventurous','graceful'
    );
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS quizr_aof_onesies (
  animal            varchar(32)                   NOT NULL,
  variant           uuid                          NOT NULL,
  onesie            varchar(512)                  NOT NULL,
  FOREIGN KEY (animal, variant)
    REFERENCES quazr_character_variants(character, variant)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT onesie_is_capitalized_and_clean CHECK (onesie ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  PRIMARY KEY (animal, variant)
);

CREATE DOMAIN characteristic_score AS smallint CHECK (VALUE >= 1 AND VALUE <= 3);
CREATE TABLE IF NOT EXISTS quizr_aof_characteristics (
  animal            varchar(32)                   PRIMARY KEY
                    REFERENCES quazr_characters(character)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  playful           characteristic_score          NOT NULL,
  calm              characteristic_score          NOT NULL,
  curious           characteristic_score          NOT NULL,
  bold              characteristic_score          NOT NULL,
  gentle            characteristic_score          NOT NULL,
  independent       characteristic_score          NOT NULL,
  loyal             characteristic_score          NOT NULL,
  silly             characteristic_score          NOT NULL,
  adventurous       characteristic_score          NOT NULL,
  graceful          characteristic_score          NOT NULL,
  created_at        timestamptz                   NOT NULL
                    DEFAULT                       NOW(),
  updated_at        timestamptz                   NOT NULL
                    DEFAULT                       NOW()
);

CREATE TABLE IF NOT EXISTS quizr_aof_characteristic_questions (
  characteristic    quizr_aof_characteristic    PRIMARY KEY,
  position          smallint        UNIQUE      NOT NULL,
  question          varchar(512)    UNIQUE      NOT NULL,
  CONSTRAINT question_is_capitalized_and_clean CHECK (question ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT position_is_in_the_expected_range CHECK (position BETWEEN 0 AND 99)
);

DROP TRIGGER IF EXISTS require_full_enum_type_set_in_questions ON quizr_aof_characteristic_questions;
CREATE CONSTRAINT TRIGGER require_full_enum_type_set_in_questions
AFTER INSERT OR UPDATE OR DELETE ON quizr_aof_characteristic_questions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'characteristic', 'quizr_aof_characteristic'
);

DROP TRIGGER IF EXISTS forbid_value_overlap_between_positions ON quizr_aof_characteristic_questions;
CREATE CONSTRAINT TRIGGER forbid_value_overlap_between_positions
AFTER INSERT OR UPDATE OR DELETE ON quizr_aof_characteristic_questions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_forbid_value_overlap_between_columns(
  'quizr_aof_characteristic_questions.position',
  'quizr_aof_questions.position'
);

CREATE TABLE IF NOT EXISTS quizr_aof_characteristic_question_options (
  characteristic    quizr_aof_characteristic    NOT NULL
                    REFERENCES quizr_aof_characteristic_questions(characteristic)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  position          smallint                    NOT NULL,
  option            varchar(512)     UNIQUE     NOT NULL,
  value             characteristic_score        NOT NULL,
  CONSTRAINT option_is_capitalized_and_clean CHECK (option ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT position_is_in_the_expected_range CHECK (position BETWEEN 0 AND 2),
  PRIMARY KEY (characteristic, value)
);

DROP TRIGGER IF EXISTS require_full_enum_type_set_in_characteristics ON quizr_aof_characteristic_question_options;
CREATE CONSTRAINT TRIGGER require_full_enum_type_set_in_characteristics
AFTER INSERT OR UPDATE OR DELETE ON quizr_aof_characteristic_question_options
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_enum_type_set_in_column(
  'characteristic', 'quizr_aof_characteristic'
);

DROP TRIGGER IF EXISTS require_full_range_in_positions_by_characteristic ON quizr_aof_characteristic_question_options;
CREATE CONSTRAINT TRIGGER require_full_range_in_positions_by_characteristic
AFTER INSERT OR UPDATE OR DELETE ON quizr_aof_characteristic_question_options
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_integer_range_in_column(
  'position', '0', '2', 'characteristic'
);

DROP TRIGGER IF EXISTS require_full_range_in_value_by_characteristic ON quizr_aof_characteristic_question_options;
CREATE CONSTRAINT TRIGGER require_full_range_in_value_by_characteristic
AFTER INSERT OR UPDATE OR DELETE ON quizr_aof_characteristic_question_options
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_require_full_integer_range_in_column(
  'value', '1', '3', 'characteristic'
);

CREATE TABLE IF NOT EXISTS quizr_aof_characteristic_question_answers (
  quizr             varchar(32)                 NOT NULL,
  instance          uuid                        NOT NULL,
  user_uuid         uuid                        NOT NULL,
  playful           characteristic_score        NOT NULL,
  calm              characteristic_score        NOT NULL,
  curious           characteristic_score        NOT NULL,
  bold              characteristic_score        NOT NULL,
  gentle            characteristic_score        NOT NULL,
  independent       characteristic_score        NOT NULL,
  loyal             characteristic_score        NOT NULL,
  silly             characteristic_score        NOT NULL,
  adventurous       characteristic_score        NOT NULL,
  graceful          characteristic_score        NOT NULL,
  created_at        timestamptz                 NOT NULL
                    DEFAULT                     NOW(),
  updated_at        timestamptz                 NOT NULL
                    DEFAULT                     NOW(),
  FOREIGN KEY (quizr, instance, user_uuid)
    REFERENCES quazr_quizr_instance_players(quizr, instance, user_uuid)
    ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY (quizr, instance, user_uuid)
);

CREATE TABLE IF NOT EXISTS quizr_aof_characteristic_question_answer_score_matches (
  quizr             varchar(32)                 NOT NULL,
  instance          uuid                        NOT NULL,
  user_uuid         uuid                        NOT NULL,
  animal            varchar(32)                 NOT NULL
    REFERENCES quizr_aof_characteristics(animal)
    ON UPDATE CASCADE ON DELETE CASCADE,
  match_percentage  numeric                     NOT NULL,
  PRIMARY KEY (quizr, instance, user_uuid, animal)
);

---              Wide View for AOF Players             ---
\ir wide_views/quizr_aof_instance_players_wide.sql
----------------------------------------------------------

CREATE TABLE IF NOT EXISTS quizr_aof_questions (
  position          smallint                    PRIMARY KEY,
  question          varchar(512)                NOT NULL,
  CONSTRAINT question_is_capitalized_and_clean CHECK (question ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT position_is_in_the_expected_range CHECK (position BETWEEN 0 AND 99)
);

DROP TRIGGER IF EXISTS forbid_value_overlap_between_positions ON quizr_aof_questions;
CREATE CONSTRAINT TRIGGER forbid_value_overlap_between_positions
AFTER INSERT OR UPDATE OR DELETE ON quizr_aof_questions
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW
EXECUTE FUNCTION quazr_common_forbid_value_overlap_between_columns(
  'quizr_aof_questions.position',
  'quizr_aof_characteristic_questions.position'
);

CREATE TABLE IF NOT EXISTS quizr_aof_question_options (
  question          smallint                    NOT NULL
                    REFERENCES quizr_aof_questions(position)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  position          smallint                    NOT NULL,
  option            varchar(512)                NOT NULL,
  value             smallint                    NOT NULL,
  next_question     smallint                    NULL
                    REFERENCES quizr_aof_questions(position)
                    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT option_is_capitalized_and_clean CHECK (option ~ '^[A-Z](?:[^\s]*|\s(?!\s)[^\s]+)*[^\s]$'),
  CONSTRAINT position_is_in_the_expected_range CHECK (position BETWEEN 0 AND 2),
  CONSTRAINT value_is_in_the_expected_range CHECK (value BETWEEN 0 AND 2),
  PRIMARY KEY (question, value)
);

COMMIT;
