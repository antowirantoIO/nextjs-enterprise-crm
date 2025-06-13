-- =====================================================
-- AUTOMATION WORKFLOWS MIGRATION
-- Advanced workflow automation and business process management
-- Created: 2025-06-13 20:13:38 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- WORKFLOW DEFINITIONS
-- =====================================================

-- Workflow categories table
CREATE TABLE workflow_categories (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Category details
                                     name VARCHAR(100) NOT NULL UNIQUE,
                                     slug VARCHAR(100) NOT NULL UNIQUE,
                                     description TEXT,
                                     icon VARCHAR(50),
                                     color VARCHAR(7), -- Hex color

    -- Category settings
                                     is_active BOOLEAN DEFAULT TRUE,
                                     sort_order INTEGER DEFAULT 0,

                                     created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workflow templates table
CREATE TABLE workflow_templates (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    category_id UUID REFERENCES workflow_categories(id),

    -- Template details
                                    name VARCHAR(255) NOT NULL,
                                    slug VARCHAR(100) NOT NULL UNIQUE,
                                    description TEXT,

    -- Template configuration
                                    workflow_definition JSONB NOT NULL, -- The workflow structure
                                    default_settings JSONB DEFAULT '{}',

    -- Template metadata
                                    tags TEXT[],
                                    use_cases TEXT[],
                                    estimated_setup_time INTEGER, -- Minutes to set up

    -- Template status
                                    is_public BOOLEAN DEFAULT TRUE,
                                    is_featured BOOLEAN DEFAULT FALSE,

    -- Usage tracking
                                    usage_count INTEGER DEFAULT 0,
                                    average_rating DECIMAL(2,1) DEFAULT 0.0,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workflows table
CREATE TABLE workflows (
                           id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                           organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                           template_id UUID REFERENCES workflow_templates(id),
                           category_id UUID REFERENCES workflow_categories(id),

    -- Workflow details
                           name VARCHAR(255) NOT NULL,
                           description TEXT,

    -- Workflow configuration
                           workflow_definition JSONB NOT NULL, -- The complete workflow structure
                           version INTEGER DEFAULT 1,

    -- Trigger configuration
                           trigger_type VARCHAR(50) NOT NULL, -- manual, scheduled, event_based, webhook
                           trigger_config JSONB NOT NULL, -- Trigger-specific configuration

    -- Workflow settings
                           is_active BOOLEAN DEFAULT FALSE,
                           run_mode VARCHAR(20) DEFAULT 'automatic', -- automatic, manual_approval, debug

    -- Execution settings
                           max_concurrent_executions INTEGER DEFAULT 10,
                           execution_timeout_minutes INTEGER DEFAULT 60,
                           retry_failed_executions BOOLEAN DEFAULT TRUE,
                           max_retries INTEGER DEFAULT 3,

    -- Scheduling (for scheduled workflows)
                           schedule_cron VARCHAR(100), -- Cron expression
                           schedule_timezone VARCHAR(50) DEFAULT 'UTC',
                           next_scheduled_run TIMESTAMPTZ,

    -- Error handling
                           error_handling_strategy VARCHAR(50) DEFAULT 'stop', -- stop, continue, retry
                           notification_on_error BOOLEAN DEFAULT TRUE,

    -- Statistics
                           total_executions INTEGER DEFAULT 0,
                           successful_executions INTEGER DEFAULT 0,
                           failed_executions INTEGER DEFAULT 0,
                           last_execution_at TIMESTAMPTZ,
                           average_execution_time_ms INTEGER DEFAULT 0,

    -- Metadata
                           created_by UUID REFERENCES user_profiles(id),
                           created_at TIMESTAMPTZ DEFAULT NOW(),
                           updated_at TIMESTAMPTZ DEFAULT NOW(),
                           deleted_at TIMESTAMPTZ
);

-- =====================================================
-- WORKFLOW EXECUTION
-- =====================================================

-- Workflow executions table
CREATE TABLE workflow_executions (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,

    -- Execution details
                                     execution_number INTEGER NOT NULL, -- Sequential number for this workflow

    -- Trigger information
                                     triggered_by VARCHAR(50) NOT NULL, -- manual, scheduled, event, webhook, api
                                     triggered_by_user_id UUID REFERENCES user_profiles(id),
                                     trigger_data JSONB, -- Data that triggered the workflow

    -- Execution status
                                     status VARCHAR(20) DEFAULT 'running', -- pending, running, completed, failed, cancelled, timeout

    -- Execution context
                                     context_data JSONB DEFAULT '{}', -- Shared data across workflow steps

    -- Progress tracking
                                     total_steps INTEGER DEFAULT 0,
                                     completed_steps INTEGER DEFAULT 0,
                                     current_step_id UUID,

    -- Error handling
                                     error_message TEXT,
                                     error_details JSONB,
                                     retry_count INTEGER DEFAULT 0,

    -- Performance metrics
                                     execution_time_ms INTEGER,
                                     memory_usage_mb INTEGER,

    -- Timing
                                     started_at TIMESTAMPTZ DEFAULT NOW(),
                                     completed_at TIMESTAMPTZ,

    -- Workflow snapshot (for debugging/auditing)
                                     workflow_snapshot JSONB, -- Snapshot of workflow definition at execution time

                                     UNIQUE(workflow_id, execution_number)
);

-- Workflow step executions table
CREATE TABLE workflow_step_executions (
                                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                          execution_id UUID NOT NULL REFERENCES workflow_executions(id) ON DELETE CASCADE,

    -- Step identification
                                          step_id VARCHAR(100) NOT NULL, -- ID from workflow definition
                                          step_name VARCHAR(255),
                                          step_type VARCHAR(50) NOT NULL, -- action, condition, loop, parallel, delay, etc.

    -- Execution details
                                          step_order INTEGER NOT NULL,

    -- Status
                                          status VARCHAR(20) DEFAULT 'pending', -- pending, running, completed, failed, skipped, cancelled

    -- Input/Output
                                          input_data JSONB,
                                          output_data JSONB,

    -- Error handling
                                          error_message TEXT,
                                          error_details JSONB,
                                          retry_count INTEGER DEFAULT 0,

    -- Performance
                                          execution_time_ms INTEGER,

    -- Timing
                                          started_at TIMESTAMPTZ,
                                          completed_at TIMESTAMPTZ,

    -- Dependencies
                                          depends_on_steps UUID[], -- Step execution IDs this step depends on

    -- Metadata
                                          metadata JSONB DEFAULT '{}'
);

-- =====================================================
-- WORKFLOW ACTIONS & CONDITIONS
-- =====================================================

-- Workflow action types table
CREATE TABLE workflow_action_types (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Action type details
                                       name VARCHAR(100) NOT NULL UNIQUE,
                                       slug VARCHAR(100) NOT NULL UNIQUE,
                                       description TEXT,
                                       category VARCHAR(50), -- data, communication, integration, logic, etc.

    -- Configuration schema
                                       config_schema JSONB NOT NULL, -- JSON schema for action configuration
                                       input_schema JSONB, -- Schema for input data
                                       output_schema JSONB, -- Schema for output data

    -- Action capabilities
                                       is_async BOOLEAN DEFAULT FALSE, -- Can run asynchronously
                                       supports_retry BOOLEAN DEFAULT TRUE,
                                       max_execution_time_ms INTEGER DEFAULT 30000,

    -- Integration requirements
                                       requires_integration BOOLEAN DEFAULT FALSE,
                                       supported_integrations TEXT[], -- Integration provider slugs

    -- UI configuration
                                       icon VARCHAR(50),
                                       color VARCHAR(7),

    -- Status
                                       is_active BOOLEAN DEFAULT TRUE,
                                       is_premium BOOLEAN DEFAULT FALSE,

                                       created_at TIMESTAMPTZ DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- WORKFLOW CONDITIONS & FILTERS
-- =====================================================

-- Workflow condition types table
CREATE TABLE workflow_condition_types (
                                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Condition type details
                                          name VARCHAR(100) NOT NULL UNIQUE,
                                          slug VARCHAR(100) NOT NULL UNIQUE,
                                          description TEXT,

    -- Configuration
                                          evaluation_function VARCHAR(100) NOT NULL, -- Function to evaluate the condition
                                          config_schema JSONB NOT NULL,

    -- Supported data types
                                          supported_data_types VARCHAR(50)[], -- string, number, boolean, date, array, object

    -- UI configuration
                                          operator_label VARCHAR(50), -- equals, contains, greater_than, etc.

    -- Status
                                          is_active BOOLEAN DEFAULT TRUE,

                                          created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- WORKFLOW VARIABLES & DATA
-- =====================================================

-- Workflow variables table (for storing workflow-specific data)
CREATE TABLE workflow_variables (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,

    -- Variable details
                                    variable_name VARCHAR(100) NOT NULL,
                                    variable_type VARCHAR(50) NOT NULL, -- string, number, boolean, date, json, encrypted
                                    description TEXT,

    -- Value storage
                                    string_value TEXT,
                                    number_value DECIMAL(15,4),
                                    boolean_value BOOLEAN,
                                    date_value TIMESTAMPTZ,
                                    json_value JSONB,
                                    encrypted_value TEXT, -- For sensitive data

    -- Variable settings
                                    is_global BOOLEAN DEFAULT FALSE, -- Available across all workflow executions
                                    is_encrypted BOOLEAN DEFAULT FALSE,
                                    is_required BOOLEAN DEFAULT FALSE,

    -- Default value
                                    default_value JSONB,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW(),

                                    UNIQUE(workflow_id, variable_name)
);

-- Workflow execution variables table (instance-specific variables)
CREATE TABLE workflow_execution_variables (
                                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                              execution_id UUID NOT NULL REFERENCES workflow_executions(id) ON DELETE CASCADE,

    -- Variable details
                                              variable_name VARCHAR(100) NOT NULL,
                                              variable_type VARCHAR(50) NOT NULL,

    -- Value storage (same structure as workflow_variables)
                                              string_value TEXT,
                                              number_value DECIMAL(15,4),
                                              boolean_value BOOLEAN,
                                              date_value TIMESTAMPTZ,
                                              json_value JSONB,

    -- Variable lifecycle
                                              created_at_step_id UUID REFERENCES workflow_step_executions(id),
                                              last_updated_step_id UUID REFERENCES workflow_step_executions(id),

                                              created_at TIMESTAMPTZ DEFAULT NOW(),
                                              updated_at TIMESTAMPTZ DEFAULT NOW(),

                                              UNIQUE(execution_id, variable_name)
);

-- =====================================================
-- WORKFLOW APPROVALS
-- =====================================================

-- Workflow approval steps table
CREATE TABLE workflow_approval_steps (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         step_execution_id UUID NOT NULL REFERENCES workflow_step_executions(id) ON DELETE CASCADE,

    -- Approval details
                                         approval_type VARCHAR(50) NOT NULL, -- user, role, manager, external

    -- Approver configuration
                                         approver_user_id UUID REFERENCES user_profiles(id),
                                         approver_role user_role,
                                         approver_email VARCHAR(255), -- For external approvers

    -- Approval request
                                         request_title VARCHAR(255) NOT NULL,
                                         request_description TEXT,
                                         request_data JSONB,

    -- Approval response
                                         status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected, expired
                                         response_comment TEXT,

    -- Timing
                                         requested_at TIMESTAMPTZ DEFAULT NOW(),
                                         expires_at TIMESTAMPTZ,
                                         responded_at TIMESTAMPTZ,

    -- Metadata
                                         metadata JSONB DEFAULT '{}'
);

-- =====================================================
-- WORKFLOW SCHEDULING & RECURRENCE
-- =====================================================

-- Workflow schedules table
CREATE TABLE workflow_schedules (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,

    -- Schedule details
                                    name VARCHAR(255),
                                    description TEXT,

    -- Schedule configuration
                                    schedule_type VARCHAR(50) NOT NULL, -- cron, interval, one_time
                                    cron_expression VARCHAR(100), -- For cron-based schedules
                                    interval_minutes INTEGER, -- For interval-based schedules

    -- Schedule boundaries
                                    start_date TIMESTAMPTZ,
                                    end_date TIMESTAMPTZ,
                                    max_executions INTEGER, -- Maximum number of executions

    -- Timezone
                                    timezone VARCHAR(50) DEFAULT 'UTC',

    -- Status
                                    is_active BOOLEAN DEFAULT TRUE,

    -- Execution tracking
                                    executions_count INTEGER DEFAULT 0,
                                    last_execution_at TIMESTAMPTZ,
                                    next_execution_at TIMESTAMPTZ,

    -- Error handling
                                    consecutive_failures INTEGER DEFAULT 0,
                                    max_consecutive_failures INTEGER DEFAULT 5,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- WORKFLOW ANALYTICS & REPORTING
-- =====================================================

-- Workflow analytics table
CREATE TABLE workflow_analytics (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,

    -- Analytics period
                                    period_type VARCHAR(20) NOT NULL, -- hour, day, week, month
                                    period_start TIMESTAMPTZ NOT NULL,
                                    period_end TIMESTAMPTZ NOT NULL,

    -- Execution metrics
                                    total_executions INTEGER DEFAULT 0,
                                    successful_executions INTEGER DEFAULT 0,
                                    failed_executions INTEGER DEFAULT 0,
                                    cancelled_executions INTEGER DEFAULT 0,

    -- Performance metrics
                                    average_execution_time_ms INTEGER DEFAULT 0,
                                    min_execution_time_ms INTEGER,
                                    max_execution_time_ms INTEGER,

    -- Error analysis
                                    most_common_errors JSONB, -- {error_type: count}
                                    error_rate DECIMAL(5,2) DEFAULT 0, -- Percentage of failed executions

    -- Step analysis
                                    slowest_steps JSONB, -- {step_type: avg_time_ms}
                                    most_failed_steps JSONB, -- {step_type: failure_count}

    -- Resource usage
                                    total_processing_time_ms BIGINT DEFAULT 0,
                                    average_memory_usage_mb INTEGER DEFAULT 0,

    -- Metadata
                                    calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                    UNIQUE(workflow_id, period_type, period_start)
);

-- =====================================================
-- FUNCTIONS FOR WORKFLOWS
-- =====================================================

-- Function to execute workflow
CREATE OR REPLACE FUNCTION execute_workflow(
    workflow_uuid UUID,
    trigger_data_param JSONB DEFAULT '{}',
    triggered_by_param VARCHAR(50) DEFAULT 'manual',
    triggered_by_user_uuid UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
execution_id UUID;
    workflow_record RECORD;
    execution_number INTEGER;
BEGIN
    -- Get workflow details
SELECT * INTO workflow_record FROM workflows WHERE id = workflow_uuid AND is_active = TRUE;

IF NOT FOUND THEN
        RAISE EXCEPTION 'Workflow not found or inactive: %', workflow_uuid;
END IF;

    -- Check concurrent execution limit
    IF (SELECT COUNT(*) FROM workflow_executions
        WHERE workflow_id = workflow_uuid AND status IN ('pending', 'running'))
       >= workflow_record.max_concurrent_executions THEN
        RAISE EXCEPTION 'Maximum concurrent executions reached for workflow: %', workflow_uuid;
END IF;

    -- Get next execution number
SELECT COALESCE(MAX(execution_number), 0) + 1 INTO execution_number
FROM workflow_executions
WHERE workflow_id = workflow_uuid;

-- Create execution record
INSERT INTO workflow_executions (
    workflow_id,
    execution_number,
    triggered_by,
    triggered_by_user_id,
    trigger_data,
    context_data,
    workflow_snapshot,
    status
) VALUES (
             workflow_uuid,
             execution_number,
             triggered_by_param,
             triggered_by_user_uuid,
             trigger_data_param,
             trigger_data_param, -- Initialize context with trigger data
             workflow_record.workflow_definition,
             'pending'
         ) RETURNING id INTO execution_id;

-- Update workflow statistics
UPDATE workflows
SET
    total_executions = total_executions + 1,
    last_execution_at = NOW()
WHERE id = workflow_uuid;

-- The actual workflow execution would be handled by the application layer
-- This function just creates the execution record and returns the ID

RETURN execution_id;
END;
$$ LANGUAGE plpgsql;

-- Function to complete workflow step
CREATE OR REPLACE FUNCTION complete_workflow_step(
    step_execution_uuid UUID,
    output_data_param JSONB DEFAULT '{}',
    status_param VARCHAR(20) DEFAULT 'completed'
)
RETURNS VOID AS $$
DECLARE
step_record RECORD;
    execution_record RECORD;
BEGIN
    -- Get step execution record
SELECT * INTO step_record FROM workflow_step_executions WHERE id = step_execution_uuid;

IF NOT FOUND THEN
        RAISE EXCEPTION 'Step execution not found: %', step_execution_uuid;
END IF;

    -- Get workflow execution record
SELECT * INTO execution_record FROM workflow_executions WHERE id = step_record.execution_id;

-- Update step execution
UPDATE workflow_step_executions
SET
    status = status_param,
    output_data = output_data_param,
    completed_at = NOW(),
    execution_time_ms = EXTRACT(EPOCH FROM (NOW() - started_at)) * 1000
WHERE id = step_execution_uuid;

-- Update workflow execution progress
UPDATE workflow_executions
SET
    completed_steps = (
        SELECT COUNT(*)
        FROM workflow_step_executions
        WHERE execution_id = step_record.execution_id
          AND status = 'completed'
    ),
    context_data = context_data || output_data_param -- Merge output into context
WHERE id = step_record.execution_id;

-- Check if all steps are completed
IF (SELECT completed_steps FROM workflow_executions WHERE id = step_record.execution_id) =
       (SELECT total_steps FROM workflow_executions WHERE id = step_record.execution_id) THEN

-- Complete the workflow execution
UPDATE workflow_executions
SET
    status = 'completed',
    completed_at = NOW(),
    execution_time_ms = EXTRACT(EPOCH FROM (NOW() - started_at)) * 1000
WHERE id = step_record.execution_id;

-- Update workflow statistics
UPDATE workflows
SET
    successful_executions = successful_executions + 1,
    average_execution_time_ms = (
        SELECT AVG(execution_time_ms)::INTEGER
        FROM workflow_executions
        WHERE workflow_id = execution_record.workflow_id
          AND status = 'completed'
    )
WHERE id = execution_record.workflow_id;
END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate workflow analytics
CREATE OR REPLACE FUNCTION calculate_workflow_analytics(
    workflow_uuid UUID,
    period_start_param TIMESTAMPTZ,
    period_end_param TIMESTAMPTZ,
    period_type_param VARCHAR(20)
)
RETURNS UUID AS $$
DECLARE
analytics_id UUID;
    total_execs INTEGER;
    successful_execs INTEGER;
    failed_execs INTEGER;
    cancelled_execs INTEGER;
    avg_time INTEGER;
    error_rate DECIMAL(5,2);
BEGIN
    -- Calculate metrics
SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'completed'),
    COUNT(*) FILTER (WHERE status = 'failed'),
    COUNT(*) FILTER (WHERE status = 'cancelled'),
    AVG(execution_time_ms)::INTEGER
INTO total_execs, successful_execs, failed_execs, cancelled_execs, avg_time
FROM workflow_executions
WHERE workflow_id = workflow_uuid
  AND started_at BETWEEN period_start_param AND period_end_param;

-- Calculate error rate
error_rate := CASE
        WHEN total_execs > 0 THEN (failed_execs::DECIMAL / total_execs) * 100
        ELSE 0
END;

    -- Insert analytics record
INSERT INTO workflow_analytics (
    workflow_id,
    period_type,
    period_start,
    period_end,
    total_executions,
    successful_executions,
    failed_executions,
    cancelled_executions,
    average_execution_time_ms,
    error_rate
) VALUES (
             workflow_uuid,
             period_type_param,
             period_start_param,
             period_end_param,
             total_execs,
             successful_execs,
             failed_execs,
             cancelled_execs,
             avg_time,
             error_rate
         ) RETURNING id INTO analytics_id;

RETURN analytics_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Workflows indexes
CREATE INDEX idx_workflows_organization_id ON workflows(organization_id);
CREATE INDEX idx_workflows_category_id ON workflows(category_id);
CREATE INDEX idx_workflows_active ON workflows(is_active);
CREATE INDEX idx_workflows_next_scheduled ON workflows(next_scheduled_run) WHERE schedule_cron IS NOT NULL;

-- Workflow executions indexes
CREATE INDEX idx_workflow_executions_workflow_id ON workflow_executions(workflow_id);
CREATE INDEX idx_workflow_executions_status ON workflow_executions(status);
CREATE INDEX idx_workflow_executions_started_at ON workflow_executions(started_at);

-- Workflow step executions indexes
CREATE INDEX idx_workflow_step_executions_execution_id ON workflow_step_executions(execution_id);
CREATE INDEX idx_workflow_step_executions_status ON workflow_step_executions(status);
CREATE INDEX idx_workflow_step_executions_step_type ON workflow_step_executions(step_type);

-- Workflow variables indexes
CREATE INDEX idx_workflow_variables_workflow_id ON workflow_variables(workflow_id);
CREATE INDEX idx_workflow_execution_variables_execution_id ON workflow_execution_variables(execution_id);

-- Workflow analytics indexes
CREATE INDEX idx_workflow_analytics_workflow_id ON workflow_analytics(workflow_id);
CREATE INDEX idx_workflow_analytics_period ON workflow_analytics(period_type, period_start);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_workflow_templates_updated_at BEFORE UPDATE ON workflow_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workflows_updated_at BEFORE UPDATE ON workflows FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workflow_action_types_updated_at BEFORE UPDATE ON workflow_action_types FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workflow_variables_updated_at BEFORE UPDATE ON workflow_variables FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workflow_schedules_updated_at BEFORE UPDATE ON workflow_schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();