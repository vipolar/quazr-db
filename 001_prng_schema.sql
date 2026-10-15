-- Create table prng_params
CREATE TABLE IF NOT EXISTS prng_params (
  version        TEXT PRIMARY KEY,
  alpha          DOUBLE PRECISION NOT NULL CHECK (alpha > 0),
  lambda         DOUBLE PRECISION NOT NULL CHECK (lambda > 0),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_default     BOOLEAN NOT NULL DEFAULT FALSE
);

-- Create table player_prng (no FK yet; we’ll add it conditionally below)
CREATE TABLE IF NOT EXISTS player_prng (
  player_id      TEXT PRIMARY KEY,
  n              INTEGER NOT NULL,
  u              DOUBLE PRECISION NOT NULL,
  params_version TEXT NOT NULL,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create table prng_roll_events
CREATE TABLE IF NOT EXISTS prng_roll_events (
  event_id       BIGSERIAL PRIMARY KEY,
  player_id      TEXT NOT NULL,
  request_id     TEXT NOT NULL,
  params_version TEXT NOT NULL,
  n_after        INTEGER NOT NULL,
  success        BOOLEAN NOT NULL,
  f_n            DOUBLE PRECISION NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes (idempotent)
CREATE UNIQUE INDEX IF NOT EXISTS uq_prng_roll_req
  ON prng_roll_events (player_id, request_id);

CREATE INDEX IF NOT EXISTS ix_prng_roll_player
  ON prng_roll_events (player_id);

-- Add FK for player_prng.params_version -> prng_params.version if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'player_prng_params_version_fkey'
  ) THEN
    ALTER TABLE player_prng
      ADD CONSTRAINT player_prng_params_version_fkey
      FOREIGN KEY (params_version) REFERENCES prng_params(version);
  END IF;
END$$;



--SESSIONS!
CREATE TABLE IF NOT EXISTS quazr_users (
	user_id           varchar        PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS quazr_user_sessions (
  user_id           varchar              NOT NULL
                    REFERENCES quazr_users(user_id)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  session_uuid      uuid                 PRIMARY KEY,
  session_state     varchar              NOT NULL,
  secret_hash       varchar              NOT NULL,
  created_at        timestamptz          NOT NULL,
  invalidated_at    timestamptz          NULL
);
CREATE INDEX idx_user_session ON quazr_user_sessions (
  user_id, session_state
);

CREATE TABLE IF NOT EXISTS quazr_user_session_refreshes (
  user_id           varchar              NOT NULL
                    REFERENCES quazr_users(user_id)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  session_uuid      uuid                 NOT NULL
                    REFERENCES quazr_user_sessions(session_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  secret_hash       varchar              NOT NULL,
  refreshed_at      timestamptz          NOT NULL,
  PRIMARY KEY (session_uuid, refreshed_at)
);

CREATE TABLE IF NOT EXISTS quazr_user_session_tokens (
  user_id           varchar              NOT NULL
                    REFERENCES quazr_users(user_id)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  session_uuid      uuid                 PRIMARY KEY
                    REFERENCES quazr_user_sessions(session_uuid)
                    ON UPDATE CASCADE ON DELETE CASCADE,
  id_token          varchar              NOT NULL,
  access_token      varchar              NOT NULL,
  at_expires_at     timestamptz          NOT NULL,
  refresh_token     varchar              NOT NULL,
  rt_expires_at     timestamptz          NOT NULL
);

CREATE TYPE quazr_user_session AS (
  user_id                   varchar,
  session_uuid              uuid,
  session_state             varchar,
  secret_hash               varchar,
  created_at                timestamptz,
  id_token                  varchar,
  access_token              varchar,
  access_token_expires_at   timestamptz,
  refresh_token             varchar,
  refresh_token_expires_at  timestamptz,
  refreshes                 jsonb,
  invalidated_at            timestamptz
);

CREATE OR REPLACE FUNCTION quazr_get_user_session(
  p_session_uuid    uuid
)
RETURNS quazr_user_session LANGUAGE sql STABLE
AS $$
  SELECT (
    s.user_id,
    s.session_uuid,
    s.session_state,
    s.secret_hash,
    s.created_at,
    t.id_token,
    t.access_token,
    t.at_expires_at,
    t.refresh_token,
    t.rt_expires_at,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'secret_hash', r.secret_hash,
          'refreshed_at', r.refreshed_at
        )
        ORDER BY r.refreshed_at ASC
      ),
      '[]'::jsonb
    ),
    s.invalidated_at
  )::quazr_user_session
  FROM quazr_user_sessions s
  LEFT JOIN quazr_user_session_tokens t
    ON t.session_uuid = s.session_uuid
  LEFT JOIN quazr_user_session_refreshes r
    ON r.session_uuid = s.session_uuid
  WHERE s.session_uuid = p_session_uuid
  GROUP BY
    s.user_id, s.session_uuid, s.session_state, s.secret_hash, s.created_at,
    t.user_id, t.id_token, t.access_token, t.at_expires_at, t.refresh_token, t.rt_expires_at
$$;

CREATE OR REPLACE FUNCTION quazr_upsert_user_session(
  p_user_id           varchar,
  p_session_uuid      uuid,
  p_session_state     varchar,
  p_secret_hash       varchar,
  p_created_at        timestamptz,
  p_id_token          varchar,
  p_access_token      varchar,
  p_at_expires_at     timestamptz,
  p_refresh_token     varchar,
  p_rt_expires_at     timestamptz,
  p_r_secret_hash     varchar,
  p_refreshed_at      timestamptz
)
RETURNS uuid AS $$
DECLARE
  v_successful_session_upsert boolean;
  v_session_uuid uuid;
BEGIN
  INSERT INTO quazr_users (
    user_id
  ) VALUES (
    p_user_id
  )
  ON CONFLICT (user_id) DO NOTHING;

  v_session_uuid := COALESCE(p_session_uuid, gen_random_uuid());
  INSERT INTO quazr_user_sessions (
    user_id, session_uuid, session_state, secret_hash, created_at, invalidated_at
  ) VALUES (
    p_user_id, v_session_uuid, p_session_state, p_secret_hash, p_created_at, NULL
  )
  ON CONFLICT (session_uuid) DO UPDATE SET
    secret_hash = EXCLUDED.secret_hash,
    invalidated_at = EXCLUDED.invalidated_at
  WHERE quazr_user_sessions.session_uuid = p_session_uuid
  RETURNING true INTO v_successful_session_upsert;

  IF v_successful_session_upsert IS NULL AND p_session_uuid <> v_session_uuid THEN
    RAISE EXCEPTION 'Data integrity violation: Hurray for the cosmically unlikely event of a UUID collision!' USING ERRCODE = '23514';
  END IF;

  INSERT INTO quazr_user_session_tokens (
    user_id, session_uuid, id_token, access_token, at_expires_at, refresh_token, rt_expires_at
  ) VALUES (
    p_user_id, v_session_uuid, p_id_token, p_access_token, p_at_expires_at, p_refresh_token, p_rt_expires_at
  )
  ON CONFLICT (session_uuid) DO UPDATE SET
    id_token       = EXCLUDED.id_token,
    access_token   = EXCLUDED.access_token,
    at_expires_at  = EXCLUDED.at_expires_at,
    refresh_token  = EXCLUDED.refresh_token,
    rt_expires_at  = EXCLUDED.rt_expires_at;

  INSERT INTO quazr_user_session_refreshes (
    user_id, session_uuid, secret_hash, refreshed_at
  ) VALUES (
    p_user_id, v_session_uuid, p_r_secret_hash, p_refreshed_at
  );

  RETURN v_session_uuid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION quazr_invalidate_user_session(
  p_session_uuid      uuid,
  p_invalidated_at    timestamptz
)
RETURNS timestamptz AS $$
DECLARE
  v_invalidated_at timestamptz;
BEGIN
  UPDATE quazr_user_sessions SET invalidated_at = p_invalidated_at WHERE session_uuid = p_session_uuid
  RETURNING invalidated_at INTO v_invalidated_at;

  RETURN v_invalidated_at;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION quazr_terminate_user_session(
  p_user_id           varchar,
  p_session_state     varchar,
  p_invalidated_at    timestamptz
)
RETURNS timestamptz AS $$
DECLARE
  v_invalidated_at timestamptz;
BEGIN
  UPDATE quazr_user_sessions SET invalidated_at = p_invalidated_at WHERE user_id = p_user_id AND session_state = p_session_state
  RETURNING invalidated_at INTO v_invalidated_at;

  RETURN v_invalidated_at;
END;
$$ LANGUAGE plpgsql;