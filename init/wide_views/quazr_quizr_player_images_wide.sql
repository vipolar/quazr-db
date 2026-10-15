BEGIN;

CREATE OR REPLACE VIEW quazr_user_images_wide AS
WITH
processing_parameters AS (
  SELECT * FROM quazr_user_image_processing_parameters
  GROUP BY image_uuid
)

SELECT
  i.image_uuid,
  i.uploader_uuid,

  pp.scaled_width,
  pp.scaled_height,
  pp.angle_in_radians,
  pp.extract_left,
  pp.extract_top,
  pp.extract_width,
  pp.extract_height,

  i.uploaded_at,
  i.updated_at
FROM quazr_user_images i
LEFT JOIN processing_parameters pp
  ON pp.image_uuid = i.image_uuid;

COMMIT;
