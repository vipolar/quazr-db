CREATE OR REPLACE FUNCTION quazr_common_require_full_integer_range_in_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  -- arg0: 'schema.table.column' or 'table.column' or just 'column'
  qual text := TG_ARGV[0];

  -- arg1/arg2: integer range that has to be covered (inclusive)
  min_allowed int := TG_ARGV[1]::int;
  max_allowed int := TG_ARGV[2]::int;

  -- arg3: grouping column name         --OPTIONAL ARGUMENT--
  group_col text  := CASE
                       WHEN array_length(TG_ARGV, 1) >= 4
                            AND TG_ARGV[3] IS NOT NULL
                            AND TG_ARGV[3] <> ''
                       THEN TG_ARGV[3]
                       ELSE NULL
                     END;

  required_cnt int := (max_allowed - min_allowed + 1);

  parts         text[];
  target_schema text;
  target_table  text;
  value_col     text;
  group_val     text;

  cnt           int;
  distinct_cnt  int;
  minv          int;
  maxv          int;
  sql           text;
BEGIN
  IF qual IS NULL OR qual = '' THEN
    RAISE EXCEPTION 'Argument Violation: Trigger argument 0 (column) must be formatted as schema.table.column, table.column, or column.';
  END IF;

  IF min_allowed IS NULL OR max_allowed IS NULL THEN
    RAISE EXCEPTION 'Argument Violation: Trigger arguments 1 and 2 (min_allowed, max_allowed) must be provided.';
  END IF;

  IF max_allowed < min_allowed THEN
    RAISE EXCEPTION 'Argument Violation: The max_allowed (%) cannot be strictly less than min_allowed (%).',
      max_allowed, min_allowed
    USING ERRCODE = '23514';
  END IF;

  ------------------------------------------------------------------------
  -- PARSE schema.table.column / table.column / column
  ------------------------------------------------------------------------
  parts := string_to_array(qual, '.');

  IF array_length(parts, 1) = 3 THEN
    -- schema.table.column
    target_schema := parts[1];
    target_table  := parts[2];
    value_col     := parts[3];

  ELSIF array_length(parts, 1) = 2 THEN
    -- table.column (use trigger's schema)
    target_schema := TG_TABLE_SCHEMA;
    target_table  := parts[1];
    value_col     := parts[2];

  ELSE
    -- column (use trigger's table + schema)
    target_schema := TG_TABLE_SCHEMA;
    target_table  := TG_TABLE_NAME;
    value_col     := parts[1];
  END IF;

  IF target_schema IS NULL OR target_schema = '' THEN
    RAISE EXCEPTION 'Schema Violation: Could not determine target schema from argument "%".',
      qual
    USING ERRCODE = '42703';
  END IF;

  IF target_table IS NULL OR target_table = '' THEN
    RAISE EXCEPTION 'Schema Violation: Could not determine target table from argument "%".',
      qual
    USING ERRCODE = '42703';
  END IF;

  ------------------------------------------------------------------------
  -- EXTRACT GROUP VALUE IF APPLICABLE
  ------------------------------------------------------------------------
  IF group_col IS NOT NULL THEN
    EXECUTE format('SELECT ($1).%I::text', group_col)
      INTO group_val
      USING COALESCE(NEW, OLD);

    -- If grouping key is NULL for this row, skip the check
    IF group_val IS NULL THEN
      RETURN NULL;
    END IF;
  END IF;

  ------------------------------------------------------------------------
  -- MAIN CHECK: exact coverage of the integer range
  ------------------------------------------------------------------------
  sql := format($f$
    SELECT
      COUNT(*)::int,
      COUNT(DISTINCT %1$I)::int,
      MIN(%1$I)::int,
      MAX(%1$I)::int
    FROM %2$I.%3$I
    %4$s
  $f$,
    value_col,      -- %1$I column
    target_schema,  -- %2$I schema
    target_table,   -- %3$I table
    CASE
      WHEN group_col IS NOT NULL
      THEN format('WHERE %1$I = %2$L', group_col, group_val)
      ELSE ''
    END             -- %4$s WHERE
  );

  EXECUTE sql INTO cnt, distinct_cnt, minv, maxv;

  IF cnt          IS DISTINCT FROM required_cnt
     OR distinct_cnt IS DISTINCT FROM required_cnt
     OR minv      IS DISTINCT FROM min_allowed
     OR maxv      IS DISTINCT FROM max_allowed
  THEN
    RAISE EXCEPTION 'Range Constraint Violation: Column "%" in table "%.%" must contain exactly % rows covering the continuous integer range % to %. (Group: %, Actual Total: %, Distinct: %, Min: %, Max: %)',
      value_col, target_schema, target_table, required_cnt, min_allowed, max_allowed, COALESCE(group_val, 'GLOBAL'), cnt, distinct_cnt, minv, maxv
    USING ERRCODE = '23514';
  END IF;

  RETURN NULL;
END;
$$;
