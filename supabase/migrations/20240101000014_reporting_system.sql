-- =====================================================
-- REPORTING SYSTEM MIGRATION
-- Advanced reporting, dashboards, and business intelligence
-- Created: 2025-06-13 20:17:15 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- REPORT DEFINITIONS & TEMPLATES
-- =====================================================

-- Report categories table
CREATE TABLE report_categories (
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

-- Report templates table
CREATE TABLE report_templates (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  category_id UUID REFERENCES report_categories(id),

    -- Template details
                                  name VARCHAR(255) NOT NULL,
                                  slug VARCHAR(100) NOT NULL UNIQUE,
                                  description TEXT,

    -- Report configuration
                                  report_type VARCHAR(50) NOT NULL, -- table, chart, dashboard, pivot, custom
                                  data_source VARCHAR(50) NOT NULL, -- contacts, companies, deals, activities, custom

    -- Query configuration
                                  base_query JSONB NOT NULL, -- Base query definition
                                  filters JSONB DEFAULT '{}', -- Available filters
                                  grouping JSONB DEFAULT '{}', -- Grouping options
                                  sorting JSONB DEFAULT '{}', -- Sorting options

    -- Visualization settings
                                  chart_type VARCHAR(50), -- bar, line, pie, area, scatter, etc.
                                  chart_config JSONB DEFAULT '{}',

    -- Layout settings
                                  layout_config JSONB DEFAULT '{}',
                                  styling_config JSONB DEFAULT '{}',

    -- Template metadata
                                  tags TEXT[],
                                  use_cases TEXT[],

    -- Template status
                                  is_public BOOLEAN DEFAULT TRUE,
                                  is_featured BOOLEAN DEFAULT FALSE,
                                  is_premium BOOLEAN DEFAULT FALSE,

    -- Usage tracking
                                  usage_count INTEGER DEFAULT 0,
                                  average_rating DECIMAL(2,1) DEFAULT 0.0,

    -- Metadata
                                  created_by UUID REFERENCES user_profiles(id),
                                  created_at TIMESTAMPTZ DEFAULT NOW(),
                                  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enhanced custom reports table (replacing basic one)
DROP TABLE IF EXISTS custom_reports;
CREATE TABLE custom_reports (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                template_id UUID REFERENCES report_templates(id),
                                category_id UUID REFERENCES report_categories(id),

    -- Report details
                                name VARCHAR(255) NOT NULL,
                                description TEXT,

    -- Report configuration
                                report_type VARCHAR(50) NOT NULL,
                                data_source VARCHAR(50) NOT NULL,

    -- Query configuration
                                query_config JSONB NOT NULL, -- Complete query configuration
                                filters JSONB DEFAULT '{}', -- Applied filters
                                grouping JSONB DEFAULT '{}', -- Applied grouping
                                sorting JSONB DEFAULT '{}', -- Applied sorting

    -- Visualization settings
                                visualization_type VARCHAR(50), -- table, bar_chart, line_chart, pie_chart, etc.
                                visualization_config JSONB DEFAULT '{}',

    -- Layout and styling
                                layout JSONB DEFAULT '{}',
                                styling JSONB DEFAULT '{}',

    -- Access control
                                visibility VARCHAR(20) DEFAULT 'private', -- private, team, organization, public
                                shared_with_users UUID[], -- Specific users with access
                                shared_with_teams UUID[], -- Teams with access

    -- Scheduling
                                is_scheduled BOOLEAN DEFAULT FALSE,
                                schedule_config JSONB, -- Scheduling configuration

    -- Caching
                                cache_duration_minutes INTEGER DEFAULT 60,
                                last_cached_at TIMESTAMPTZ,
                                cached_data JSONB,
                                cache_key VARCHAR(255),

    -- Performance
                                last_execution_time_ms INTEGER,
                                average_execution_time_ms INTEGER,

    -- Usage statistics
                                view_count INTEGER DEFAULT 0,
                                last_viewed_at TIMESTAMPTZ,
                                export_count INTEGER DEFAULT 0,
                                last_exported_at TIMESTAMPTZ,

    -- Metadata
                                created_by UUID REFERENCES user_profiles(id),
                                created_at TIMESTAMPTZ DEFAULT NOW(),
                                updated_at TIMESTAMPTZ DEFAULT NOW(),
                                deleted_at TIMESTAMPTZ
);

-- =====================================================
-- DASHBOARDS
-- =====================================================

-- Dashboards table
CREATE TABLE dashboards (
                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                            organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Dashboard details
                            name VARCHAR(255) NOT NULL,
                            description TEXT,

    -- Dashboard configuration
                            layout_type VARCHAR(50) DEFAULT 'grid', -- grid, flexible, fixed
                            layout_config JSONB DEFAULT '{}', -- Grid settings, responsive breakpoints

    -- Dashboard settings
                            auto_refresh_enabled BOOLEAN DEFAULT FALSE,
                            auto_refresh_interval_minutes INTEGER DEFAULT 15,

    -- Access control
                            visibility VARCHAR(20) DEFAULT 'private', -- private, team, organization, public
                            shared_with_users UUID[],
                            shared_with_teams UUID[],

    -- Dashboard state
                            is_default BOOLEAN DEFAULT FALSE,
                            is_published BOOLEAN DEFAULT FALSE,

    -- Performance
                            load_time_ms INTEGER,

    -- Usage statistics
                            view_count INTEGER DEFAULT 0,
                            unique_viewers INTEGER DEFAULT 0,
                            last_viewed_at TIMESTAMPTZ,

    -- Metadata
                            created_by UUID REFERENCES user_profiles(id),
                            created_at TIMESTAMPTZ DEFAULT NOW(),
                            updated_at TIMESTAMPTZ DEFAULT NOW(),
                            deleted_at TIMESTAMPTZ
);

-- Dashboard widgets table
CREATE TABLE dashboard_widgets (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   dashboard_id UUID NOT NULL REFERENCES dashboards(id) ON DELETE CASCADE,
                                   report_id UUID REFERENCES custom_reports(id) ON DELETE CASCADE,

    -- Widget details
                                   widget_type VARCHAR(50) NOT NULL, -- report, metric, chart, table, text, iframe
                                   title VARCHAR(255),
                                   description TEXT,

    -- Widget configuration
                                   config JSONB DEFAULT '{}', -- Widget-specific configuration

    -- Layout positioning
                                   position_x INTEGER DEFAULT 0,
                                   position_y INTEGER DEFAULT 0,
                                   width INTEGER DEFAULT 4, -- Grid units
                                   height INTEGER DEFAULT 3, -- Grid units

    -- Responsive settings
                                   min_width INTEGER DEFAULT 2,
                                   min_height INTEGER DEFAULT 2,
                                   max_width INTEGER DEFAULT 12,
                                   max_height INTEGER DEFAULT 10,

    -- Widget settings
                                   is_visible BOOLEAN DEFAULT TRUE,
                                   refresh_interval_minutes INTEGER,

    -- Styling
                                   styling JSONB DEFAULT '{}',

    -- Data caching
                                   cached_data JSONB,
                                   last_cached_at TIMESTAMPTZ,

    -- Metadata
                                   created_at TIMESTAMPTZ DEFAULT NOW(),
                                   updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- REPORT EXECUTION & CACHING
-- =====================================================

-- Report executions table
CREATE TABLE report_executions (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   report_id UUID NOT NULL REFERENCES custom_reports(id) ON DELETE CASCADE,

    -- Execution details
                                   execution_type VARCHAR(50) DEFAULT 'manual', -- manual, scheduled, cached, api

    -- Execution parameters
                                   parameters JSONB DEFAULT '{}', -- Runtime parameters
                                   filters JSONB DEFAULT '{}', -- Applied filters

    -- Execution results
                                   status VARCHAR(20) DEFAULT 'running', -- running, completed, failed, cancelled
                                   result_data JSONB, -- Query results
                                   result_metadata JSONB, -- Metadata about results (row count, columns, etc.)

    -- Performance metrics
                                   execution_time_ms INTEGER,
                                   data_size_bytes INTEGER,
                                   rows_returned INTEGER,

    -- Error handling
                                   error_message TEXT,
                                   error_details JSONB,

    -- Execution context
                                   executed_by UUID REFERENCES user_profiles(id),
                                   executed_at TIMESTAMPTZ DEFAULT NOW(),
                                   completed_at TIMESTAMPTZ,

    -- Export information
                                   export_format VARCHAR(20), -- csv, excel, pdf, json
                                   export_file_path VARCHAR(1000),

    -- Metadata
                                   metadata JSONB DEFAULT '{}'
);

-- Report subscriptions table (for scheduled reports)
CREATE TABLE report_subscriptions (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      report_id UUID NOT NULL REFERENCES custom_reports(id) ON DELETE CASCADE,
                                      user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Subscription details
                                      subscription_name VARCHAR(255),

    -- Delivery settings
                                      delivery_method VARCHAR(50) NOT NULL, -- email, slack, webhook, download
                                      delivery_config JSONB NOT NULL, -- Method-specific configuration

    -- Schedule settings
                                      schedule_type VARCHAR(50) NOT NULL, -- daily, weekly, monthly, custom
                                      schedule_config JSONB NOT NULL, -- Schedule-specific configuration
                                      timezone VARCHAR(50) DEFAULT 'UTC',

    -- Format settings
                                      export_format VARCHAR(20) DEFAULT 'pdf', -- csv, excel, pdf, json
                                      include_data BOOLEAN DEFAULT TRUE,
                                      include_charts BOOLEAN DEFAULT TRUE,

    -- Subscription status
                                      is_active BOOLEAN DEFAULT TRUE,

    -- Execution tracking
                                      last_delivered_at TIMESTAMPTZ,
                                      next_delivery_at TIMESTAMPTZ,
                                      delivery_count INTEGER DEFAULT 0,
                                      failure_count INTEGER DEFAULT 0,
                                      consecutive_failures INTEGER DEFAULT 0,

    -- Error handling
                                      last_error_message TEXT,

    -- Metadata
                                      created_at TIMESTAMPTZ DEFAULT NOW(),
                                      updated_at TIMESTAMPTZ DEFAULT NOW(),

                                      UNIQUE(report_id, user_id)
);

-- =====================================================
-- DATA SOURCES & QUERIES
-- =====================================================

-- Data sources table
CREATE TABLE data_sources (
                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                              organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Data source details
                              name VARCHAR(255) NOT NULL,
                              description TEXT,
                              source_type VARCHAR(50) NOT NULL, -- internal, external, integration

    -- Connection configuration
                              connection_config JSONB DEFAULT '{}', -- Database connection, API config, etc.

    -- Schema information
                              schema_info JSONB DEFAULT '{}', -- Available tables, columns, relationships

    -- Query configuration
                              query_language VARCHAR(50) DEFAULT 'sql', -- sql, graphql, rest, custom
                              base_queries JSONB DEFAULT '{}', -- Pre-defined queries

    -- Access control
                              allowed_users UUID[],
                              allowed_roles user_role[],

    -- Performance settings
                              default_limit INTEGER DEFAULT 1000,
                              max_limit INTEGER DEFAULT 10000,
                              query_timeout_seconds INTEGER DEFAULT 30,

    -- Caching settings
                              enable_caching BOOLEAN DEFAULT TRUE,
                              default_cache_duration_minutes INTEGER DEFAULT 60,

    -- Status
                              is_active BOOLEAN DEFAULT TRUE,
                              last_tested_at TIMESTAMPTZ,
                              test_status VARCHAR(20), -- healthy, warning, error, unknown

    -- Metadata
                              created_by UUID REFERENCES user_profiles(id),
                              created_at TIMESTAMPTZ DEFAULT NOW(),
                              updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Query builder saved queries
CREATE TABLE saved_queries (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                               data_source_id UUID REFERENCES data_sources(id),

    -- Query details
                               name VARCHAR(255) NOT NULL,
                               description TEXT,

    -- Query definition
                               query_text TEXT NOT NULL,
                               query_parameters JSONB DEFAULT '{}',

    -- Query metadata
                               query_type VARCHAR(50), -- select, insert, update, delete, custom
                               affected_tables TEXT[],

    -- Performance
                               estimated_rows INTEGER,
                               last_execution_time_ms INTEGER,

    -- Access control
                               is_public BOOLEAN DEFAULT FALSE,
                               shared_with_users UUID[],

    -- Usage tracking
                               execution_count INTEGER DEFAULT 0,
                               last_executed_at TIMESTAMPTZ,

    -- Metadata
                               created_by UUID REFERENCES user_profiles(id),
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- REPORT SHARING & COLLABORATION
-- =====================================================

-- Report shares table
CREATE TABLE report_shares (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               report_id UUID NOT NULL REFERENCES custom_reports(id) ON DELETE CASCADE,

    -- Share details
                               share_type VARCHAR(50) NOT NULL, -- link, email, embed, api
                               share_token VARCHAR(255) NOT NULL UNIQUE,

    -- Access configuration
                               access_level VARCHAR(50) DEFAULT 'view', -- view, comment, edit
                               password_protected BOOLEAN DEFAULT FALSE,
                               password_hash VARCHAR(255),

    -- Restrictions
                               allowed_domains TEXT[], -- Email domains that can access
                               ip_whitelist INET[], -- IP restrictions
                               max_views INTEGER, -- Maximum number of views
                               current_views INTEGER DEFAULT 0,

    -- Expiration
                               expires_at TIMESTAMPTZ,

    -- Share settings
                               allow_download BOOLEAN DEFAULT FALSE,
                               allow_refresh BOOLEAN DEFAULT TRUE,
                               show_filters BOOLEAN DEFAULT TRUE,

    -- Tracking
                               last_accessed_at TIMESTAMPTZ,
                               access_count INTEGER DEFAULT 0,

    -- Metadata
                               shared_by UUID REFERENCES user_profiles(id),
                               shared_at TIMESTAMPTZ DEFAULT NOW(),

    -- Status
                               is_active BOOLEAN DEFAULT TRUE
);

-- Report comments table
CREATE TABLE report_comments (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 report_id UUID NOT NULL REFERENCES custom_reports(id) ON DELETE CASCADE,
                                 author_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
                                 parent_comment_id UUID REFERENCES report_comments(id) ON DELETE CASCADE,

    -- Comment content
                                 content TEXT NOT NULL,

    -- Comment context (for specific data points)
                                 context_data JSONB, -- Which data point/chart element the comment refers to

    -- Comment type
                                 comment_type VARCHAR(50) DEFAULT 'general', -- general, question, insight, issue

    -- Status
                                 is_resolved BOOLEAN DEFAULT FALSE,
                                 resolved_at TIMESTAMPTZ,
                                 resolved_by UUID REFERENCES user_profiles(id),

    -- Metadata
                                 created_at TIMESTAMPTZ DEFAULT NOW(),
                                 updated_at TIMESTAMPTZ DEFAULT NOW(),
                                 deleted_at TIMESTAMPTZ
);

-- =====================================================
-- ANALYTICS & INSIGHTS
-- =====================================================

-- Report analytics table
CREATE TABLE report_analytics (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  report_id UUID NOT NULL REFERENCES custom_reports(id) ON DELETE CASCADE,

    -- Analytics period
                                  date DATE NOT NULL,

    -- Usage metrics
                                  total_views INTEGER DEFAULT 0,
                                  unique_viewers INTEGER DEFAULT 0,
                                  total_exports INTEGER DEFAULT 0,

    -- Performance metrics
                                  average_load_time_ms INTEGER DEFAULT 0,
                                  total_execution_time_ms BIGINT DEFAULT 0,

    -- Engagement metrics
                                  average_time_spent_seconds INTEGER DEFAULT 0,
                                  bounce_rate DECIMAL(5,2) DEFAULT 0, -- Percentage who left immediately

    -- Error metrics
                                  error_count INTEGER DEFAULT 0,
                                  timeout_count INTEGER DEFAULT 0,

    -- Access patterns
                                  peak_usage_hour INTEGER, -- Hour with most usage (0-23)
                                  top_filters JSONB, -- Most used filters

    -- Metadata
                                  calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                  UNIQUE(report_id, date)
);

-- Dashboard analytics table
CREATE TABLE dashboard_analytics (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     dashboard_id UUID NOT NULL REFERENCES dashboards(id) ON DELETE CASCADE,

    -- Analytics period
                                     date DATE NOT NULL,

    -- Usage metrics
                                     total_views INTEGER DEFAULT 0,
                                     unique_viewers INTEGER DEFAULT 0,
                                     average_session_duration_seconds INTEGER DEFAULT 0,

    -- Widget interaction
                                     widget_interactions JSONB DEFAULT '{}', -- {widget_id: interaction_count}
                                     most_viewed_widgets JSONB DEFAULT '{}', -- {widget_id: view_count}

    -- Performance metrics
                                     average_load_time_ms INTEGER DEFAULT 0,

    -- Metadata
                                     calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                     UNIQUE(dashboard_id, date)
);

-- =====================================================
-- FUNCTIONS FOR REPORTING
-- =====================================================

-- Function to execute report query
CREATE OR REPLACE FUNCTION execute_report_query(
    report_uuid UUID,
    parameters_param JSONB DEFAULT '{}',
    filters_param JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
execution_id UUID;
    report_record RECORD;
    start_time TIMESTAMPTZ;
    end_time TIMESTAMPTZ;
    execution_time INTEGER;
    result_count INTEGER := 0;
BEGIN
    -- Get report details
SELECT * INTO report_record FROM custom_reports WHERE id = report_uuid;

IF NOT FOUND THEN
        RAISE EXCEPTION 'Report not found: %', report_uuid;
END IF;

    start_time := NOW();

    -- Create execution record
INSERT INTO report_executions (
    report_id,
    execution_type,
    parameters,
    filters,
    executed_by,
    status
) VALUES (
             report_uuid,
             'manual',
             parameters_param,
             filters_param,
             auth.uid(),
             'running'
         ) RETURNING id INTO execution_id;

-- The actual query execution would be handled by the application layer
-- This function just creates the execution record and simulates completion

end_time := NOW();
    execution_time := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

    -- Update execution with results
UPDATE report_executions
SET
    status = 'completed',
    execution_time_ms = execution_time,
    rows_returned = result_count,
    completed_at = end_time,
    result_metadata = jsonb_build_object(
            'execution_time_ms', execution_time,
            'rows_returned', result_count,
            'columns', '[]'::jsonb
                      )
WHERE id = execution_id;

-- Update report statistics
UPDATE custom_reports
SET
    view_count = view_count + 1,
    last_viewed_at = NOW(),
    last_execution_time_ms = execution_time,
    average_execution_time_ms = (
        SELECT AVG(execution_time_ms)::INTEGER
        FROM report_executions
        WHERE report_id = report_uuid
          AND status = 'completed'
    )
WHERE id = report_uuid;

RETURN execution_id;
END;
$$ LANGUAGE plpgsql;

-- Function to create report share
CREATE OR REPLACE FUNCTION create_report_share(
    report_uuid UUID,
    share_type_param VARCHAR(50),
    access_level_param VARCHAR(50) DEFAULT 'view',
    expires_in_hours INTEGER DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
share_token TEXT;
    share_id UUID;
    expires_at_param TIMESTAMPTZ;
BEGIN
    -- Generate secure share token
    share_token := encode(gen_random_bytes(32), 'base64');
    share_token := replace(share_token, '/', '_');
    share_token := replace(share_token, '+', '-');
    share_token := replace(share_token, '=', '');

    -- Calculate expiration
    IF expires_in_hours IS NOT NULL THEN
        expires_at_param := NOW() + INTERVAL '1 hour' * expires_in_hours;
END IF;

    -- Create share record
INSERT INTO report_shares (
    report_id,
    share_type,
    share_token,
    access_level,
    expires_at,
    shared_by
) VALUES (
             report_uuid,
             share_type_param,
             share_token,
             access_level_param,
             expires_at_param,
             auth.uid()
         ) RETURNING id INTO share_id;

RETURN share_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate report analytics
CREATE OR REPLACE FUNCTION calculate_report_analytics(
    report_uuid UUID,
    analytics_date DATE
)
RETURNS VOID AS $$
DECLARE
total_views_count INTEGER;
    unique_viewers_count INTEGER;
    total_exports_count INTEGER;
    avg_load_time INTEGER;
    error_count_val INTEGER;
BEGIN
    -- Calculate metrics for the specified date
SELECT
    COUNT(*),
    COUNT(DISTINCT executed_by),
    COUNT(*) FILTER (WHERE export_format IS NOT NULL),
    AVG(execution_time_ms)::INTEGER,
    COUNT(*) FILTER (WHERE status = 'failed')
INTO
    total_views_count,
    unique_viewers_count,
    total_exports_count,
    avg_load_time,
    error_count_val
FROM report_executions
WHERE report_id = report_uuid
  AND executed_at::DATE = analytics_date;

-- Insert or update analytics record
INSERT INTO report_analytics (
    report_id,
    date,
    total_views,
    unique_viewers,
    total_exports,
    average_load_time_ms,
    error_count
) VALUES (
             report_uuid,
             analytics_date,
             total_views_count,
             unique_viewers_count,
             total_exports_count,
             avg_load_time,
             error_count_val
         )
    ON CONFLICT (report_id, date)
    DO UPDATE SET
    total_views = EXCLUDED.total_views,
               unique_viewers = EXCLUDED.unique_viewers,
               total_exports = EXCLUDED.total_exports,
               average_load_time_ms = EXCLUDED.average_load_time_ms,
               error_count = EXCLUDED.error_count,
               calculated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to deliver scheduled report
CREATE OR REPLACE FUNCTION deliver_scheduled_report(
    subscription_uuid UUID
)
RETURNS BOOLEAN AS $$
DECLARE
subscription_record RECORD;
    execution_id UUID;
    delivery_success BOOLEAN := FALSE;
BEGIN
    -- Get subscription details
SELECT * INTO subscription_record
FROM report_subscriptions
WHERE id = subscription_uuid AND is_active = TRUE;

IF NOT FOUND THEN
        RETURN FALSE;
END IF;

    -- Execute the report
SELECT execute_report_query(subscription_record.report_id) INTO execution_id;

-- The actual delivery would be handled by the application layer
-- (email sending, file generation, etc.)

-- Update subscription tracking
UPDATE report_subscriptions
SET
    last_delivered_at = NOW(),
    delivery_count = delivery_count + 1,
    consecutive_failures = 0,
    next_delivery_at = CASE
                           WHEN schedule_type = 'daily' THEN NOW() + INTERVAL '1 day'
    WHEN schedule_type = 'weekly' THEN NOW() + INTERVAL '1 week'
    WHEN schedule_type = 'monthly' THEN NOW() + INTERVAL '1 month'
    ELSE next_delivery_at
END
WHERE id = subscription_uuid;

    delivery_success := TRUE;
RETURN delivery_success;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Report templates indexes
CREATE INDEX idx_report_templates_category_id ON report_templates(category_id);
CREATE INDEX idx_report_templates_slug ON report_templates(slug);
CREATE INDEX idx_report_templates_public ON report_templates(is_public);

-- Custom reports indexes
CREATE INDEX idx_custom_reports_organization_id ON custom_reports(organization_id);
CREATE INDEX idx_custom_reports_template_id ON custom_reports(template_id);
CREATE INDEX idx_custom_reports_category_id ON custom_reports(category_id);
CREATE INDEX idx_custom_reports_visibility ON custom_reports(visibility);
CREATE INDEX idx_custom_reports_created_by ON custom_reports(created_by);

-- Dashboards indexes
CREATE INDEX idx_dashboards_organization_id ON dashboards(organization_id);
CREATE INDEX idx_dashboards_visibility ON dashboards(visibility);
CREATE INDEX idx_dashboards_created_by ON dashboards(created_by);

-- Dashboard widgets indexes
CREATE INDEX idx_dashboard_widgets_dashboard_id ON dashboard_widgets(dashboard_id);
CREATE INDEX idx_dashboard_widgets_report_id ON dashboard_widgets(report_id);

-- Report executions indexes
CREATE INDEX idx_report_executions_report_id ON report_executions(report_id);
CREATE INDEX idx_report_executions_executed_by ON report_executions(executed_by);
CREATE INDEX idx_report_executions_executed_at ON report_executions(executed_at);
CREATE INDEX idx_report_executions_status ON report_executions(status);

-- Report subscriptions indexes
CREATE INDEX idx_report_subscriptions_report_id ON report_subscriptions(report_id);
CREATE INDEX idx_report_subscriptions_user_id ON report_subscriptions(user_id);
CREATE INDEX idx_report_subscriptions_next_delivery ON report_subscriptions(next_delivery_at) WHERE is_active = TRUE;

-- Data sources indexes
CREATE INDEX idx_data_sources_organization_id ON data_sources(organization_id);
CREATE INDEX idx_data_sources_source_type ON data_sources(source_type);
CREATE INDEX idx_data_sources_active ON data_sources(is_active);

-- Report shares indexes
CREATE INDEX idx_report_shares_report_id ON report_shares(report_id);
CREATE INDEX idx_report_shares_token ON report_shares(share_token);
CREATE INDEX idx_report_shares_expires_at ON report_shares(expires_at);

-- Analytics indexes
CREATE INDEX idx_report_analytics_report_id ON report_analytics(report_id);
CREATE INDEX idx_report_analytics_date ON report_analytics(date);
CREATE INDEX idx_dashboard_analytics_dashboard_id ON dashboard_analytics(dashboard_id);
CREATE INDEX idx_dashboard_analytics_date ON dashboard_analytics(date);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_report_templates_updated_at BEFORE UPDATE ON report_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_custom_reports_updated_at BEFORE UPDATE ON custom_reports FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_dashboards_updated_at BEFORE UPDATE ON dashboards FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_dashboard_widgets_updated_at BEFORE UPDATE ON dashboard_widgets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_report_subscriptions_updated_at BEFORE UPDATE ON report_subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_data_sources_updated_at BEFORE UPDATE ON data_sources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_saved_queries_updated_at BEFORE UPDATE ON saved_queries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_report_comments_updated_at BEFORE UPDATE ON report_comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();