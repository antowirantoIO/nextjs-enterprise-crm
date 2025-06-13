-- =====================================================
-- ANALYTICS EVENTS MIGRATION
-- Comprehensive analytics tracking and business intelligence
-- Created: 2025-06-13 20:10:08 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- ANALYTICS EVENT SCHEMA ENHANCEMENT
-- =====================================================

-- Analytics event categories table
CREATE TABLE analytics_event_categories (
                                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Category details
                                            name VARCHAR(100) NOT NULL UNIQUE,
                                            slug VARCHAR(100) NOT NULL UNIQUE,
                                            description TEXT,

    -- Category settings
                                            retention_days INTEGER DEFAULT 365,
                                            is_active BOOLEAN DEFAULT TRUE,

    -- Aggregation settings
                                            enable_real_time_aggregation BOOLEAN DEFAULT TRUE,
                                            aggregation_intervals VARCHAR(20)[] DEFAULT '{hour,day,week,month}',

                                            created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enhanced analytics events table (replacing basic one)
DROP TABLE IF EXISTS analytics_events;
CREATE TABLE analytics_events (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                  category_id UUID REFERENCES analytics_event_categories(id),
                                  user_id UUID REFERENCES user_profiles(id),

    -- Event identification
                                  event_name VARCHAR(100) NOT NULL,
                                  event_category VARCHAR(50),
                                  event_action VARCHAR(50),
                                  event_label VARCHAR(100),

    -- Event value and metrics
                                  event_value DECIMAL(15,2),
                                  event_count INTEGER DEFAULT 1,

    -- Dimensional data
                                  properties JSONB DEFAULT '{}',

    -- User context
                                  anonymous_id VARCHAR(255), -- For tracking before user signup

    -- Session context
                                  session_id VARCHAR(100),
                                  session_number INTEGER, -- User's Nth session
                                  is_new_session BOOLEAN DEFAULT FALSE,

    -- Page/screen context
                                  page_url VARCHAR(1000),
                                  page_title VARCHAR(500),
                                  referrer_url VARCHAR(1000),

    -- Device and technical context
                                  user_agent TEXT,
                                  ip_address INET,
                                  device_type VARCHAR(50), -- desktop, mobile, tablet
                                  device_brand VARCHAR(100),
                                  device_model VARCHAR(100),
                                  browser VARCHAR(100),
                                  browser_version VARCHAR(50),
                                  operating_system VARCHAR(100),
                                  os_version VARCHAR(50),
                                  screen_resolution VARCHAR(20),

    -- Geographic context
                                  country VARCHAR(100),
                                  region VARCHAR(100),
                                  city VARCHAR(100),
                                  timezone VARCHAR(50),

    -- Time context
                                  timestamp TIMESTAMPTZ DEFAULT NOW(),
                                  local_time TIME,
                                  day_of_week INTEGER, -- 0=Sunday, 6=Saturday
                                  hour_of_day INTEGER, -- 0-23

    -- Attribution context
                                  utm_source VARCHAR(255),
                                  utm_medium VARCHAR(255),
                                  utm_campaign VARCHAR(255),
                                  utm_term VARCHAR(255),
                                  utm_content VARCHAR(255),

    -- Revenue attribution
                                  revenue_amount DECIMAL(15,2),
                                  currency VARCHAR(3) DEFAULT 'USD',

    -- Related entities
                                  contact_id UUID REFERENCES contacts(id),
                                  company_id UUID REFERENCES companies(id),
                                  deal_id UUID REFERENCES deals(id),

    -- Event metadata
                                  event_version VARCHAR(10) DEFAULT '1.0',
                                  sdk_version VARCHAR(50),
                                  app_version VARCHAR(50),

    -- Data quality
                                  is_bot BOOLEAN DEFAULT FALSE,
                                  confidence_score DECIMAL(3,2) DEFAULT 1.00, -- 0.00 to 1.00

    -- Processing status
                                  processed BOOLEAN DEFAULT FALSE,
                                  processed_at TIMESTAMPTZ,

    -- Additional metadata
                                  metadata JSONB DEFAULT '{}'
);

-- =====================================================
-- ANALYTICS AGGREGATIONS
-- =====================================================

-- Analytics aggregations table (pre-computed metrics)
CREATE TABLE analytics_aggregations (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                        organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Aggregation key
                                        metric_name VARCHAR(100) NOT NULL,
                                        dimension_values JSONB NOT NULL, -- The dimension values this aggregation represents

    -- Time period
                                        period_type VARCHAR(20) NOT NULL, -- hour, day, week, month, quarter, year
                                        period_start TIMESTAMPTZ NOT NULL,
                                        period_end TIMESTAMPTZ NOT NULL,

    -- Aggregated metrics
                                        total_count INTEGER DEFAULT 0,
                                        unique_count INTEGER DEFAULT 0,
                                        sum_value DECIMAL(15,2) DEFAULT 0,
                                        avg_value DECIMAL(15,2) DEFAULT 0,
                                        min_value DECIMAL(15,2),
                                        max_value DECIMAL(15,2),

    -- Additional aggregated data
                                        aggregated_data JSONB DEFAULT '{}',

    -- Metadata
                                        last_updated TIMESTAMPTZ DEFAULT NOW(),
                                        calculation_version VARCHAR(10) DEFAULT '1.0',

                                        UNIQUE(organization_id, metric_name, period_type, period_start, dimension_values)
);

-- =====================================================
-- FUNNELS & CONVERSION TRACKING
-- =====================================================

-- Analytics funnels table
CREATE TABLE analytics_funnels (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Funnel definition
                                   name VARCHAR(255) NOT NULL,
                                   description TEXT,

    -- Funnel steps (ordered array of events)
                                   steps JSONB NOT NULL, -- [{event_name, conditions, time_window}, ...]

    -- Funnel settings
                                   conversion_window_hours INTEGER DEFAULT 24, -- Max time between steps

    -- Status
                                   is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                   created_by UUID REFERENCES user_profiles(id),
                                   created_at TIMESTAMPTZ DEFAULT NOW(),
                                   updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Funnel analysis results table
CREATE TABLE funnel_analysis_results (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         funnel_id UUID NOT NULL REFERENCES analytics_funnels(id) ON DELETE CASCADE,

    -- Analysis period
                                         analysis_date DATE NOT NULL,
                                         period_start TIMESTAMPTZ NOT NULL,
                                         period_end TIMESTAMPTZ NOT NULL,

    -- Results per step
                                         step_results JSONB NOT NULL, -- [{step_number, users_entered, users_converted, conversion_rate}, ...]

    -- Overall metrics
                                         total_users_entered INTEGER DEFAULT 0,
                                         total_users_completed INTEGER DEFAULT 0,
                                         overall_conversion_rate DECIMAL(5,2) DEFAULT 0,

    -- Segments breakdown
                                         segment_breakdown JSONB, -- Breakdown by user segments

    -- Metadata
                                         calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                         UNIQUE(funnel_id, analysis_date)
);

-- =====================================================
-- COHORT ANALYSIS
-- =====================================================

-- Cohort definitions table
CREATE TABLE analytics_cohorts (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Cohort definition
                                   name VARCHAR(255) NOT NULL,
                                   description TEXT,

    -- Cohort criteria
                                   cohort_event VARCHAR(100) NOT NULL, -- Event that defines cohort entry
                                   cohort_conditions JSONB, -- Additional conditions for cohort entry

    -- Return event (what we're measuring)
                                   return_event VARCHAR(100) NOT NULL,
                                   return_conditions JSONB,

    -- Analysis settings
                                   period_type VARCHAR(20) DEFAULT 'week', -- day, week, month
                                   analysis_periods INTEGER DEFAULT 12, -- How many periods to analyze

    -- Status
                                   is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                   created_by UUID REFERENCES user_profiles(id),
                                   created_at TIMESTAMPTZ DEFAULT NOW(),
                                   updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cohort analysis results table
CREATE TABLE cohort_analysis_results (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         cohort_id UUID NOT NULL REFERENCES analytics_cohorts(id) ON DELETE CASCADE,

    -- Cohort period (when users entered the cohort)
                                         cohort_period DATE NOT NULL,

    -- Results by period
                                         period_results JSONB NOT NULL, -- [{period_number, users_returned, retention_rate}, ...]

    -- Cohort size
                                         cohort_size INTEGER DEFAULT 0,

    -- Metadata
                                         calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                         UNIQUE(cohort_id, cohort_period)
);

-- =====================================================
-- A/B TESTING & EXPERIMENTS
-- =====================================================

-- Experiments table
CREATE TABLE analytics_experiments (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Experiment details
                                       name VARCHAR(255) NOT NULL,
                                       description TEXT,
                                       hypothesis TEXT,

    -- Experiment configuration
                                       experiment_key VARCHAR(100) NOT NULL, -- Unique key for code reference

    -- Variants
                                       variants JSONB NOT NULL, -- [{name, key, allocation_percentage, configuration}, ...]

    -- Targeting
                                       audience_conditions JSONB, -- Who should be included in the experiment

    -- Metrics
                                       primary_metric VARCHAR(100), -- Main metric we're optimizing for
                                       secondary_metrics VARCHAR(100)[], -- Additional metrics to track

    -- Sample size and power
                                       minimum_sample_size INTEGER,
                                       expected_effect_size DECIMAL(5,2), -- Expected improvement percentage
                                       statistical_power DECIMAL(3,2) DEFAULT 0.80, -- 80% power
                                       significance_level DECIMAL(3,2) DEFAULT 0.05, -- 5% significance

    -- Experiment lifecycle
                                       status VARCHAR(20) DEFAULT 'draft', -- draft, running, paused, completed, cancelled
                                       start_date TIMESTAMPTZ,
                                       end_date TIMESTAMPTZ,

    -- Results
                                       winner_variant VARCHAR(100),
                                       confidence_level DECIMAL(5,2),
                                       results_summary TEXT,

    -- Metadata
                                       created_by UUID REFERENCES user_profiles(id),
                                       created_at TIMESTAMPTZ DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ DEFAULT NOW(),

                                       UNIQUE(organization_id, experiment_key)
);

-- Experiment assignments table
CREATE TABLE experiment_assignments (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                        experiment_id UUID NOT NULL REFERENCES analytics_experiments(id) ON DELETE CASCADE,

    -- Assignment details
                                        user_id UUID REFERENCES user_profiles(id),
                                        anonymous_id VARCHAR(255), -- For users not yet signed up
                                        variant_key VARCHAR(100) NOT NULL,

    -- Assignment metadata
                                        assigned_at TIMESTAMPTZ DEFAULT NOW(),
                                        first_exposure_at TIMESTAMPTZ,

    -- Conversion tracking
                                        has_converted BOOLEAN DEFAULT FALSE,
                                        converted_at TIMESTAMPTZ,
                                        conversion_value DECIMAL(15,2),

                                        UNIQUE(experiment_id, COALESCE(user_id::text, anonymous_id))
);

-- =====================================================
-- REAL-TIME ANALYTICS VIEWS
-- =====================================================

-- Real-time metrics table (for dashboard display)
CREATE TABLE real_time_metrics (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Metric identification
                                   metric_key VARCHAR(100) NOT NULL,
                                   metric_name VARCHAR(255) NOT NULL,

    -- Current values
                                   current_value DECIMAL(15,2) DEFAULT 0,
                                   previous_value DECIMAL(15,2) DEFAULT 0,
                                   change_percentage DECIMAL(5,2) DEFAULT 0,

    -- Time context
                                   last_updated TIMESTAMPTZ DEFAULT NOW(),
                                   measurement_window VARCHAR(20) DEFAULT 'hour', -- hour, day, week, month

    -- Metadata
                                   metadata JSONB DEFAULT '{}',

                                   UNIQUE(organization_id, metric_key, measurement_window)
);

-- =====================================================
-- FUNCTIONS FOR ANALYTICS
-- =====================================================

-- Function to track analytics event
CREATE OR REPLACE FUNCTION track_analytics_event(
    p_event_name VARCHAR(100),
    p_properties JSONB DEFAULT '{}',
    p_user_uuid UUID DEFAULT NULL,
    p_session_id VARCHAR(100) DEFAULT NULL,
    p_anonymous_id VARCHAR(255) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
event_id UUID;
    user_org_id UUID;
    category_id UUID;
    session_number INTEGER := 1;
    is_new_session BOOLEAN := FALSE;
BEGIN
    -- Get organization ID
    IF p_user_uuid IS NOT NULL THEN
SELECT organization_id INTO user_org_id
FROM user_profiles WHERE id = p_user_uuid;
ELSE
        user_org_id := auth.user_organization_id();
END IF;

    -- Get category
SELECT id INTO category_id
FROM analytics_event_categories
WHERE name = (p_properties->>'category')
   OR name = 'general';

-- Determine session number and if it's new
IF p_session_id IS NOT NULL THEN
SELECT COUNT(DISTINCT session_id) + 1,
       NOT EXISTS (
           SELECT 1 FROM analytics_events
           WHERE session_id = p_session_id
             AND COALESCE(user_id, p_user_uuid) = p_user_uuid
       )
INTO session_number, is_new_session
FROM analytics_events
WHERE COALESCE(user_id, p_user_uuid) = p_user_uuid;
END IF;

    -- Insert analytics event
INSERT INTO analytics_events (
    organization_id,
    category_id,
    user_id,
    anonymous_id,
    event_name,
    event_category,
    event_action,
    event_label,
    event_value,
    properties,
    session_id,
    session_number,
    is_new_session,
    page_url,
    referrer_url,
    utm_source,
    utm_medium,
    utm_campaign,
    day_of_week,
    hour_of_day,
    local_time
) VALUES (
             user_org_id,
             category_id,
             p_user_uuid,
             p_anonymous_id,
             p_event_name,
             p_properties->>'category',
             p_properties->>'action',
             p_properties->>'label',
             CASE WHEN p_properties ? 'value' THEN (p_properties->>'value')::DECIMAL ELSE NULL END,
             p_properties,
             p_session_id,
             session_number,
             is_new_session,
             p_properties->>'page_url',
             p_properties->>'referrer_url',
             p_properties->>'utm_source',
             p_properties->>'utm_medium',
             p_properties->>'utm_campaign',
             EXTRACT(dow FROM NOW()),
             EXTRACT(hour FROM NOW()),
             NOW()::TIME
         ) RETURNING id INTO event_id;

-- Trigger real-time aggregation
PERFORM update_real_time_metrics(user_org_id, p_event_name);

RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate funnel conversion
CREATE OR REPLACE FUNCTION calculate_funnel_conversion(
    funnel_uuid UUID,
    analysis_start TIMESTAMPTZ,
    analysis_end TIMESTAMPTZ
)
RETURNS UUID AS $$
DECLARE
funnel_record RECORD;
    step_results JSONB := '[]';
    step_record JSONB;
    users_in_step INTEGER;
    total_users INTEGER := 0;
    completed_users INTEGER := 0;
    result_id UUID;
BEGIN
    -- Get funnel definition
SELECT * INTO funnel_record FROM analytics_funnels WHERE id = funnel_uuid;

-- Process each step
FOR i IN 0..jsonb_array_length(funnel_record.steps) - 1 LOOP
        step_record := funnel_record.steps->i;

        -- Calculate users in this step
        -- This is a simplified version - real implementation would be more complex
SELECT COUNT(DISTINCT COALESCE(user_id::text, anonymous_id)) INTO users_in_step
FROM analytics_events
WHERE organization_id = funnel_record.organization_id
  AND event_name = step_record->>'event_name'
  AND timestamp BETWEEN analysis_start AND analysis_end;

IF i = 0 THEN
            total_users := users_in_step;
END IF;

        IF i = jsonb_array_length(funnel_record.steps) - 1 THEN
            completed_users := users_in_step;
END IF;

        -- Add to results
        step_results := step_results || jsonb_build_object(
            'step_number', i + 1,
            'step_name', step_record->>'event_name',
            'users_entered', users_in_step,
            'conversion_rate', CASE WHEN total_users > 0 THEN ROUND((users_in_step::DECIMAL / total_users) * 100, 2) ELSE 0 END
        );
END LOOP;

    -- Insert results
INSERT INTO funnel_analysis_results (
    funnel_id,
    analysis_date,
    period_start,
    period_end,
    step_results,
    total_users_entered,
    total_users_completed,
    overall_conversion_rate
) VALUES (
             funnel_uuid,
             analysis_start::DATE,
             analysis_start,
             analysis_end,
             step_results,
             total_users,
             completed_users,
             CASE WHEN total_users > 0 THEN ROUND((completed_users::DECIMAL / total_users) * 100, 2) ELSE 0 END
         ) RETURNING id INTO result_id;

RETURN result_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update real-time metrics
CREATE OR REPLACE FUNCTION update_real_time_metrics(
    org_uuid UUID,
    event_name_param VARCHAR(100)
)
RETURNS VOID AS $$
DECLARE
current_hour_count INTEGER;
    previous_hour_count INTEGER;
    change_pct DECIMAL(5,2);
BEGIN
    -- Count events in current hour
SELECT COUNT(*) INTO current_hour_count
FROM analytics_events
WHERE organization_id = org_uuid
  AND event_name = event_name_param
  AND timestamp >= date_trunc('hour', NOW());

-- Count events in previous hour
SELECT COUNT(*) INTO previous_hour_count
FROM analytics_events
WHERE organization_id = org_uuid
  AND event_name = event_name_param
  AND timestamp >= date_trunc('hour', NOW()) - INTERVAL '1 hour'
  AND timestamp < date_trunc('hour', NOW());

-- Calculate change percentage
change_pct := CASE
        WHEN previous_hour_count > 0 THEN
            ROUND(((current_hour_count - previous_hour_count)::DECIMAL / previous_hour_count) * 100, 2)
        ELSE
            CASE WHEN current_hour_count > 0 THEN 100.0 ELSE 0.0 END
END;

    -- Update real-time metrics
INSERT INTO real_time_metrics (
    organization_id,
    metric_key,
    metric_name,
    current_value,
    previous_value,
    change_percentage,
    measurement_window
) VALUES (
             org_uuid,
             'event_' || event_name_param || '_hourly',
             event_name_param || ' (Hourly)',
             current_hour_count,
             previous_hour_count,
             change_pct,
             'hour'
         )
    ON CONFLICT (organization_id, metric_key, measurement_window)
    DO UPDATE SET
    current_value = EXCLUDED.current_value,
               previous_value = EXCLUDED.previous_value,
               change_percentage = EXCLUDED.change_percentage,
               last_updated = NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Analytics events indexes
CREATE INDEX idx_analytics_events_organization_id ON analytics_events(organization_id);
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_timestamp ON analytics_events(timestamp);
CREATE INDEX idx_analytics_events_event_name ON analytics_events(event_name);
CREATE INDEX idx_analytics_events_session_id ON analytics_events(session_id);
CREATE INDEX idx_analytics_events_anonymous_id ON analytics_events(anonymous_id);

-- Composite indexes for common queries
CREATE INDEX idx_analytics_events_org_event_time ON analytics_events(organization_id, event_name, timestamp);
CREATE INDEX idx_analytics_events_user_time ON analytics_events(user_id, timestamp);
CREATE INDEX idx_analytics_events_session_time ON analytics_events(session_id, timestamp);

-- GIN indexes for JSONB properties
CREATE INDEX idx_analytics_events_properties ON analytics_events USING GIN(properties);

-- Analytics aggregations indexes
CREATE INDEX idx_analytics_aggregations_org_metric ON analytics_aggregations(organization_id, metric_name);
CREATE INDEX idx_analytics_aggregations_period ON analytics_aggregations(period_type, period_start);

-- Experiment indexes
CREATE INDEX idx_analytics_experiments_organization_id ON analytics_experiments(organization_id);
CREATE INDEX idx_analytics_experiments_status ON analytics_experiments(status);
CREATE INDEX idx_experiment_assignments_experiment_id ON experiment_assignments(experiment_id);
CREATE INDEX idx_experiment_assignments_user_id ON experiment_assignments(user_id);

-- Real-time metrics indexes
CREATE INDEX idx_real_time_metrics_org_key ON real_time_metrics(organization_id, metric_key);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_analytics_funnels_updated_at BEFORE UPDATE ON analytics_funnels FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_analytics_cohorts_updated_at BEFORE UPDATE ON analytics_cohorts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_analytics_experiments_updated_at BEFORE UPDATE ON analytics_experiments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();