CREATE OR REPLACE FUNCTION quazr_common_forbid_value_overlap_between_columns()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  -- arg0: 'schema.table.column' or 'table.column' or just 'column'
  base_qual    text := TG_ARGV[0];

  base_parts   text[];
  base_schema  text;
  base_table   text;
  base_col     text;

  -- arg1...N: 'schema.table.column' or 'table.column' or just 'column'
  i            int;
  other_qual   text;
  other_parts  text[];
  other_schema text;
  other_table  text;
  other_col    text;

  overlap_cnt  int;
  sql          text;
BEGIN
  ------------------------------------------------------------------------
  -- BASIC ARG VALIDATION
  ------------------------------------------------------------------------
  IF base_qual IS NULL OR base_qual = '' THEN
    RAISE EXCEPTION 'Argument Violation: Trigger argument 0 (base column) must be formatted as schema.table.column, table.column, or column.';
  END IF;

  IF TG_NARGS IS NULL OR TG_NARGS < 2 THEN
    RAISE EXCEPTION 'Argument Violation: At least two arguments are required (a base column and at least one target column to check against).';
  END IF;

  ------------------------------------------------------------------------
  -- PARSE BASE COLUMN: schema.table.column / table.column / column
  ------------------------------------------------------------------------
  base_parts := string_to_array(base_qual, '.');

  IF array_length(base_parts, 1) = 3 THEN
    -- schema.table.column
    base_schema := base_parts[1];
    base_table  := base_parts[2];
    base_col    := base_parts[3];

  ELSIF array_length(base_parts, 1) = 2 THEN
    -- table.column (use trigger's schema)
    base_schema := TG_TABLE_SCHEMA;
    base_table  := base_parts[1];
    base_col    := base_parts[2];

  ELSE
    -- column (use trigger's table + schema)
    base_schema := TG_TABLE_SCHEMA;
    base_table  := TG_TABLE_NAME;
    base_col    := base_parts[1];
  END IF;

  IF base_schema IS NULL OR base_schema = '' THEN
    RAISE EXCEPTION 'Schema Violation: Could not determine schema for base column from argument "%".',
      base_qual
    USING ERRCODE = '42703';
  END IF;

  IF base_table IS NULL OR base_table = '' OR base_col IS NULL OR base_col = '' THEN
    RAISE EXCEPTION 'Schema Violation: Could not determine table or column for base column from argument "%".',
      base_qual
    USING ERRCODE = '42703';
  END IF;

  ------------------------------------------------------------------------
  -- LOOP OVER ALL OTHER COLUMN SPECS: TG_ARGV[1..N]
  ------------------------------------------------------------------------
  FOR i IN 1 .. (TG_NARGS - 1) LOOP
    other_qual := TG_ARGV[i];

    -- skip empty/null just in case
    IF other_qual IS NULL OR other_qual = '' THEN
      CONTINUE;
    END IF;

    other_parts := string_to_array(other_qual, '.');

    IF array_length(other_parts, 1) = 3 THEN
      -- schema.table.column
      other_schema := other_parts[1];
      other_table  := other_parts[2];
      other_col    := other_parts[3];

    ELSIF array_length(other_parts, 1) = 2 THEN
      -- table.column (use trigger's schema)
      other_schema := TG_TABLE_SCHEMA;
      other_table  := other_parts[1];
      other_col    := other_parts[2];

    ELSE
      -- column (use trigger's table + schema)
      other_schema := TG_TABLE_SCHEMA;
      other_table  := TG_TABLE_NAME;
      other_col    := other_parts[1];
    END IF;

    IF other_schema IS NULL OR other_schema = '' THEN
      RAISE EXCEPTION 'Schema Violation: Could not determine schema for target column from argument "%".',
        other_qual
      USING ERRCODE = '42703';
    END IF;

    IF other_table IS NULL OR other_table = '' OR other_col IS NULL OR other_col = '' THEN
      RAISE EXCEPTION 'Schema Violation: Could not determine table or column for target column from argument "%".',
        other_qual
      USING ERRCODE = '42703';
    END IF;

    --------------------------------------------------------------------
    -- MAIN CHECK: base_col must not share values with this other_col
    --------------------------------------------------------------------
    sql := format($f$
      WITH a AS (
        SELECT DISTINCT %1$I::text AS val
        FROM %2$I.%3$I
      ),
      b AS (
        SELECT DISTINCT %4$I::text AS val
        FROM %5$I.%6$I
      )
      SELECT COUNT(*) FROM a JOIN b USING (val)
    $f$,
      base_col,     -- %1$I
      base_schema,  -- %2$I
      base_table,   -- %3$I
      other_col,    -- %4$I
      other_schema, -- %5$I
      other_table   -- %6$I
    );

    EXECUTE sql INTO overlap_cnt;

    IF overlap_cnt > 0 THEN
      RAISE EXCEPTION 'Overlap Constraint Violation: Column "%" in table "%.%" must not share values with target column "%" in table "%.%". (Overlapping values found: %)',
        base_col, base_schema, base_table, other_col, other_schema, other_table, overlap_cnt
      USING ERRCODE = '23514';
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$;
