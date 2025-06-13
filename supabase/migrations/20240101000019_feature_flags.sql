-- =====================================================
-- FEATURE FLAGS MIGRATION
-- Advanced feature flag management and experimentation
-- Created: 2025-06-13 20:32:55 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- FEATURE FLAG SYSTEM
-- =====================================================

-- Enhanced feature flags table (replacing basic one)
DROP TABLE IF EXISTS feature_flags;
CREATE TABLE feature_flags (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE, -- NULL for global flags

    -- Flag identification
                               flag_key VARCHAR(100) NOT NULL,
                               name VARCHAR(255) NOT NULL,
                               description TEXT,

    -- Flag type and behavior
                               flag_type VARCHAR(50) DEFAULT 'boolean', -- boolean, string, number, json, percentage

    -- Flag configuration
                               default_value JSONB DEFAULT 'false',
                               variations JSONB DEFAULT '[]', -- Array of possible values for multi-variant flags

    -- Flag status
                               status feature_flag_status DEFAULT 'disabled',

    -- Rollout configuration
                               rollout_percentage INTEGER DEFAULT 0 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),
                               rollout_strategy VARCHAR(50) DEFAULT 'percentage', -- percentage, user_list, attribute_based, gradual

    -- Targeting rules
                               targeting_rules JSONB DEFAULT '[]', -- Array of targeting rule objects

    -- Environment and context
                               environment VARCHAR(50) DEFAULT 'production', -- development, staging, production

    -- Feature flag lifecycle
                               created_for VARCHAR(100), -- Feature/experiment this flag was created for
                               temporary BOOLEAN DEFAULT FALSE, -- Should this flag be removed after rollout?
                               removal_date DATE, -- When this flag should be removed

    -- Dependencies
                               depends_on_flags UUID[], -- Other flags this flag depends on
                               conflicts_with_flags UUID[], -- Flags that conflict with this one

    -- Analytics and monitoring
                               track_events BOOLEAN DEFAULT TRUE,
                               custom_events TEXT[] DEFAULT '{}',

    -- External integration
                               external_provider VARCHAR(50), -- launchdarkly, split, custom
                               external_flag_id VARCHAR(255),
                               sync_with_external BOOLEAN DEFAULT FALSE,

    -- Access control
                               editable_by_roles user_role[] DEFAULT '{admin}',
                               viewable_by_roles user_role[] DEFAULT '{admin,manager}',

    -- Metadata
                               tags TEXT[] DEFAULT '{}',

    -- Audit fields
                               created_by UUID REFERENCES user_profiles(id),
                               last_modified_by UUID REFERENCES user_profiles(id),
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
                               UNIQUE(organization_id, flag_key),
                               UNIQUE(flag_key) WHERE organization_id IS NULL -- Global flags must have unique keys
);

-- Feature flag environments table
CREATE TABLE feature_flag_environments (
                                           id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                           flag_id UUID NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,

    -- Environment details
                                           environment_name VARCHAR(50) NOT NULL,

    -- Environment-specific configuration
                                           is_enabled BOOLEAN DEFAULT FALSE,
                                           rollout_percentage INTEGER DEFAULT 0,
                                           default_value JSONB DEFAULT 'false',

    -- Environment-specific targeting
                                           targeting_rules JSONB DEFAULT '[]',

    -- Environment metadata
                                           last_modified_by UUID REFERENCES user_profiles(id),
                                           modified_at TIMESTAMPTZ DEFAULT NOW(),

                                           UNIQUE(flag_id, environment_name)
);

-- =====================================================
-- TARGETING & SEGMENTATION
-- =====================================================

-- User segments table (for advanced targeting)
CREATE TABLE user_segments (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Segment details
                               name VARCHAR(255) NOT NULL,
                               description TEXT,

    -- Segment type
                               segment_type VARCHAR(50) DEFAULT 'dynamic', -- static, dynamic, custom

    -- Segment criteria
                               criteria JSONB NOT NULL, -- Conditions for segment membership

    -- Segment settings
                               is_active BOOLEAN DEFAULT TRUE,
                               auto_update BOOLEAN DEFAULT TRUE, -- For dynamic segments

    -- Segment statistics
                               member_count INTEGER DEFAULT 0,
                               last_calculated_at TIMESTAMPTZ,

    -- Metadata
                               created_by UUID REFERENCES user_profiles(id),
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),

                               UNIQUE(organization_id, name)
);

-- User segment members table
CREATE TABLE user_segment_members (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      segment_id UUID NOT NULL REFERENCES user_segments(id) ON DELETE CASCADE,
                                      user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Membership details
                                      added_at TIMESTAMPTZ DEFAULT NOW(),
                                      added_by_rule BOOLEAN DEFAULT TRUE, -- True if added by segment criteria, false if manual

    -- Membership metadata
                                      metadata JSONB DEFAULT '{}',

                                      UNIQUE(segment_id, user_id)
);

-- Feature flag targeting rules table
CREATE TABLE flag_targeting_rules (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      flag_id UUID NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,
                                      environment_name VARCHAR(50) DEFAULT 'production',

    -- Rule details
                                      rule_name VARCHAR(255),
                                      rule_description TEXT,
                                      priority INTEGER DEFAULT 0, -- Higher number = higher priority

    -- Rule conditions
                                      conditions JSONB NOT NULL, -- Targeting conditions

    -- Rule outcome
                                      enabled BOOLEAN DEFAULT TRUE,
                                      value JSONB, -- Value to return if rule matches
                                      rollout_percentage INTEGER DEFAULT 100,

    -- Rule status
                                      is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                      created_by UUID REFERENCES user_profiles(id),
                                      created_at TIMESTAMPTZ DEFAULT NOW(),
                                      updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- FEATURE FLAG EVALUATIONS & ANALYTICS
-- =====================================================

-- Feature flag evaluations table (for analytics)
CREATE TABLE flag_evaluations (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  flag_id UUID NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,
                                  user_id UUID REFERENCES user_profiles(id),

    -- Evaluation context
                                  environment VARCHAR(50) DEFAULT 'production',
                                  user_key VARCHAR(255), -- For anonymous users

    -- Evaluation result
                                  value JSONB NOT NULL,
                                  variation_name VARCHAR(100),

    -- Evaluation metadata
                                  rule_id UUID REFERENCES flag_targeting_rules(id),
                                  reason VARCHAR(100), -- default, rule_match, percentage_rollout, user_override

    -- Request context
                                  session_id VARCHAR(255),
                                  ip_address INET,
                                  user_agent TEXT,

    -- Timing
                                  evaluated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Additional context
                                  context_attributes JSONB DEFAULT '{}'
);

-- Feature flag analytics table (aggregated metrics)
CREATE TABLE flag_analytics (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                flag_id UUID NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,

    -- Analytics period
                                date DATE NOT NULL,
                                environment VARCHAR(50) DEFAULT 'production',

    -- Evaluation metrics
                                total_evaluations INTEGER DEFAULT 0,
                                unique_users INTEGER DEFAULT 0,

    -- Variation breakdown
                                variation_breakdown JSONB DEFAULT '{}', -- {variation: count}

    -- Performance metrics
                                average_evaluation_time_ms DECIMAL(8,2) DEFAULT 0,

    -- Error metrics
                                evaluation_errors INTEGER DEFAULT 0,

    -- Metadata
                                calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                UNIQUE(flag_id, date, environment)
);

-- =====================================================
-- FEATURE FLAG EXPERIMENTS
-- =====================================================

-- Feature experiments table (A/B testing with feature flags)
CREATE TABLE feature_experiments (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                     flag_id UUID NOT NULL REFERENCES feature_flags(id),

    -- Experiment details
                                     name VARCHAR(255) NOT NULL,
                                     description TEXT,
                                     hypothesis TEXT,

    -- Experiment configuration
                                     experiment_key VARCHAR(100) NOT NULL,

    -- Variations (must match flag variations)
                                     control_variation VARCHAR(100) NOT NULL,
                                     treatment_variations JSONB NOT NULL, -- Array of treatment variation names

    -- Traffic allocation
                                     traffic_allocation DECIMAL(5,2) DEFAULT 100.00, -- Percentage of users to include

    -- Success metrics
                                     primary_metric VARCHAR(100), -- Main metric to optimize
                                     secondary_metrics JSONB DEFAULT '[]', -- Additional metrics to track

    -- Statistical configuration
                                     minimum_sample_size INTEGER DEFAULT 1000,
                                     minimum_duration_days INTEGER DEFAULT 7,
                                     statistical_significance_threshold DECIMAL(3,2) DEFAULT 0.05,
                                     minimum_effect_size DECIMAL(5,2) DEFAULT 5.0, -- Minimum % improvement to detect

    -- Experiment status
                                     status VARCHAR(20) DEFAULT 'draft', -- draft, running, paused, completed, cancelled

    -- Experiment timeline
                                     planned_start_date DATE,
                                     planned_end_date DATE,
                                     actual_start_date DATE,
                                     actual_end_date DATE,

    -- Results
                                     winner_variation VARCHAR(100),
                                     confidence_level DECIMAL(5,2),
                                     effect_size DECIMAL(8,4),
                                     results_summary TEXT,

    -- Decision information
                                     decision VARCHAR(50), -- launch_treatment, keep_control, inconclusive, need_more_data
                                     decision_reason TEXT,
                                     decided_by UUID REFERENCES user_profiles(id),
                                     decided_at TIMESTAMPTZ,

    -- Metadata
                                     created_by UUID REFERENCES user_profiles(id),
                                     created_at TIMESTAMPTZ DEFAULT NOW(),
                                     updated_at TIMESTAMPTZ DEFAULT NOW(),

                                     UNIQUE(organization_id, experiment_key)
);

-- Experiment participants table
CREATE TABLE experiment_participants (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         experiment_id UUID NOT NULL REFERENCES feature_experiments(id) ON DELETE CASCADE,
                                         user_id UUID REFERENCES user_profiles(id),
                                         user_key VARCHAR(255), -- For anonymous users

    -- Assignment details
                                         assigned_variation VARCHAR(100) NOT NULL,
                                         assigned_at TIMESTAMPTZ DEFAULT NOW(),

    -- Participant metadata
                                         user_attributes JSONB DEFAULT '{}',

    -- Conversion tracking
                                         has_converted BOOLEAN DEFAULT FALSE,
                                         converted_at TIMESTAMPTZ,
                                         conversion_value DECIMAL(15,2),

                                         UNIQUE(experiment_id, COALESCE(user_id::text, user_key))
);

-- =====================================================
-- FEATURE FLAG MANAGEMENT
-- =====================================================

-- Flag change requests table (approval workflow)
CREATE TABLE flag_change_requests (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      flag_id UUID NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,

    -- Request details
                                      title VARCHAR(255) NOT NULL,
                                      description TEXT,
                                      change_type VARCHAR(50) NOT NULL, -- enable, disable, update_targeting, update_value, rollout_increase

    -- Proposed changes
                                      proposed_changes JSONB NOT NULL,

    -- Request status
                                      status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected, implemented, cancelled

    -- Approval workflow
                                      requires_approval BOOLEAN DEFAULT TRUE,
                                      approver_role user_role,
                                      approved_by UUID REFERENCES user_profiles(id),
                                      approved_at TIMESTAMPTZ,
                                      rejection_reason TEXT,

    -- Implementation
                                      implemented_by UUID REFERENCES user_profiles(id),
                                      implemented_at TIMESTAMPTZ,
                                      rollback_info JSONB, -- Information needed to rollback the change

    -- Scheduling
                                      scheduled_for TIMESTAMPTZ,
                                      auto_implement BOOLEAN DEFAULT FALSE,

    -- Metadata
                                      requested_by UUID REFERENCES user_profiles(id),
                                      created_at TIMESTAMPTZ DEFAULT NOW(),
                                      updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Flag audit log table (detailed change history)
CREATE TABLE flag_audit_log (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                flag_id UUID NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,
                                change_request_id UUID REFERENCES flag_change_requests(id),

    -- Change details
                                action VARCHAR(50) NOT NULL, -- created, updated, enabled, disabled, deleted
                                field_changed VARCHAR(100), -- Which field was changed
                                old_value JSONB,
                                new_value JSONB,

    -- Change context
                                environment VARCHAR(50),
                                change_reason VARCHAR(255),

    -- Change metadata
                                changed_by UUID REFERENCES user_profiles(id),
                                changed_at TIMESTAMPTZ DEFAULT NOW(),

    -- External integration
                                external_change_id VARCHAR(255),

    -- Change impact
                                affected_users_count INTEGER,
                                rollback_id UUID REFERENCES flag_audit_log(id) -- If this change was rolled back
);

-- =====================================================
-- FUNCTIONS FOR FEATURE FLAGS
-- =====================================================

-- Function to evaluate feature flag for user
CREATE OR REPLACE FUNCTION evaluate_feature_flag(
    flag_key_param VARCHAR(100),
    user_uuid UUID DEFAULT NULL,
    user_key_param VARCHAR(255) DEFAULT NULL,
    environment_param VARCHAR(50) DEFAULT 'production',
    context_attributes JSONB DEFAULT '{}',
    org_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
flag_record RECORD;
    user_record RECORD;
    rule_record RECORD;
    evaluation_result JSONB;
    flag_value JSONB;
    variation_name VARCHAR(100);
    evaluation_reason VARCHAR(100) := 'default';
    rule_matched UUID;
BEGIN
    -- Get organization ID
    org_id := COALESCE(org_id, auth.user_organization_id());

    -- Get feature flag
SELECT * INTO flag_record
FROM feature_flags
WHERE flag_key = flag_key_param
  AND (organization_id = org_id OR organization_id IS NULL)
  AND status != 'disabled'
ORDER BY organization_id NULLS LAST -- Prefer org-specific flags
    LIMIT 1;

IF NOT FOUND THEN
        -- Return default false for non-existent flags
        RETURN jsonb_build_object(
            'enabled', false,
            'value', false,
            'reason', 'flag_not_found'
        );
END IF;

    -- Get user information if available
    IF user_uuid IS NOT NULL THEN
SELECT * INTO user_record FROM user_profiles WHERE id = user_uuid;
END IF;

    -- Check if flag is globally disabled
    IF flag_record.status = 'disabled' THEN
        flag_value := flag_record.default_value;
        evaluation_reason := 'flag_disabled';
ELSE
        -- Evaluate targeting rules in priority order
        FOR rule_record IN
SELECT * FROM flag_targeting_rules
WHERE flag_id = flag_record.id
  AND environment_name = environment_param
  AND is_active = TRUE
ORDER BY priority DESC
    LOOP
            -- Simple rule evaluation (can be enhanced with complex targeting)
            -- Check user role condition
            IF rule_record.conditions ? 'user_role' AND user_record.role IS NOT NULL THEN
                IF (rule_record.conditions->>'user_role') = user_record.role::TEXT THEN
                    flag_value := rule_record.value;
evaluation_reason := 'rule_match';
                    rule_matched := rule_record.id;
                    EXIT;
END IF;
END IF;

            -- Check user ID condition
            IF rule_record.conditions ? 'user_ids' AND user_uuid IS NOT NULL THEN
                IF user_uuid::TEXT = ANY(ARRAY(SELECT jsonb_array_elements_text(rule_record.conditions->'user_ids'))) THEN
                    flag_value := rule_record.value;
                    evaluation_reason := 'user_override';
                    rule_matched := rule_record.id;
                    EXIT;
END IF;
END IF;
END LOOP;

        -- If no rule matched, use percentage rollout
        IF flag_value IS NULL THEN
            -- Simple percentage rollout based on user ID hash
            IF flag_record.rollout_percentage > 0 THEN
                DECLARE
user_hash INTEGER;
                    user_identifier TEXT;
BEGIN
                    user_identifier := COALESCE(user_uuid::TEXT, user_key_param, 'anonymous');
                    user_hash := abs(hashtext(flag_record.flag_key || user_identifier)) % 100 + 1;

                    IF user_hash <= flag_record.rollout_percentage THEN
                        flag_value := jsonb_build_object('enabled', true);
                        evaluation_reason := 'percentage_rollout';
ELSE
                        flag_value := flag_record.default_value;
                        evaluation_reason := 'percentage_excluded';
END IF;
END;
ELSE
                flag_value := flag_record.default_value;
                evaluation_reason := 'default';
END IF;
END IF;
END IF;

    -- Log the evaluation
INSERT INTO flag_evaluations (
    flag_id,
    user_id,
    user_key,
    environment,
    value,
    rule_id,
    reason,
    context_attributes
) VALUES (
             flag_record.id,
             user_uuid,
             user_key_param,
             environment_param,
             flag_value,
             rule_matched,
             evaluation_reason,
             context_attributes
         );

-- Build result
evaluation_result := jsonb_build_object(
        'enabled', CASE
            WHEN flag_value ? 'enabled' THEN flag_value->>'enabled'
            ELSE flag_value
        END,
        'value', flag_value,
        'reason', evaluation_reason,
        'flag_key', flag_record.flag_key,
        'variation', variation_name
    );

RETURN evaluation_result;
END;
$$ LANGUAGE plpgsql;

-- Function to update user segment membership
CREATE OR REPLACE FUNCTION update_user_segment_membership(
    segment_uuid UUID
)
RETURNS INTEGER AS $$
DECLARE
segment_record RECORD;
    user_record RECORD;
    members_added INTEGER := 0;
    members_removed INTEGER := 0;
BEGIN
    -- Get segment details
SELECT * INTO segment_record FROM user_segments WHERE id = segment_uuid;

IF NOT FOUND OR NOT segment_record.auto_update THEN
        RETURN 0;
END IF;

    -- Remove existing auto-added members
DELETE FROM user_segment_members
WHERE segment_id = segment_uuid
  AND added_by_rule = TRUE;

GET DIAGNOSTICS members_removed = ROW_COUNT;

-- Add users that match criteria
FOR user_record IN
SELECT * FROM user_profiles
WHERE organization_id = segment_record.organization_id
  AND status = 'active'
    LOOP
        -- Simple criteria evaluation (can be enhanced)
        -- Check role criteria
        IF segment_record.criteria ? 'roles' THEN
            IF user_record.role::TEXT = ANY(ARRAY(SELECT jsonb_array_elements_text(segment_record.criteria->'roles'))) THEN
INSERT INTO user_segment_members (segment_id, user_id, added_by_rule)
VALUES (segment_uuid, user_record.id, TRUE)
ON CONFLICT (segment_id, user_id) DO NOTHING;

members_added := members_added + 1;
END IF;
END IF;

        -- Check created date criteria
        IF segment_record.criteria ? 'created_after' THEN
            IF user_record.created_at >= (segment_record.criteria->>'created_after')::TIMESTAMPTZ THEN
                INSERT INTO user_segment_members (segment_id, user_id, added_by_rule)
                VALUES (segment_uuid, user_record.id, TRUE)
                ON CONFLICT (segment_id, user_id) DO NOTHING;

                members_added := members_added + 1;
END IF;
END IF;
END LOOP;

    -- Update segment member count
UPDATE user_segments
SET
    member_count = (SELECT COUNT(*) FROM user_segment_members WHERE segment_id = segment_uuid),
    last_calculated_at = NOW()
WHERE id = segment_uuid;

RETURN members_added;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate flag analytics
CREATE OR REPLACE FUNCTION calculate_flag_analytics(
    flag_uuid UUID,
    analytics_date DATE,
    environment_param VARCHAR(50) DEFAULT 'production'
)
RETURNS VOID AS $$
DECLARE
total_evals INTEGER;
    unique_users_count INTEGER;
    variation_data JSONB := '{}';
    avg_eval_time DECIMAL(8,2);
    error_count INTEGER;
BEGIN
    -- Calculate metrics for the specified date
SELECT
    COUNT(*),
    COUNT(DISTINCT COALESCE(user_id::text, user_key)),
    AVG(EXTRACT(EPOCH FROM (NOW() - evaluated_at)) * 1000),
    COUNT(*) FILTER (WHERE reason = 'error')
INTO
    total_evals,
    unique_users_count,
    avg_eval_time,
    error_count
FROM flag_evaluations
WHERE flag_id = flag_uuid
  AND environment = environment_param
  AND evaluated_at::DATE = analytics_date;

-- Calculate variation breakdown
SELECT jsonb_object_agg(variation_name, count)
INTO variation_data
FROM (
         SELECT
             COALESCE(variation_name, 'default') as variation_name,
             COUNT(*) as count
         FROM flag_evaluations
         WHERE flag_id = flag_uuid
           AND environment = environment_param
           AND evaluated_at::DATE = analytics_date
         GROUP BY variation_name
     ) t;

-- Insert or update analytics record
INSERT INTO flag_analytics (
    flag_id,
    date,
    environment,
    total_evaluations,
    unique_users,
    variation_breakdown,
    average_evaluation_time_ms,
    evaluation_errors
) VALUES (
             flag_uuid,
             analytics_date,
             environment_param,
             total_evals,
             unique_users_count,
             variation_data,
             avg_eval_time,
             error_count
         )
    ON CONFLICT (flag_id, date, environment)
    DO UPDATE SET
    total_evaluations = EXCLUDED.total_evaluations,
               unique_users = EXCLUDED.unique_users,
               variation_breakdown = EXCLUDED.variation_breakdown,
               average_evaluation_time_ms = EXCLUDED.average_evaluation_time_ms,
               evaluation_errors = EXCLUDED.evaluation_errors,
               calculated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Feature flags indexes
CREATE INDEX idx_feature_flags_organization_id ON feature_flags(organization_id);
CREATE INDEX idx_feature_flags_flag_key ON feature_flags(flag_key);
CREATE INDEX idx_feature_flags_status ON feature_flags(status);
CREATE INDEX idx_feature_flags_environment ON feature_flags(environment);
CREATE INDEX idx_feature_flags_rollout_percentage ON feature_flags(rollout_percentage);

-- Feature flag environments indexes
CREATE INDEX idx_flag_environments_flag_id ON feature_flag_environments(flag_id);
CREATE INDEX idx_flag_environments_environment ON feature_flag_environments(environment_name);

-- User segments indexes
CREATE INDEX idx_user_segments_organization_id ON user_segments(organization_id);
CREATE INDEX idx_user_segments_segment_type ON user_segments(segment_type);
CREATE INDEX idx_user_segments_active ON user_segments(is_active);

-- User segment members indexes
CREATE INDEX idx_user_segment_members_segment_id ON user_segment_members(segment_id);
CREATE INDEX idx_user_segment_members_user_id ON user_segment_members(user_id);

-- Flag targeting rules indexes
CREATE INDEX idx_flag_targeting_rules_flag_id ON flag_targeting_rules(flag_id);
CREATE INDEX idx_flag_targeting_rules_environment ON flag_targeting_rules(environment_name);
CREATE INDEX idx_flag_targeting_rules_priority ON flag_targeting_rules(priority);

-- Flag evaluations indexes
CREATE INDEX idx_flag_evaluations_flag_id ON flag_evaluations(flag_id);
CREATE INDEX idx_flag_evaluations_user_id ON flag_evaluations(user_id);
CREATE INDEX idx_flag_evaluations_environment ON flag_evaluations(environment);
CREATE INDEX idx_flag_evaluations_evaluated_at ON flag_evaluations(evaluated_at);

-- Flag analytics indexes
CREATE INDEX idx_flag_analytics_flag_id ON flag_analytics(flag_id);
CREATE INDEX idx_flag_analytics_date ON flag_analytics(date);
CREATE INDEX idx_flag_analytics_environment ON flag_analytics(environment);

-- Feature experiments indexes
CREATE INDEX idx_feature_experiments_organization_id ON feature_experiments(organization_id);
CREATE INDEX idx_feature_experiments_flag_id ON feature_experiments(flag_id);
CREATE INDEX idx_feature_experiments_status ON feature_experiments(status);
CREATE INDEX idx_feature_experiments_experiment_key ON feature_experiments(experiment_key);

-- Experiment participants indexes
CREATE INDEX idx_experiment_participants_experiment_id ON experiment_participants(experiment_id);
CREATE INDEX idx_experiment_participants_user_id ON experiment_participants(user_id);
CREATE INDEX idx_experiment_participants_assigned_variation ON experiment_participants(assigned_variation);

-- Flag change requests indexes
CREATE INDEX idx_flag_change_requests_flag_id ON flag_change_requests(flag_id);
CREATE INDEX idx_flag_change_requests_status ON flag_change_requests(status);
CREATE INDEX idx_flag_change_requests_scheduled_for ON flag_change_requests(scheduled_for);

-- Flag audit log indexes
CREATE INDEX idx_flag_audit_log_flag_id ON flag_audit_log(flag_id);
CREATE INDEX idx_flag_audit_log_changed_at ON flag_audit_log(changed_at);
CREATE INDEX idx_flag_audit_log_changed_by ON flag_audit_log(changed_by);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_feature_flags_updated_at BEFORE UPDATE ON feature_flags FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_segments_updated_at BEFORE UPDATE ON user_segments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_flag_targeting_rules_updated_at BEFORE UPDATE ON flag_targeting_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_feature_experiments_updated_at BEFORE UPDATE ON feature_experiments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_flag_change_requests_updated_at BEFORE UPDATE ON flag_change_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();