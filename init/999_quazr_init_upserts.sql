BEGIN;

\ir upserts/002_quazr_upsert_environments.sql
\ir upserts/003_quazr_upsert_characters.sql
\ir upserts/004_quazr_upsert_character_variants.sql
\ir upserts/005_quazr_upsert_character_item_variants.sql
\ir upserts/006_quazr_upsert_character_action_variants.sql
\ir upserts/007_quazr_upsert_users.sql
\ir upserts/008_quazr_upsert_user_images.sql
\ir upserts/009_quazr_upsert_user_settings.sql
\ir upserts/010_quazr_upsert_quizrs.sql

COMMIT;
