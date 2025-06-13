-- =====================================================
-- CUSTOM FIELDS MIGRATION
-- Flexible custom field system for all entities
-- Created: 2025-06-13 20:17:15 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- CUSTOM FIELD DEFINITIONS
-- =====================================================

-- Custom field types enum
CREATE TYPE custom_field_type AS ENUM (
    'text',
    'textarea',
    'number',
    'decimal',
    'boolean',
    'date',
    'datetime',
    'email',
    'url',
    'phone',
    'select',
    'multiselect',
    'radio',
    'checkbox',
    'file',
    'image',
    'currency',
    'percentage',
    'json',
    'reference'
);

-- Custom field definitions table
CREATE TABLE custom_field_definitions (
                                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                          organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Field identification
                                          field_name VARCHAR(100) NOT NULL, -- Internal field name
                                          display_name VARCHAR(255) NOT NULL, -- User-facing label
                                          description TEXT,

    -- Field type and configuration
                                          field_type custom_field_type NOT NULL,
                                          field_config JSONB DEFAULT '{}', -- Type-specific configuration

    -- Entity association
                                          entity_type VARCHAR(50) NOT NULL, -- contacts, companies, deals, activities, users, etc.

    -- Validation rules
                                          is_required BOOLEAN DEFAULT FALSE,
                                          is_unique BOOLEAN DEFAULT FALSE,
                                          validation_rules JSONB DEFAULT '{}', -- Field-specific validation

    -- Display and UI configuration
                                          display_order INTEGER DEFAULT 0,
                                          field_group VARCHAR(100), -- Grouping for UI display
                                          help_text TEXT,
                                          placeholder TEXT,

    -- Options for select/radio fields
                                          field_options JSONB DEFAULT '[]', -- Array of {value, label, color?} objects

    -- Default value
                                          default_value JSONB,

    -- Access control
                                          visibility VARCHAR(20) DEFAULT 'all', -- all, admin_only, role_based, custom
                                          visible_to_roles user_role[],
                                          editable_by_roles user_role[],

    -- Field behavior
                                          is_system_field BOOLEAN DEFAULT FALSE,
                                          is_active BOOLEAN DEFAULT TRUE,
                                          is_searchable BOOLEAN DEFAULT TRUE,
                                          is_reportable BOOLEAN DEFAULT TRUE,

    -- Conditional logic
                                          conditional_logic JSONB, -- Show/hide based on other field values

    -- Integration mapping
                                          external_mappings JSONB DEFAULT '{}', -- {integration_id: external_field_name}

    -- Metadata
                                          created_by UUID REFERENCES user_profiles(id),
                                          created_at TIMESTAMPTZ DEFAULT NOW(),
                                          updated_at TIMESTAMPTZ DEFAULT NOW(),
                                          deleted_at TIMESTAMPTZ,

    -- Constraints
                                          UNIQUE(organization_id, entity_type, field_name),
                                          CHECK (field_name ~ '^[a-z][a-z0-9_]*$') -- Snake case validation
    );

-- =====================================================
-- CUSTOM FIELD VALUES STORAGE
-- =====================================================

-- Custom field values table (polymorphic storage)
CREATE TABLE custom_field_values (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     field_definition_id UUID NOT NULL REFERENCES custom_field_definitions(id) ON DELETE CASCADE,

    -- Entity reference (polymorphic)
                                     entity_type VARCHAR(50) NOT NULL,
                                     entity_id UUID NOT NULL,

    -- Value storage (using appropriate column based on type)
                                     text_value TEXT,
                                     number_value BIGINT,
                                     decimal_value DECIMAL(15,4),
                                     boolean_value BOOLEAN,
                                     date_value DATE,
                                     datetime_value TIMESTAMPTZ,
                                     json_value JSONB,

    -- Array values for multiselect
                                     text_array_value TEXT[],

    -- File references
                                     file_url VARCHAR(1000),
                                     file_name VARCHAR(255),
                                     file_size BIGINT,
                                     file_type VARCHAR(100),

    -- Reference to other entities
                                     reference_entity_type VARCHAR(50),
                                     reference_entity_id UUID,

    -- Value metadata
                                     metadata JSONB DEFAULT '{}',

    -- Audit trail
                                     created_by UUID REFERENCES user_profiles(id),
                                     updated_by UUID REFERENCES user_profiles(id),
                                     created_at TIMESTAMPTZ DEFAULT NOW(),
                                     updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
                                     UNIQUE(field_definition_id, entity_type, entity_id)
);

-- =====================================================
-- CUSTOM FIELD GROUPS & SECTIONS
-- =====================================================

-- Custom field groups table (for organizing fields in UI)
CREATE TABLE custom_field_groups (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Group details
                                     group_name VARCHAR(100) NOT NULL,
                                     display_name VARCHAR(255) NOT NULL,
                                     description TEXT,

    -- Group configuration
                                     entity_type VARCHAR(50) NOT NULL,
                                     display_order INTEGER DEFAULT 0,

    -- Group styling
                                     icon VARCHAR(50),
                                     color VARCHAR(7), -- Hex color

    -- Group behavior
                                     is_collapsible BOOLEAN DEFAULT TRUE,
                                     is_collapsed_by_default BOOLEAN DEFAULT FALSE,

    -- Conditional display
                                     conditional_logic JSONB,

    -- Access control
                                     visible_to_roles user_role[],

    -- Status
                                     is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                     created_by UUID REFERENCES user_profiles(id),
                                     created_at TIMESTAMPTZ DEFAULT NOW(),
                                     updated_at TIMESTAMPTZ DEFAULT NOW(),

                                     UNIQUE(organization_id, entity_type, group_name)
);

-- =====================================================
-- CUSTOM FIELD TEMPLATES
-- =====================================================

-- Custom field templates table (reusable field configurations)
CREATE TABLE custom_field_templates (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Template details
                                        template_name VARCHAR(255) NOT NULL,
                                        description TEXT,
                                        category VARCHAR(100), -- industry, use_case, etc.

    -- Template configuration
                                        entity_type VARCHAR(50) NOT NULL,
                                        fields_config JSONB NOT NULL, -- Array of field definitions

    -- Template metadata
                                        tags TEXT[],
                                        use_cases TEXT[],

    -- Template status
                                        is_public BOOLEAN DEFAULT TRUE,
                                        is_featured BOOLEAN DEFAULT FALSE,

    -- Usage tracking
                                        usage_count INTEGER DEFAULT 0,

    -- Metadata
                                        created_by UUID REFERENCES user_profiles(id),
                                        created_at TIMESTAMPTZ DEFAULT NOW(),
                                        updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- CUSTOM FIELD HISTORY & VERSIONING
-- =====================================================

-- Custom field value history table
CREATE TABLE custom_field_value_history (
                                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                            field_value_id UUID NOT NULL REFERENCES custom_field_values(id) ON DELETE CASCADE,

    -- Historical value
                                            old_value JSONB,
                                            new_value JSONB,
                                            change_type VARCHAR(50) NOT NULL, -- created, updated, deleted

    -- Change context
                                            changed_by UUID REFERENCES user_profiles(id),
                                            change_reason VARCHAR(255),

    -- Metadata
                                            changed_at TIMESTAMPTZ DEFAULT NOW(),
                                            metadata JSONB DEFAULT '{}'
);

-- =====================================================
-- CUSTOM FIELD VALIDATION & RULES
-- =====================================================

-- Custom field validation rules table
CREATE TABLE custom_field_validation_rules (
                                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                               field_definition_id UUID NOT NULL REFERENCES custom_field_definitions(id) ON DELETE CASCADE,

    -- Rule details
                                               rule_name VARCHAR(100) NOT NULL,
                                               rule_type VARCHAR(50) NOT NULL, -- required, min_length, max_length, pattern, range, etc.
                                               rule_config JSONB NOT NULL,

    -- Rule behavior
                                               error_message TEXT NOT NULL,
                                               is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                               created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- CUSTOM FIELD ANALYTICS
-- =====================================================

-- Custom field usage analytics
CREATE TABLE custom_field_analytics (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                        field_definition_id UUID NOT NULL REFERENCES custom_field_definitions(id) ON DELETE CASCADE,

    -- Analytics period
                                        date DATE NOT NULL,

    -- Usage metrics
                                        total_records_with_value INTEGER DEFAULT 0,
                                        total_records_without_value INTEGER DEFAULT 0,
                                        fill_rate DECIMAL(5,2) DEFAULT 0, -- Percentage of records with values

    -- Value distribution (for select/multiselect fields)
                                        value_distribution JSONB DEFAULT '{}',

    -- Update frequency
                                        total_updates INTEGER DEFAULT 0,
                                        unique_updaters INTEGER DEFAULT 0,

    -- Performance metrics
                                        average_validation_time_ms INTEGER DEFAULT 0,
                                        validation_failures INTEGER DEFAULT 0,

    -- Metadata
                                        calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                        UNIQUE(field_definition_id, date)
);

-- =====================================================
-- FUNCTIONS FOR CUSTOM FIELDS
-- =====================================================

-- Function to get custom field value
CREATE OR REPLACE FUNCTION get_custom_field_value(
    entity_type_param VARCHAR(50),
    entity_id_param UUID,
    field_name_param VARCHAR(100),
    org_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
field_def RECORD;
    field_value RECORD;
    result JSONB;
BEGIN
    -- Get organization ID
    org_id := COALESCE(org_id, auth.user_organization_id());

    -- Get field definition
SELECT * INTO field_def
FROM custom_field_definitions
WHERE organization_id = org_id
  AND entity_type = entity_type_param
  AND field_name = field_name_param
  AND is_active = TRUE;

IF NOT FOUND THEN
        RETURN NULL;
END IF;

    -- Get field value
SELECT * INTO field_value
FROM custom_field_values
WHERE field_definition_id = field_def.id
  AND entity_type = entity_type_param
  AND entity_id = entity_id_param;

IF NOT FOUND THEN
        RETURN field_def.default_value;
END IF;

    -- Return appropriate value based on field type
CASE field_def.field_type
        WHEN 'text', 'textarea', 'email', 'url', 'phone' THEN
            result := to_jsonb(field_value.text_value);
WHEN 'number' THEN
            result := to_jsonb(field_value.number_value);
WHEN 'decimal', 'currency', 'percentage' THEN
            result := to_jsonb(field_value.decimal_value);
WHEN 'boolean', 'checkbox' THEN
            result := to_jsonb(field_value.boolean_value);
WHEN 'date' THEN
            result := to_jsonb(field_value.date_value);
WHEN 'datetime' THEN
            result := to_jsonb(field_value.datetime_value);
WHEN 'select', 'radio' THEN
            result := to_jsonb(field_value.text_value);
WHEN 'multiselect' THEN
            result := to_jsonb(field_value.text_array_value);
WHEN 'file', 'image' THEN
            result := jsonb_build_object(
                'url', field_value.file_url,
                'name', field_value.file_name,
                'size', field_value.file_size,
                'type', field_value.file_type
            );
WHEN 'reference' THEN
            result := jsonb_build_object(
                'entity_type', field_value.reference_entity_type,
                'entity_id', field_value.reference_entity_id
            );
WHEN 'json' THEN
            result := field_value.json_value;
ELSE
            result := to_jsonb(field_value.text_value);
END CASE;

RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to set custom field value
CREATE OR REPLACE FUNCTION set_custom_field_value(
    entity_type_param VARCHAR(50),
    entity_id_param UUID,
    field_name_param VARCHAR(100),
    field_value_param JSONB,
    org_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
field_def RECORD;
    existing_value RECORD;
    old_value JSONB;
    validation_result BOOLEAN;
BEGIN
    -- Get organization ID
    org_id := COALESCE(org_id, auth.user_organization_id());

    -- Get field definition
SELECT * INTO field_def
FROM custom_field_definitions
WHERE organization_id = org_id
  AND entity_type = entity_type_param
  AND field_name = field_name_param
  AND is_active = TRUE;

IF NOT FOUND THEN
        RAISE EXCEPTION 'Custom field not found: %', field_name_param;
END IF;

    -- Validate the value (basic validation)
    validation_result := validate_custom_field_value(field_def.id, field_value_param);

    IF NOT validation_result THEN
        RAISE EXCEPTION 'Invalid value for field: %', field_name_param;
END IF;

    -- Check if value already exists
SELECT * INTO existing_value
FROM custom_field_values
WHERE field_definition_id = field_def.id
  AND entity_type = entity_type_param
  AND entity_id = entity_id_param;

-- Store old value for history
IF FOUND THEN
        old_value := get_custom_field_value(entity_type_param, entity_id_param, field_name_param, org_id);
END IF;

    -- Insert or update value
INSERT INTO custom_field_values (
    field_definition_id,
    entity_type,
    entity_id,
    text_value,
    number_value,
    decimal_value,
    boolean_value,
    date_value,
    datetime_value,
    json_value,
    text_array_value,
    file_url,
    file_name,
    file_size,
    file_type,
    reference_entity_type,
    reference_entity_id,
    created_by,
    updated_by
) VALUES (
             field_def.id,
             entity_type_param,
             entity_id_param,
             CASE WHEN field_def.field_type IN ('text', 'textarea', 'email', 'url', 'phone', 'select', 'radio')
                      THEN field_value_param #>> '{}' END,
             CASE WHEN field_def.field_type = 'number'
                      THEN (field_value_param #>> '{}')::BIGINT END,
             CASE WHEN field_def.field_type IN ('decimal', 'currency', 'percentage')
                      THEN (field_value_param #>> '{}')::DECIMAL END,
             CASE WHEN field_def.field_type IN ('boolean', 'checkbox')
                      THEN (field_value_param #>> '{}')::BOOLEAN END,
             CASE WHEN field_def.field_type = 'date'
                      THEN (field_value_param #>> '{}')::DATE END,
             CASE WHEN field_def.field_type = 'datetime'
                      THEN (field_value_param #>> '{}')::TIMESTAMPTZ END,
             CASE WHEN field_def.field_type = 'json'
                      THEN field_value_param END,
             CASE WHEN field_def.field_type = 'multiselect'
                      THEN ARRAY(SELECT jsonb_array_elements_text(field_value_param)) END,
             CASE WHEN field_def.field_type IN ('file', 'image')
                      THEN field_value_param ->> 'url' END,
             CASE WHEN field_def.field_type IN ('file', 'image')
                      THEN field_value_param ->> 'name' END,
             CASE WHEN field_def.field_type IN ('file', 'image')
                      THEN (field_value_param ->> 'size')::BIGINT END,
             CASE WHEN field_def.field_type IN ('file', 'image')
                      THEN field_value_param ->> 'type' END,
             CASE WHEN field_def.field_type = 'reference'
                      THEN field_value_param ->> 'entity_type' END,
             CASE WHEN field_def.field_type = 'reference'
                      THEN (field_value_param ->> 'entity_id')::UUID END,
             auth.uid(),
             auth.uid()
         )
    ON CONFLICT (field_definition_id, entity_type, entity_id)
    DO UPDATE SET
    text_value = EXCLUDED.text_value,
               number_value = EXCLUDED.number_value,
               decimal_value = EXCLUDED.decimal_value,
               boolean_value = EXCLUDED.boolean_value,
               date_value = EXCLUDED.date_value,
               datetime_value = EXCLUDED.datetime_value,
               json_value = EXCLUDED.json_value,
               text_array_value = EXCLUDED.text_array_value,
               file_url = EXCLUDED.file_url,
               file_name = EXCLUDED.file_name,
               file_size = EXCLUDED.file_size,
               file_type = EXCLUDED.file_type,
               reference_entity_type = EXCLUDED.reference_entity_type,
               reference_entity_id = EXCLUDED.reference_entity_id,
               updated_by = auth.uid(),
               updated_at = NOW();

-- Record change in history
IF existing_value.id IS NOT NULL THEN
        INSERT INTO custom_field_value_history (
            field_value_id,
            old_value,
            new_value,
            change_type,
            changed_by
        ) VALUES (
            existing_value.id,
            old_value,
            field_value_param,
            'updated',
            auth.uid()
        );
END IF;

RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate custom field value
CREATE OR REPLACE FUNCTION validate_custom_field_value(
    field_definition_uuid UUID,
    field_value_param JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
field_def RECORD;
    validation_rule RECORD;
    value_text TEXT;
    value_number DECIMAL;
BEGIN
    -- Get field definition
SELECT * INTO field_def FROM custom_field_definitions WHERE id = field_definition_uuid;

IF NOT FOUND THEN
        RETURN FALSE;
END IF;

    -- Check if required field has value
    IF field_def.is_required AND (field_value_param IS NULL OR field_value_param = 'null'::jsonb) THEN
        RETURN FALSE;
END IF;

    -- Skip validation if value is null and field is not required
    IF field_value_param IS NULL OR field_value_param = 'null'::jsonb THEN
        RETURN TRUE;
END IF;

    -- Type-specific validation
CASE field_def.field_type
        WHEN 'email' THEN
            value_text := field_value_param #>> '{}';
            IF value_text !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
                RETURN FALSE;
END IF;
WHEN 'url' THEN
            value_text := field_value_param #>> '{}';
            IF value_text !~ '^https?://' THEN
                RETURN FALSE;
END IF;
WHEN 'number' THEN
BEGIN
                value_number := (field_value_param #>> '{}')::DECIMAL;
EXCEPTION WHEN OTHERS THEN
                RETURN FALSE;
END;
WHEN 'decimal', 'currency', 'percentage' THEN
BEGIN
                value_number := (field_value_param #>> '{}')::DECIMAL;
EXCEPTION WHEN OTHERS THEN
                RETURN FALSE;
END;
END CASE;

    -- Check validation rules
FOR validation_rule IN
SELECT * FROM custom_field_validation_rules
WHERE field_definition_id = field_definition_uuid
  AND is_active = TRUE
    LOOP
        -- Implement specific validation logic based on rule_type
        CASE validation_rule.rule_type
            WHEN 'min_length' THEN
                value_text := field_value_param #>> '{}';
IF char_length(value_text) < (validation_rule.rule_config ->> 'min_length')::INTEGER THEN
                    RETURN FALSE;
END IF;
WHEN 'max_length' THEN
                value_text := field_value_param #>> '{}';
                IF char_length(value_text) > (validation_rule.rule_config ->> 'max_length')::INTEGER THEN
                    RETURN FALSE;
END IF;
WHEN 'min_value' THEN
                value_number := (field_value_param #>> '{}')::DECIMAL;
                IF value_number < (validation_rule.rule_config ->> 'min_value')::DECIMAL THEN
                    RETURN FALSE;
END IF;
WHEN 'max_value' THEN
                value_number := (field_value_param #>> '{}')::DECIMAL;
                IF value_number > (validation_rule.rule_config ->> 'max_value')::DECIMAL THEN
                    RETURN FALSE;
END IF;
END CASE;
END LOOP;

RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate custom field analytics
CREATE OR REPLACE FUNCTION calculate_custom_field_analytics(
    field_definition_uuid UUID,
    analytics_date DATE
)
RETURNS VOID AS $$
DECLARE
field_def RECORD;
    total_records INTEGER;
    records_with_value INTEGER;
    records_without_value INTEGER;
    fill_rate_calc DECIMAL(5,2);
    total_updates_count INTEGER;
    unique_updaters_count INTEGER;
BEGIN
    -- Get field definition
SELECT * INTO field_def FROM custom_field_definitions WHERE id = field_definition_uuid;

IF NOT FOUND THEN
        RETURN;
END IF;

    -- Calculate total records for this entity type (simplified)
    -- In a real implementation, this would query the actual entity tables
EXECUTE format('SELECT COUNT(*) FROM %I WHERE organization_id = $1', field_def.entity_type)
    INTO total_records
    USING field_def.organization_id;

-- Calculate records with values
SELECT COUNT(*) INTO records_with_value
FROM custom_field_values cfv
WHERE cfv.field_definition_id = field_definition_uuid
  AND cfv.entity_type = field_def.entity_type;

records_without_value := total_records - records_with_value;

    -- Calculate fill rate
    fill_rate_calc := CASE
        WHEN total_records > 0 THEN (records_with_value::DECIMAL / total_records) * 100
        ELSE 0
END;

    -- Calculate updates for the date
SELECT COUNT(*), COUNT(DISTINCT changed_by) INTO total_updates_count, unique_updaters_count
FROM custom_field_value_history cfvh
         JOIN custom_field_values cfv ON cfvh.field_value_id = cfv.id
WHERE cfv.field_definition_id = field_definition_uuid
  AND cfvh.changed_at::DATE = analytics_date;

-- Insert analytics record
INSERT INTO custom_field_analytics (
    field_definition_id,
    date,
    total_records_with_value,
    total_records_without_value,
    fill_rate,
    total_updates,
    unique_updaters
) VALUES (
             field_definition_uuid,
             analytics_date,
             records_with_value,
             records_without_value,
             fill_rate_calc,
             total_updates_count,
             unique_updaters_count
         )
    ON CONFLICT (field_definition_id, date)
    DO UPDATE SET
    total_records_with_value = EXCLUDED.total_records_with_value,
               total_records_without_value = EXCLUDED.total_records_without_value,
               fill_rate = EXCLUDED.fill_rate,
               total_updates = EXCLUDED.total_updates,
               unique_updaters = EXCLUDED.unique_updaters,
               calculated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Custom field definitions indexes
CREATE INDEX idx_custom_field_definitions_organization_id ON custom_field_definitions(organization_id);
CREATE INDEX idx_custom_field_definitions_entity_type ON custom_field_definitions(entity_type);
CREATE INDEX idx_custom_field_definitions_field_name ON custom_field_definitions(field_name);
CREATE INDEX idx_custom_field_definitions_active ON custom_field_definitions(is_active);
CREATE INDEX idx_custom_field_definitions_searchable ON custom_field_definitions(is_searchable) WHERE is_searchable = TRUE;

-- Custom field values indexes
CREATE INDEX idx_custom_field_values_field_definition_id ON custom_field_values(field_definition_id);
CREATE INDEX idx_custom_field_values_entity ON custom_field_values(entity_type, entity_id);
CREATE INDEX idx_custom_field_values_text ON custom_field_values(text_value) WHERE text_value IS NOT NULL;
CREATE INDEX idx_custom_field_values_number ON custom_field_values(number_value) WHERE number_value IS NOT NULL;
CREATE INDEX idx_custom_field_values_decimal ON custom_field_values(decimal_value) WHERE decimal_value IS NOT NULL;
CREATE INDEX idx_custom_field_values_boolean ON custom_field_values(boolean_value) WHERE boolean_value IS NOT NULL;
CREATE INDEX idx_custom_field_values_date ON custom_field_values(date_value) WHERE date_value IS NOT NULL;
CREATE INDEX idx_custom_field_values_datetime ON custom_field_values(datetime_value) WHERE datetime_value IS NOT NULL;

-- GIN indexes for JSON and array fields
CREATE INDEX idx_custom_field_values_json ON custom_field_values USING GIN(json_value) WHERE json_value IS NOT NULL;
CREATE INDEX idx_custom_field_values_text_array ON custom_field_values USING GIN(text_array_value) WHERE text_array_value IS NOT NULL;

-- Custom field groups indexes
CREATE INDEX idx_custom_field_groups_organization_id ON custom_field_groups(organization_id);
CREATE INDEX idx_custom_field_groups_entity_type ON custom_field_groups(entity_type);

-- Custom field value history indexes
CREATE INDEX idx_custom_field_value_history_field_value_id ON custom_field_value_history(field_value_id);
CREATE INDEX idx_custom_field_value_history_changed_at ON custom_field_value_history(changed_at);

-- Custom field analytics indexes
CREATE INDEX idx_custom_field_analytics_field_definition_id ON custom_field_analytics(field_definition_id);
CREATE INDEX idx_custom_field_analytics_date ON custom_field_analytics(date);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_custom_field_definitions_updated_at BEFORE UPDATE ON custom_field_definitions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_custom_field_values_updated_at BEFORE UPDATE ON custom_field_values FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_custom_field_groups_updated_at BEFORE UPDATE ON custom_field_groups FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_custom_field_templates_updated_at BEFORE UPDATE ON custom_field_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();