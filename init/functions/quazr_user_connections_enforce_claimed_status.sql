CREATE OR REPLACE FUNCTION quazr_user_connections_enforce_claimed_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM quazr_users WHERE user_uuid = NEW.user_uuid AND account_uuid IS NOT NULL) THEN
    RAISE EXCEPTION 'State Violation: User "%" cannot establish connections because their account is unclaimed.',
      NEW.user_uuid
    USING ERRCODE = '23514';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM quazr_users WHERE user_uuid = NEW.target_uuid AND account_uuid IS NOT NULL) THEN
    RAISE EXCEPTION 'State Violation: Cannot establish connections with user "%" because their account is unclaimed.',
      NEW.target_uuid
    USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

