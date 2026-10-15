BEGIN;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.quazr_onesies_animals (
  animal      text,
  description text,
  onesie      text
);

CREATE TABLE IF NOT EXISTS staging.quazr_onesies_animal_characteristics (
  animal     text,
  characteristic  text,
  score      smallint
);

TRUNCATE staging.quazr_onesies_animals;
TRUNCATE staging.quazr_onesies_animal_characteristics;

\copy staging.quazr_onesies_animals FROM '/migrations/data/quazr_onesies_animals.csv' WITH (FORMAT csv, HEADER true)
\copy staging.quazr_onesies_animal_characteristics FROM '/migrations/data/quazr_onesies_animal_characteristics.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO quazr_onesies_animals (animal, description, onesie)
SELECT
  TRIM(animal),
  TRIM(description),
  TRIM(onesie)
FROM staging.quazr_onesies_animals
WHERE animal IS NOT NULL AND animal <> ''
ON CONFLICT (animal) DO UPDATE
  SET description = EXCLUDED.description,
      onesie      = EXCLUDED.onesie;

INSERT INTO quazr_onesies_animal_characteristics (animal, characteristic, score)
SELECT
  TRIM(animal),
  characteristic::quazr_onesies_animal_characteristic,
  score
FROM staging.quazr_onesies_animal_characteristics
WHERE animal IS NOT NULL AND characteristic IS NOT NULL
ON CONFLICT (animal, characteristic) DO UPDATE
  SET score = EXCLUDED.score;

COMMIT;