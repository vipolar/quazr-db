CREATE OR REPLACE FUNCTION quazr_common_require_full_enum_type_set_in_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  -- arg0: 'schema.table.column' or 'table.column' or just 'column'
  qual text      := TG_ARGV[0];
  -- arg1: enum type every entry of which should be in the column
  enum_t regtype := to_regtype(TG_ARGV[1]);
  -- arg2: grouping column name        --OPTIONAL ARGUMENT--
  group_col text := CASE
                      WHEN array_length(TG_ARGV,1) >= 3
                           AND TG_ARGV[2] IS NOT NULL
                           AND TG_ARGV[2] <> ''
                      THEN TG_ARGV[2]
                      ELSE NULL
                    END;

  rows_exist     boolean;
  parts          text[];
  target_schema  text;
  target_table   text;
  value_col      text;
  group_val      text;

  missing        int;
  sql            text;
BEGIN
  IF qual IS NULL OR qual = '' THEN
    RAISE EXCEPTION 'Argument Violation: Trigger argument 0 (column) must be formatted as schema.table.column, table.column, or column.';
  END IF;

  IF enum_t IS NULL THEN
    RAISE EXCEPTION 'Argument Violation: Trigger argument 1 (enum type) must be a valid registered enum type.';
  END IF;

  ------------------------------------------------------------------------
  -- PARSE schema.table.column formats
  ------------------------------------------------------------------------
  parts := string_to_array(qual, '.');

  IF array_length(parts,1) = 3 THEN
    target_schema := parts[1];
    target_table  := parts[2];
    value_col     := parts[3];
  ELSIF array_length(parts,1) = 2 THEN
    target_schema := TG_TABLE_SCHEMA;
    target_table  := parts[1];
    value_col     := parts[2];
  ELSE
    target_schema := TG_TABLE_SCHEMA;
    target_table  := TG_TABLE_NAME;
    value_col     := parts[1];
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

  ------------------------------------------------------------------------
  -- SKIP CHECK IF THERE ARE NO ROWS LEFT (for this group or at all)
  ------------------------------------------------------------------------
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

  ------------------------------------------------------------------------
  -- MAIN CHECK: ensure all enum values appear in the target column
  ------------------------------------------------------------------------
  sql := format($f$
    WITH e AS (
      SELECT unnest(enum_range(NULL::%1$s)) AS attr
    ),
    present AS (
      SELECT DISTINCT %2$I::%1$s AS attr
      FROM %3$I.%4$I
      %5$s
    )
    SELECT count(*) FROM e
    LEFT JOIN present USING (attr)
    WHERE present.attr IS NULL
  $f$,
    enum_t,         -- %1$s enum type
    value_col,      -- %2$I column storing enum values
    target_schema,  -- %3$I schema
    target_table,   -- %4$I table
    CASE WHEN group_col IS NOT NULL
        THEN format('WHERE %I = %L', group_col, group_val)
        ELSE '' END
  );

  EXECUTE sql INTO missing;

  IF missing > 0 THEN
    RAISE EXCEPTION 'Enum Set Constraint Violation: Column "%" in table "%.%" must contain every value of the enum type "%". (Group: %, Missing: %)',
      value_col, target_schema, target_table, enum_t::text, COALESCE(group_val, 'GLOBAL'), missing
    USING ERRCODE = '23514';
  END IF;

  RETURN NULL;
END;
$$;
