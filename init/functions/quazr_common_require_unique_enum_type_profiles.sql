CREATE OR REPLACE FUNCTION quazr_common_require_unique_enum_type_profiles()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  -- arg0: 'schema.table.column' or 'table.column' or just 'column'
  enum_col_qual text    := TG_ARGV[0];

  -- arg1: enum type every entry of which should be in the column
  enum_t        regtype := to_regtype(TG_ARGV[1]);

  -- arg2: value column name (same table as the enum column)
  value_col     text    := TG_ARGV[2];

  -- arg3: grouping column name  --OPTIONAL ARGUMENT--
  group_col     text    := CASE
                             WHEN array_length(TG_ARGV, 1) >= 4
                                 AND TG_ARGV[3] IS NOT NULL
                                 AND TG_ARGV[3] <> ''
                             THEN TG_ARGV[3]
                             ELSE NULL
                           END;

  parts            text[];
  target_schema    text;
  target_table     text;
  enum_col         text;

  group_val        text;
  rows_exist       boolean;
  enum_count       int;
  v_cnt            int;
  v_profile        text;
  conflict_group   text;
  sql              text;
BEGIN
  IF enum_col_qual IS NULL OR enum_col_qual = '' THEN
    RAISE EXCEPTION 'Argument Violation: Trigger argument 0 (enum column) must be formatted as schema.table.column, table.column, or column.';
  END IF;

  IF value_col IS NULL OR value_col = '' THEN
    RAISE EXCEPTION 'Argument Violation: Trigger argument 2 (value column) must be provided as a valid column name.';
  END IF;

  IF enum_t IS NULL THEN
    RAISE EXCEPTION 'Argument Violation: Trigger argument 1 (enum type) must be a valid registered enum type.';
  END IF;

  IF group_col IS NULL OR group_col = '' THEN
    RETURN NULL;
  END IF;

  ------------------------------------------------------------------------
  -- PARSE schema.table.column formats
  ------------------------------------------------------------------------
  parts := string_to_array(enum_col_qual, '.');

  IF array_length(parts, 1) = 3 THEN
    target_schema := parts[1];
    target_table  := parts[2];
    enum_col      := parts[3];

  ELSIF array_length(parts, 1) = 2 THEN
    target_schema := TG_TABLE_SCHEMA;
    target_table  := parts[1];
    enum_col      := parts[2];

  ELSE
    target_schema := TG_TABLE_SCHEMA;
    target_table  := TG_TABLE_NAME;
    enum_col      := parts[1];
  END IF;

  ------------------------------------------------------------------------
  -- EXTRACT GROUPING VALUE IF APPLICABLE
  ------------------------------------------------------------------------
  IF group_col IS NOT NULL THEN
    EXECUTE format('SELECT ($1).%I::text', group_col)
      INTO group_val
      USING COALESCE(NEW, OLD);

    IF group_val IS NULL THEN
      RETURN NULL;
    END IF;
  END IF;

  --------------------------------------------------------------------
  -- SKIP CHECK IF THERE ARE NO ROWS LEFT (for this group or at all)
  --------------------------------------------------------------------
  IF group_col IS NOT NULL THEN
    sql := format(
      'SELECT EXISTS (SELECT 1 FROM %I.%I WHERE %I = $1)',
      target_schema, target_table, group_col
    );
    EXECUTE sql INTO rows_exist USING group_val;
  ELSE
    sql := format(
      'SELECT EXISTS (SELECT 1 FROM %I.%I)',
      target_schema, target_table
    );
    EXECUTE sql INTO rows_exist;
  END IF;

  IF NOT rows_exist THEN
    RETURN NULL;
  END IF;

  --------------------------------------------------------------------
  -- CHECK IF THERE IS A FULL ENUM SET (for this group or at all)
  --------------------------------------------------------------------
  SELECT COUNT(*) INTO enum_count FROM pg_enum WHERE enumtypid = enum_t;

  sql := format($f$
    SELECT
      COUNT(*)::int AS cnt,
      string_agg(%1$I::text, ',' ORDER BY %2$I) AS profile
    FROM %3$I.%4$I
    WHERE %5$I = $1
  $f$,
    value_col,      -- %1$I value column
    enum_col,       -- %2$I enum column (ordering)
    target_schema,  -- %3$I schema
    target_table,   -- %4$I table
    group_col       -- %5$I grouping column
  );

  EXECUTE sql INTO v_cnt, v_profile USING group_val;

  IF v_cnt <> enum_count OR v_profile IS NULL THEN
    RETURN NULL;
  END IF;

  --------------------------------------------------------------------
  -- MAIN CHECK: ensure no other group has the same enum profile
  --------------------------------------------------------------------
  sql := format($f$
    WITH group_profiles AS (
      SELECT
        %1$I::text AS grp,
        COUNT(*)::int AS cnt,
        string_agg(%2$I::text, ',' ORDER BY %3$I) AS profile
      FROM %4$I.%5$I
      GROUP BY %1$I
    )
    SELECT grp
    FROM group_profiles
    WHERE cnt = $1        -- full enum set
      AND profile = $2    -- same profile
      AND grp <> $3       -- different group
    LIMIT 1
  $f$,
    group_col,      -- %1$I grouping column
    value_col,      -- %2$I value column
    enum_col,       -- %3$I enum column
    target_schema,  -- %4$I schema
    target_table    -- %5$I table
  );

  EXECUTE sql INTO conflict_group
  USING enum_count, v_profile, group_val;

  IF conflict_group IS NOT NULL THEN
    RAISE EXCEPTION 'Profile Constraint Violation: Group "%" shares an identical complete enum profile with group "%". (Table: %.%, Enum: %)',
      group_val, conflict_group, target_schema, target_table, enum_t::text
    USING ERRCODE = '23514';
  END IF;

  RETURN NULL;
END;
$$;
