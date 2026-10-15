DROP FUNCTION IF EXISTS quazr_upsert_users(
  VARCHAR, UUID, UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ
);
CREATE OR REPLACE FUNCTION quazr_upsert_users(
  p_username          VARCHAR,
  p_user_uuid         UUID,
  p_invited_by        UUID,
  p_account_uuid      UUID,
  p_created_at        TIMESTAMPTZ,
  p_updated_at        TIMESTAMPTZ
) 
RETURNS quazr_users AS $$
DECLARE
  v_created_at timestamptz;
  v_result quazr_users;
  v_user_uuid uuid;
BEGIN
  v_user_uuid := COALESCE(p_user_uuid, gen_random_uuid());
  v_created_at := COALESCE(p_created_at, NOW());
  INSERT INTO quazr_users (
    username, user_uuid, invited_by, account_uuid, created_at
  ) VALUES (
    p_username, v_user_uuid, p_invited_by, p_account_uuid, v_created_at
  )
  ON CONFLICT (user_uuid) DO UPDATE SET
    username = EXCLUDED.username,
    invited_by = EXCLUDED.invited_by,
    account_uuid = EXCLUDED.account_uuid,
    updated_at = NOW()
  WHERE quazr_users.created_at = p_created_at
    AND quazr_users.user_uuid = p_user_uuid
  RETURNING * INTO v_result;

  IF v_result IS NULL THEN
    IF p_user_uuid <> v_user_uuid THEN
      RAISE EXCEPTION 'Data integrity violation: Record "quazr_users.%" update rejected due to a UUID collision (Hurray for the cosmically unlikely event of a UUID collision!)',
        p_user_uuid
      USING ERRCODE = '23514';
    END IF;

    SELECT created_at FROM quazr_users WHERE user_uuid = p_user_uuid INTO v_created_at;
    RAISE EXCEPTION 'Data integrity violation: Record "quazr_users.%" update rejected due to a creation timestamp mismatch (expected: %s, got: %s)',
      p_user_uuid, v_created_at, p_created_at
    USING ERRCODE = '23514';
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;
