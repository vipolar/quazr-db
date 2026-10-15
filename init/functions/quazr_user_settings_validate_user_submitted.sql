CREATE OR REPLACE FUNCTION quazr_user_settings_validate_user_submitted()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  parsed_float double precision;
  user_record RECORD;
  def_record RECORD;

  curr_enabling_setting_path varchar;
  curr_required_enabling_value varchar;
  curr_actual_user_value varchar;
  enabling_def_rec RECORD;
  target_def_rec RECORD;
  mismatch boolean;

  curr_eval_path text := '';
  path_parts text[];
  i integer;
BEGIN
  IF NEW.value IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO def_record FROM quazr_user_setting_definitions WHERE setting_path = NEW.setting_path;
  SELECT * INTO user_record FROM quazr_users WHERE user_uuid = NEW.user_uuid;

  IF user_record.account_uuid IS NULL THEN
    RAISE EXCEPTION 'Permissions Violation: User "%" is not permitted to have a user settings record.',
      NEW.user_uuid
    USING ERRCODE = '23514';
  END IF;

  ----------------------------------------------------------------------
  -- DEPENDENCY CHAIN VALIDATION
  ----------------------------------------------------------------------
  path_parts := string_to_array(NEW.setting_path, '.');
  
  FOR i IN 1 .. array_length(path_parts, 1) LOOP    
    IF i = 1 THEN
      curr_eval_path := path_parts[i];
    ELSE
      curr_eval_path := curr_eval_path || '.' || path_parts[i];
    END IF;

    SELECT * INTO target_def_rec FROM quazr_user_setting_definitions WHERE setting_path = curr_eval_path;

    curr_enabling_setting_path := target_def_rec.enabling_setting;
    curr_required_enabling_value := target_def_rec.enabling_value;
    WHILE curr_enabling_setting_path IS NOT NULL LOOP
      SELECT * INTO enabling_def_rec FROM quazr_user_setting_definitions WHERE setting_path = curr_enabling_setting_path;
      SELECT value INTO curr_actual_user_value FROM quazr_user_settings WHERE user_uuid = NEW.user_uuid AND setting_path = curr_enabling_setting_path;

      IF curr_actual_user_value IS NULL THEN
        curr_actual_user_value := enabling_def_rec.default_value;
      END IF;

      CASE enabling_def_rec.setting_type
        WHEN 'int' THEN
          mismatch := curr_actual_user_value::integer IS DISTINCT FROM curr_required_enabling_value::integer;
        WHEN 'float' THEN
          mismatch := curr_actual_user_value::double precision IS DISTINCT FROM curr_required_enabling_value::double precision;
        WHEN 'boolean' THEN
          mismatch := curr_actual_user_value::boolean IS DISTINCT FROM curr_required_enabling_value::boolean;
        WHEN 'string' THEN
          mismatch := curr_actual_user_value IS DISTINCT FROM curr_required_enabling_value;
        ELSE
          RAISE EXCEPTION 'Type Violation: Unrecognized setting type "%" for setting "%".',
            enabling_def_rec.setting_type, enabling_def_rec.setting_path
          USING ERRCODE = '23514';
      END CASE;

      IF mismatch THEN
        IF curr_eval_path = NEW.setting_path THEN
          RAISE EXCEPTION 'Dependency Chain Violation: Cannot set value for "%" because enabling setting "%" currently evaluates to "%" (expected: "%").',
            NEW.setting_path, curr_enabling_setting_path, COALESCE(curr_actual_user_value, 'NULL'), curr_required_enabling_value
          USING ERRCODE = '23514';
        ELSE
          RAISE EXCEPTION 'Hierarchy Dependency Violation: Cannot set value for "%" because its ancestor "%" is disabled. (Ancestor''s enabling setting "%" evaluates to "%", expected: "%").',
            NEW.setting_path, curr_eval_path, curr_enabling_setting_path, COALESCE(curr_actual_user_value, 'NULL'), curr_required_enabling_value
          USING ERRCODE = '23514';
        END IF;
      END IF;

      curr_enabling_setting_path := enabling_def_rec.enabling_setting;
      curr_required_enabling_value := enabling_def_rec.enabling_value;
    END LOOP;
  END LOOP;

  ----------------------------------------------------------------------
  -- TYPE & BOUNDARY VALIDATION
  ----------------------------------------------------------------------
  BEGIN
    CASE def_record.setting_type
      WHEN 'int' THEN
        NEW.value := (NEW.value::integer)::text;
        IF def_record.min_value IS NOT NULL AND NEW.value::integer < def_record.min_value::integer THEN
          RAISE EXCEPTION 'Bounds Violation: Value (%) is below minimum (%) for setting "%".',
            NEW.value, def_record.min_value, NEW.setting_path
          USING ERRCODE = '23514';
        END IF;
        IF def_record.max_value IS NOT NULL AND NEW.value::integer > def_record.max_value::integer THEN
          RAISE EXCEPTION 'Bounds Violation: Value (%) exceeds maximum (%) for setting "%".',
            NEW.value, def_record.max_value, NEW.setting_path
          USING ERRCODE = '23514';
        END IF;

      WHEN 'float' THEN
        parsed_float := NEW.value::double precision;
        NEW.value := parsed_float::text;
        IF def_record.min_value IS NOT NULL AND parsed_float < def_record.min_value::double precision THEN
          RAISE EXCEPTION 'Bounds Violation: Value (%) is below minimum (%) for setting "%".',
            NEW.value, def_record.min_value, NEW.setting_path
          USING ERRCODE = '23514';
        END IF;
        IF def_record.max_value IS NOT NULL AND parsed_float > def_record.max_value::double precision THEN
          RAISE EXCEPTION 'Bounds Violation: Value (%) exceeds maximum (%) for setting "%".',
            NEW.value, def_record.max_value, NEW.setting_path
          USING ERRCODE = '23514';
        END IF;

      WHEN 'boolean' THEN
        NEW.value := (NEW.value::boolean)::text;

      WHEN 'string' THEN
        NULL;

      WHEN 'blank' THEN
        RAISE EXCEPTION 'Type Violation: Target "%" is a "blank" type and cannot hold a value.',
          NEW.setting_path
        USING ERRCODE = '23514';
      
      ELSE
        RAISE EXCEPTION 'Type Violation: Unrecognized setting type "%" for setting "%".',
          def_record.setting_type, NEW.setting_path
        USING ERRCODE = '23514';
    END CASE;
      
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE EXCEPTION 'Type Violation: Value "%" cannot cast to expected type (%) for setting "%".', 
      NEW.value, def_record.setting_type, NEW.setting_path
    USING ERRCODE = '23514';
  END;

  IF def_record.options IS NOT NULL AND COALESCE(array_length(def_record.options, 1), 0) > 0 THEN
    IF NOT (NEW.value = ANY(def_record.options)) THEN
      RAISE EXCEPTION 'Options Violation: Value "%" is not in allowed options [%] for setting "%".', 
        NEW.value, array_to_string(def_record.options, ', '), NEW.setting_path
      USING ERRCODE = '23514';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
