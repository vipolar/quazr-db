CREATE OR REPLACE FUNCTION quazr_user_settings_validate_setting_definition()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  -- Variables for path validation
  ancestor_path text := '';
  path_parts text[];
  i integer;

  -- Variables for parent definitions
  parent_parsed_float double precision;
  parent_def RECORD;
  
  -- Variables for children definitions (Updates)
  child_parsed_float double precision;
  child_rec RECORD;

  -- Variables for checking actual user settings (Updates)
  user_parsed_float double precision;
  user_rec RECORD;
BEGIN
  ----------------------------------------------------------------------
  -- DELETION PROTECTIONS
  ----------------------------------------------------------------------
  IF TG_OP = 'DELETE' THEN
    IF EXISTS (SELECT 1 FROM quazr_user_setting_definitions WHERE setting_path LIKE OLD.setting_path || '.%') THEN
      RAISE EXCEPTION 'Deletion Rejected: Path "%" has hierarchical children.',
        OLD.setting_path
      USING ERRCODE = '23514';
    END IF;
    
    IF EXISTS (SELECT 1 FROM quazr_user_setting_definitions WHERE enabling_setting = OLD.setting_path) THEN
      RAISE EXCEPTION 'Deletion Rejected: Other settings depend on "%" as an enabling_setting.',
        OLD.setting_path
      USING ERRCODE = '23514';
    END IF;

    RETURN OLD;
  END IF;

  ----------------------------------------------------------------------
  -- SETTING TYPE CHANGE PROTECTIONS
  ----------------------------------------------------------------------
  IF TG_OP = 'UPDATE' AND OLD.setting_type IS DISTINCT FROM NEW.setting_type THEN
    IF EXISTS (SELECT 1 FROM quazr_user_setting_definitions WHERE enabling_setting = NEW.setting_path) THEN
      RAISE EXCEPTION 'Cascading Update Blocked: Cannot change setting_type for "%" because dependent settings rely on it.',
        NEW.setting_path
      USING ERRCODE = '23514';
    END IF;

    IF EXISTS (SELECT 1 FROM quazr_user_settings WHERE setting_path = NEW.setting_path AND value IS NOT NULL) THEN
      RAISE EXCEPTION 'Cascading Update Blocked: Cannot change setting_type for "%" because it already has a value set in a user record.',
        NEW.setting_path
      USING ERRCODE = '23514';
    END IF;
  END IF;

  ----------------------------------------------------------------------
  -- PATH RENAME PROTECTION & HIERARCHY CHAIN CHECKS
  ----------------------------------------------------------------------
  IF TG_OP = 'UPDATE' AND OLD.setting_path IS DISTINCT FROM NEW.setting_path THEN
    IF EXISTS (SELECT 1 FROM quazr_user_setting_definitions WHERE setting_path LIKE OLD.setting_path || '.%') THEN
      RAISE EXCEPTION 'Path Rename Rejected: Path "%" has hierarchical children.',
        OLD.setting_path
      USING ERRCODE = '23514';
    END IF;
    
    IF EXISTS (SELECT 1 FROM quazr_user_setting_definitions WHERE enabling_setting = OLD.setting_path) THEN
      RAISE EXCEPTION 'Path Rename Rejected: Other settings depend on "%" as an enabling_setting.',
        OLD.setting_path
      USING ERRCODE = '23514';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.setting_path IS DISTINCT FROM NEW.setting_path) THEN
    path_parts := string_to_array(NEW.setting_path, '.');
    
    IF array_length(path_parts, 1) > 1 THEN
      FOR i IN 1 .. (array_length(path_parts, 1) - 1) LOOP
        IF i = 1 THEN
          ancestor_path := path_parts[i];
        ELSE
          ancestor_path := ancestor_path || '.' || path_parts[i];
        END IF;

        IF NOT EXISTS (SELECT 1 FROM quazr_user_setting_definitions WHERE setting_path = ancestor_path) THEN
          RAISE EXCEPTION 'Hierarchy Violation: Required ancestor "%" is missing for path "%".',
            ancestor_path, NEW.setting_path
          USING ERRCODE = '23514';
        END IF;
      END LOOP;
    END IF;
  END IF;

  ----------------------------------------------------------------------
  -- VALIDATE THE SETTING's OWN RULES & BOUNDARIES
  ----------------------------------------------------------------------
  IF NEW.setting_type <> 'blank' THEN
    BEGIN
      CASE NEW.setting_type
        WHEN 'int' THEN
          IF NEW.default_value IS NOT NULL THEN NEW.default_value := (NEW.default_value::integer)::text; END IF;
          IF NEW.min_value IS NOT NULL THEN NEW.min_value := (NEW.min_value::integer)::text; END IF;
          IF NEW.max_value IS NOT NULL THEN NEW.max_value := (NEW.max_value::integer)::text; END IF;
          IF NEW.options IS NOT NULL THEN NEW.options := (NEW.options::integer[])::text[]; END IF;

          IF NEW.min_value IS NOT NULL AND NEW.max_value IS NOT NULL AND NEW.min_value::integer > NEW.max_value::integer THEN
            RAISE EXCEPTION 'Bounds Violation: Minimum (%) cannot exceed maximum (%) for setting "%".',
              NEW.min_value, NEW.max_value, NEW.setting_path
            USING ERRCODE = '23514';
          END IF;

          IF NEW.default_value IS NOT NULL THEN
            IF NEW.min_value IS NOT NULL AND NEW.default_value::integer < NEW.min_value::integer THEN
              RAISE EXCEPTION 'Default Value Violation: Value (%) is below minimum (%) for setting "%".',
                NEW.default_value, NEW.min_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;
            IF NEW.max_value IS NOT NULL AND NEW.default_value::integer > NEW.max_value::integer THEN
              RAISE EXCEPTION 'Default Value Violation: Value (%) exceeds maximum (%) for setting "%".',
                NEW.default_value, NEW.max_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;
          END IF;

        WHEN 'float' THEN
          IF NEW.default_value IS NOT NULL THEN NEW.default_value := (NEW.default_value::double precision)::text; END IF;
          IF NEW.min_value IS NOT NULL THEN NEW.min_value := (NEW.min_value::double precision)::text; END IF;
          IF NEW.max_value IS NOT NULL THEN NEW.max_value := (NEW.max_value::double precision)::text; END IF;
          IF NEW.options IS NOT NULL THEN NEW.options := (NEW.options::double precision[])::text[]; END IF;

          IF NEW.min_value IS NOT NULL AND NEW.max_value IS NOT NULL AND NEW.min_value::double precision > NEW.max_value::double precision THEN
            RAISE EXCEPTION 'Bounds Violation: Minimum (%) cannot exceed maximum (%) for setting "%".',
              NEW.min_value, NEW.max_value, NEW.setting_path
            USING ERRCODE = '23514';
          END IF;

          IF NEW.default_value IS NOT NULL THEN
            IF NEW.min_value IS NOT NULL AND NEW.default_value::double precision < NEW.min_value::double precision THEN
              RAISE EXCEPTION 'Default Value Violation: Value (%) is below minimum (%) for setting "%".',
                NEW.default_value, NEW.min_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;
            IF NEW.max_value IS NOT NULL AND NEW.default_value::double precision > NEW.max_value::double precision THEN
              RAISE EXCEPTION 'Default Value Violation: Value (%) exceeds maximum (%) for setting "%".',
                NEW.default_value, NEW.max_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;
          END IF;

        WHEN 'boolean' THEN
          IF NEW.default_value IS NOT NULL THEN NEW.default_value := (NEW.default_value::boolean)::text; END IF;

        WHEN 'string' THEN
          NULL;

        ELSE
          RAISE EXCEPTION 'Type Violation: Unrecognized setting type "%" for setting "%".',
            NEW.setting_type, NEW.setting_path
          USING ERRCODE = '23514';
      END CASE;
        
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'Type Violation: Invalid format in default, min, max, or options for setting "%". Expected: %.',
        NEW.setting_path, NEW.setting_type
      USING ERRCODE = '23514';
    END;

    IF NEW.default_value IS NOT NULL AND NEW.options IS NOT NULL AND COALESCE(array_length(NEW.options, 1), 0) > 0 THEN
      IF NOT (NEW.default_value = ANY(NEW.options)) THEN
        RAISE EXCEPTION 'Options Violation: Default value "%" is not in allowed options [%] for setting "%".', 
          NEW.default_value, array_to_string(NEW.options, ', '), NEW.setting_path
        USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  ----------------------------------------------------------------------
  -- VALIDATE DEPENDENCY RULES (enabling_value constraints check)
  ----------------------------------------------------------------------
  IF NEW.enabling_setting IS NOT NULL AND NEW.enabling_value IS NOT NULL THEN
    SELECT * INTO parent_def FROM quazr_user_setting_definitions WHERE setting_path = NEW.enabling_setting;

    BEGIN
      CASE parent_def.setting_type
        WHEN 'int' THEN
          NEW.enabling_value := (NEW.enabling_value::integer)::text;
          IF parent_def.min_value IS NOT NULL AND NEW.enabling_value::integer < parent_def.min_value::integer THEN
              RAISE EXCEPTION 'Dependency Bounds Violation: Value (%) is below minimum (%) for parent "%".',
                NEW.enabling_value, parent_def.min_value, parent_def.setting_path
              USING ERRCODE = '23514';
          END IF;
          IF parent_def.max_value IS NOT NULL AND NEW.enabling_value::integer > parent_def.max_value::integer THEN
              RAISE EXCEPTION 'Dependency Bounds Violation: Value (%) exceeds maximum (%) for parent "%".',
                NEW.enabling_value, parent_def.max_value, parent_def.setting_path
              USING ERRCODE = '23514';
          END IF;

        WHEN 'float' THEN
            parent_parsed_float := NEW.enabling_value::double precision;
            NEW.enabling_value := parent_parsed_float::text;
            IF parent_def.min_value IS NOT NULL AND parent_parsed_float < parent_def.min_value::double precision THEN
                RAISE EXCEPTION 'Dependency Bounds Violation: Value (%) is below minimum (%) for parent "%".',
                  NEW.enabling_value, parent_def.min_value, parent_def.setting_path
                USING ERRCODE = '23514';
            END IF;
            IF parent_def.max_value IS NOT NULL AND parent_parsed_float > parent_def.max_value::double precision THEN
                RAISE EXCEPTION 'Dependency Bounds Violation: Value (%) exceeds maximum (%) for parent "%".',
                  NEW.enabling_value, parent_def.max_value, parent_def.setting_path
                USING ERRCODE = '23514';
            END IF;

        WHEN 'boolean' THEN
          NEW.enabling_value := (NEW.enabling_value::boolean)::text;

        WHEN 'string' THEN
          NULL;

        WHEN 'blank' THEN
          RAISE EXCEPTION 'Dependency Type Violation: Target "%" is a "blank" type and holds no value. (Setting: "%")',
            NEW.enabling_setting, NEW.setting_path
          USING ERRCODE = '23514';

        ELSE
          NULL;
      END CASE;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'Dependency Type Violation: Value "%" cannot cast to parent "%" type: %.', 
        NEW.enabling_value, parent_def.setting_path, parent_def.setting_type
      USING ERRCODE = '23514';
    END;

    IF parent_def.options IS NOT NULL AND COALESCE(array_length(parent_def.options, 1), 0) > 0 THEN
      IF NOT (NEW.enabling_value = ANY(parent_def.options)) THEN
        RAISE EXCEPTION 'Dependency Options Violation: Value "%" is not in allowed options [%] for parent "%".', 
          NEW.enabling_value, array_to_string(parent_def.options, ', '), parent_def.setting_path
        USING ERRCODE = '23514';
      END IF;
    END IF;
  END IF;

  ----------------------------------------------------------------------
  -- CASCADING CHECKS (ONLY ON UPDATES)
  ----------------------------------------------------------------------
  IF TG_OP = 'UPDATE' THEN
    FOR child_rec IN 
      SELECT setting_path, enabling_value FROM quazr_user_setting_definitions WHERE enabling_setting = NEW.setting_path
    LOOP
      BEGIN
        CASE NEW.setting_type
          WHEN 'int' THEN
            PERFORM child_rec.enabling_value::integer;
            IF NEW.min_value IS NOT NULL AND child_rec.enabling_value::integer < NEW.min_value::integer THEN
              RAISE EXCEPTION 'Cascading Update Blocked: Dependent "%" has value (%) below new minimum (%) of parent "%".',
                child_rec.setting_path, child_rec.enabling_value, NEW.min_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;
            IF NEW.max_value IS NOT NULL AND child_rec.enabling_value::integer > NEW.max_value::integer THEN
              RAISE EXCEPTION 'Cascading Update Blocked: Dependent "%" has value (%) exceeding new maximum (%) of parent "%".',
                child_rec.setting_path, child_rec.enabling_value, NEW.max_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;

          WHEN 'float' THEN
            child_parsed_float := child_rec.enabling_value::double precision;
            IF NEW.min_value IS NOT NULL AND child_parsed_float < NEW.min_value::double precision THEN
              RAISE EXCEPTION 'Cascading Update Blocked: Dependent "%" has value (%) below new minimum (%) of parent "%".',
                child_rec.setting_path, child_rec.enabling_value, NEW.min_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;
            IF NEW.max_value IS NOT NULL AND child_parsed_float > NEW.max_value::double precision THEN
              RAISE EXCEPTION 'Cascading Update Blocked: Dependent "%" has value (%) exceeding new maximum (%) of parent "%".',
                child_rec.setting_path, child_rec.enabling_value, NEW.max_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;

          WHEN 'boolean' THEN
            PERFORM child_rec.enabling_value::boolean;

          WHEN 'string' THEN
            NULL;
          
          ELSE
            NULL;
        END CASE;
      EXCEPTION WHEN invalid_text_representation THEN
          RAISE EXCEPTION 'Cascading Update Blocked: Dependent "%" has value "%" invalid for new type (%) of "%".',
            child_rec.setting_path, child_rec.enabling_value, NEW.setting_type, NEW.setting_path
          USING ERRCODE = '23514';
      END;

      IF NEW.options IS NOT NULL AND COALESCE(array_length(NEW.options, 1), 0) > 0 THEN
        IF NOT (child_rec.enabling_value = ANY(NEW.options)) THEN
          RAISE EXCEPTION 'Cascading Update Blocked: Dependent "%" has value "%" not in new options for "%".',
            child_rec.setting_path, child_rec.enabling_value, NEW.setting_path
          USING ERRCODE = '23514';
        END IF;
      END IF;
    END LOOP;

    FOR user_rec IN 
        SELECT user_uuid, value FROM quazr_user_settings WHERE setting_path = NEW.setting_path AND value IS NOT NULL
    LOOP
      BEGIN
        CASE NEW.setting_type
          WHEN 'int' THEN
            PERFORM user_rec.value::integer;
            IF NEW.min_value IS NOT NULL AND user_rec.value::integer < NEW.min_value::integer THEN
              RAISE EXCEPTION 'Cascading Update Blocked: User "%" has saved value (%) below new minimum (%) for "%".',
                user_rec.user_uuid, user_rec.value, NEW.min_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;
            IF NEW.max_value IS NOT NULL AND user_rec.value::integer > NEW.max_value::integer THEN
              RAISE EXCEPTION 'Cascading Update Blocked: User "%" has saved value (%) exceeding new maximum (%) for "%".',
                user_rec.user_uuid, user_rec.value, NEW.max_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;

          WHEN 'float' THEN
            user_parsed_float := user_rec.value::double precision;
            IF NEW.min_value IS NOT NULL AND user_parsed_float < NEW.min_value::double precision THEN
              RAISE EXCEPTION 'Cascading Update Blocked: User "%" has saved value (%) below new minimum (%) for "%".',
                user_rec.user_uuid, user_rec.value, NEW.min_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;
            IF NEW.max_value IS NOT NULL AND user_parsed_float > NEW.max_value::double precision THEN
              RAISE EXCEPTION 'Cascading Update Blocked: User "%" has saved value (%) exceeding new maximum (%) for "%".',
                user_rec.user_uuid, user_rec.value, NEW.max_value, NEW.setting_path
              USING ERRCODE = '23514';
            END IF;

          WHEN 'boolean' THEN
            PERFORM user_rec.value::boolean;

          WHEN 'string' THEN
            NULL;
          
          ELSE
            NULL;
        END CASE;
      EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Cascading Update Blocked: User "%" has saved value "%" invalid for new type (%) of "%".',
          user_rec.user_uuid, user_rec.value, NEW.setting_type, NEW.setting_path
        USING ERRCODE = '23514';
      END;

      IF NEW.options IS NOT NULL AND COALESCE(array_length(NEW.options, 1), 0) > 0 THEN
        IF NOT (user_rec.value = ANY(NEW.options)) THEN
          RAISE EXCEPTION 'Cascading Update Blocked: User "%" has saved value "%" not in new options for "%".',
            user_rec.user_uuid, user_rec.value, NEW.setting_path
          USING ERRCODE = '23514';
        END IF;
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;
