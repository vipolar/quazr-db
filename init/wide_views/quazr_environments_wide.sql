BEGIN;

CREATE OR REPLACE VIEW quazr_environments_wide AS
WITH
styles_array AS (
  SELECT
    environment,
    ARRAY_AGG(style ORDER BY tier ASC) AS styles
  FROM quazr_environment_descriptions
  GROUP BY environment
),
attr_pivot AS (
  SELECT
    environment,
    MAX(value) FILTER (WHERE attribute = 'time') AS time,
    MAX(value) FILTER (WHERE attribute = 'space') AS space,
    MAX(value) FILTER (WHERE attribute = 'concept') AS concept,
    MAX(value) FILTER (WHERE attribute = 'function') AS function,
    MAX(value) FILTER (WHERE attribute = 'ecosystem') AS ecosystem,
    MAX(value) FILTER (WHERE attribute = 'settlement') AS settlement,
    MAX(value) FILTER (WHERE attribute = 'weather') AS weather,
    MAX(value) FILTER (WHERE attribute = 'style') AS preferred_style
  FROM quazr_environment_attribute_values
  GROUP BY environment
)

SELECT
  e.environment,
  e.display_name,

  piv.time,
  piv.space,
  piv.concept,
  piv.function,
  piv.ecosystem,
  piv.settlement,
  piv.weather,

  CASE 
    WHEN piv.preferred_style = ANY(s.styles)
    THEN piv.preferred_style
    ELSE s.styles[1]
  END AS default_style,

  e.description,
  e.created_at,
  e.updated_at,
  e.starts_at,
  e.ends_at,
  e.tier
FROM quazr_environments e
LEFT JOIN attr_pivot piv 
  ON piv.environment = e.environment
LEFT JOIN styles_array s
  ON s.environment = e.environment;

COMMIT;
