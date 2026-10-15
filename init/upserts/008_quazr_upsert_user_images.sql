DROP FUNCTION IF EXISTS quazr_upsert_user_images(
  UUID, UUID, INTEGER, INTEGER, DOUBLE PRECISION, INTEGER, INTEGER, INTEGER, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ
);
CREATE OR REPLACE FUNCTION quazr_upsert_user_images(
  p_image_uuid        UUID,
  p_uploader_uuid     UUID,
  p_scaled_width      INTEGER,
  p_scaled_height     INTEGER,
  p_angle_in_radians  DOUBLE PRECISION,
  p_extract_left      INTEGER,
  p_extract_top       INTEGER,
  p_extract_width     INTEGER,
  p_extract_height    INTEGER,
  p_uploaded_at       TIMESTAMPTZ,
  p_updated_at        TIMESTAMPTZ
) 
RETURNS quazr_user_images_wide AS $$
DECLARE
  v_parameters quazr_user_image_processing_parameters;
  v_quazr_user_image quazr_user_images;
  v_result quazr_user_images_wide;
  v_uploaded_at timestamptz;
  v_image_uuid uuid;
BEGIN
  v_image_uuid := COALESCE(p_image_uuid, gen_random_uuid());
  v_uploaded_at := COALESCE(p_uploaded_at, NOW());
  INSERT INTO quazr_user_images (
    image_uuid, uploader_uuid, uploaded_at
  ) VALUES (
    v_image_uuid, p_uploader_uuid, v_uploaded_at
  )
  ON CONFLICT (image_uuid) DO UPDATE SET
    updated_at = NOW()
  WHERE quazr_user_images.uploaded_at = p_uploaded_at
    AND quazr_user_images.image_uuid = p_image_uuid
  RETURNING * INTO v_quazr_user_image;

  IF v_quazr_user_image IS NULL THEN
    IF p_image_uuid <> v_image_uuid THEN
      RAISE EXCEPTION 'Data integrity violation: Record "quazr_user_images.%" update rejected due to a UUID collision (Hurray for the cosmically unlikely event of a UUID collision!)',
        p_image_uuid
      USING ERRCODE = '23514';
    END IF;

    SELECT uploaded_at FROM quazr_user_images WHERE image_uuid = p_image_uuid INTO v_uploaded_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_user_images.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_image_uuid, v_uploaded_at, p_uploaded_at
    USING ERRCODE = '23514';
  END IF;

  INSERT INTO quazr_user_image_processing_parameters (
    image_uuid, scaled_width, scaled_height, angle_in_radians, extract_left, extract_top, extract_width, extract_height
  ) VALUES (
    v_image_uuid, p_scaled_width, p_scaled_height, p_angle_in_radians, p_extract_left, p_extract_top, p_extract_width, p_extract_height
  ) ON CONFLICT (image_uuid) DO UPDATE SET
    scaled_width = EXCLUDED.scaled_width,
    scaled_height = EXCLUDED.scaled_height,
    angle_in_radians = EXCLUDED.angle_in_radians,
    extract_left = EXCLUDED.extract_left,
    extract_top = EXCLUDED.extract_top,
    extract_width = EXCLUDED.extract_width,
    extract_height = EXCLUDED.extract_height
  RETURNING * INTO v_parameters;

  --SELECT * FROM quazr_user_images_wide WHERE image_uuid = v_image_uuid INTO v_result;
  v_result := ROW(
    v_quazr_user_image.image_uuid,
    v_quazr_user_image.uploader_uuid,

    v_parameters.scaled_width,
    v_parameters.scaled_height,
    v_parameters.angle_in_radians,
    v_parameters.extract_left,
    v_parameters.extract_top,
    v_parameters.extract_width,
    v_parameters.extract_height,

    v_quazr_user_image.uploaded_at,
    v_quazr_user_image.updated_at
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
