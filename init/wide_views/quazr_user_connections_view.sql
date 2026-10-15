BEGIN;

CREATE OR REPLACE VIEW quazr_user_connections_view AS
SELECT 
  uc_out.user_uuid AS connection_source_uuid,
  f.username AS connection_target_username,
  f.user_uuid AS connection_target_uuid,
  CASE WHEN uc_in.user_uuid IS NOT NULL THEN 'friends' ELSE 'following' END AS connection_type,
  COALESCE(uc_out.connected_since, uc_in.connected_since) AS connected_since
FROM quazr_user_connections uc_out
JOIN quazr_users f ON f.user_uuid = uc_out.target_uuid
LEFT JOIN quazr_user_connections uc_in 
  ON uc_in.user_uuid = f.user_uuid AND uc_in.target_uuid = uc_out.user_uuid
CROSS JOIN (
  SELECT COALESCE(MAX(default_value), 'anyone') AS default_invite_setting
  FROM quazr_user_setting_definitions WHERE setting_path = 'privacy.connections.allow-invites-from'
) globals
WHERE CASE COALESCE(
    (SELECT value FROM quazr_user_settings WHERE user_uuid = f.user_uuid AND setting_path = 'privacy.connections.allow-invites-from'), globals.default_invite_setting
  )
  WHEN 'friends' THEN (uc_in.user_uuid IS NOT NULL)
  ELSE true
END

UNION ALL

SELECT 
  inv.invited_by AS connection_source_uuid,
  inv.username AS connection_target_username,
  inv.user_uuid AS connection_target_uuid,
  'invited' AS connection_type,
  inv.created_at AS connected_since
FROM quazr_users inv
WHERE inv.account_uuid IS NULL AND inv.invited_by IS NOT NULL;

COMMIT;