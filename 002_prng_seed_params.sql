-- Example curve (replace numbers with your calibrated values)
INSERT INTO prng_params(version, alpha, lambda, is_default)
VALUES ('v1', 1.75, 0.045, TRUE)
ON CONFLICT (version) DO NOTHING;

-- Ensure only one default (make v1 default if none is set)
UPDATE prng_params
   SET is_default = TRUE
 WHERE version = 'v1'
   AND NOT EXISTS (SELECT 1 FROM prng_params WHERE is_default = TRUE);
