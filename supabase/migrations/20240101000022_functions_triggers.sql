-- =====================================================
-- FUNCTIONS & TRIGGERS MIGRATION
-- Final utility functions and trigger setup
-- Created: 2025-06-13 20:36:35 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

-- Function to generate unique slug
CREATE OR REPLACE FUNCTION generate_unique_slug(
    base_text TEXT,
    table_name TEXT,
    org_id UUID DEFAULT NULL,
    exclude_id UUID DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
base_slug TEXT;
    final_slug TEXT;
    counter INTEGER := 1;
    exists_check BOOLEAN;
BEGIN
    -- Create base slug
    base_slug := regexp_replace(
        regexp_replace(
            regexp_replace(lower(base_text), '[^a-z0-9\s-]', '', 'g'),
            '\s+', '-', 'g'
        ),
        '-+', '-', 'g'
    );

    -- Trim leading/trailing hyphens
    base_slug := trim(both '-' from base_slug);

    -- Ensure minimum length
    IF length(base_slug) < 3 THEN
        base_slug := base_slug || '-item';
END IF;

    final_slug := base_slug;

    -- Check for uniqueness and increment if needed
    LOOP
        -- Build dynamic query to check existence
EXECUTE format(
            'SELECT EXISTS(SELECT 1 FROM %I WHERE slug = $1 %s %s)',
            table_name,
            CASE WHEN org_id IS NOT NULL THEN 'AND organization_id = $2' ELSE '' END,
            CASE WHEN exclude_id IS NOT NULL THEN 'AND id != $3' ELSE '' END
        ) INTO exists_check
        USING final_slug, org_id, exclude_id;

        -- If slug is unique, break the loop
        EXIT WHEN NOT exists_check;

        -- Increment counter and try again
        final_slug := base_slug || '-' || counter;
        counter := counter + 1;

        -- Safety check to prevent infinite loop
        IF counter > 1000 THEN
            final_slug := base_slug || '-' || extract(epoch from now())::text;
            EXIT;
END IF;
END LOOP;

RETURN final_slug;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate business days between dates
CREATE OR REPLACE FUNCTION calculate_business_days(
    start_date DATE,
    end_date DATE,
    exclude_weekends BOOLEAN DEFAULT TRUE,
    exclude_holidays DATE[] DEFAULT '{}'
)
RETURNS INTEGER AS $$
DECLARE
current_date DATE := start_date;
    business_days INTEGER := 0;
BEGIN
    WHILE current_date <= end_date LOOP
        -- Check if it's a weekend day
        IF exclude_weekends AND EXTRACT(dow FROM current_date) IN (0, 6) THEN
            -- Skip weekends
        ELSIF current_date = ANY(exclude_holidays) THEN
            -- Skip holidays
        ELSE
            business_days := business_days + 1;
END IF;

current_date := current_date + 1;
END LOOP;

RETURN business_days;
END;
$$ LANGUAGE plpgsql;

-- Function to format currency
CREATE OR REPLACE FUNCTION format_currency(
    amount DECIMAL(15,2),
    currency_code VARCHAR(3) DEFAULT 'USD',
    show_symbol BOOLEAN DEFAULT TRUE
)
RETURNS TEXT AS $$
DECLARE
formatted_amount TEXT;
    currency_symbol TEXT;
BEGIN
    -- Format the number with commas
    formatted_amount := to_char(amount, 'FM999,999,999,990.00');

    -- Get currency symbol
    currency_symbol := CASE currency_code
        WHEN 'USD' THEN '$'
        WHEN 'EUR' THEN '€'
        WHEN 'GBP' THEN '£'
        WHEN 'JPY' THEN '¥'
        ELSE currency_code || ' '
END;

    -- Return formatted currency
    IF show_symbol THEN
        RETURN currency_symbol || formatted_amount;
ELSE
        RETURN formatted_amount;
END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to send email notification (placeholder for external service integration)
CREATE OR REPLACE FUNCTION send_email_notification(
    recipient_email VARCHAR(255),
    subject VARCHAR(255),
    body TEXT,
    template_name VARCHAR(100) DEFAULT NULL,
    template_data JSONB DEFAULT '{}'
)
RETURNS BOOLEAN AS $$
BEGIN
    -- This would integrate with an email service like Resend, SendGrid, etc.
    -- For now, we'll just log the attempt

INSERT INTO audit_logs (
    organization_id,
    user_id,
    action,
    resource_type,
    resource_id,
    metadata
) VALUES (
             auth.user_organization_id(),
             auth.uid(),
             'email_sent',
             'notifications',
             gen_random_uuid(),
             jsonb_build_object(
                     'recipient', recipient_email,
                     'subject', subject,
                     'template', template_name,
                     'timestamp', NOW()
             )
         );

RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate lead score
CREATE OR REPLACE FUNCTION calculate_lead_score(
    contact_uuid UUID
)
RETURNS INTEGER AS $$
DECLARE
contact_record RECORD;
    score INTEGER := 0;
    activity_count INTEGER;
    email_engagement INTEGER;
    company_size_score INTEGER;
BEGIN
    -- Get contact details
SELECT * INTO contact_record FROM contacts WHERE id = contact_uuid;

IF NOT FOUND THEN
        RETURN 0;
END IF;

    -- Base demographic scoring
CASE contact_record.status
        WHEN 'lead' THEN score := score + 10;
WHEN 'prospect' THEN score := score + 20;
WHEN 'customer' THEN score := score + 50;
ELSE score := score + 5;
END CASE;

    -- Job title scoring
    IF contact_record.job_title ~* '(ceo|cto|cfo|president|director|manager|head)' THEN
        score := score + 15;
    ELSIF contact_record.job_title ~* '(coordinator|assistant|intern)' THEN
        score := score + 5;
ELSE
        score := score + 10;
END IF;

    -- Email domain scoring (corporate vs personal)
    IF contact_record.email ~* '@(gmail|yahoo|hotmail|outlook)' THEN
        score := score + 5;
ELSE
        score := score + 15;
END IF;

    -- Activity engagement scoring
SELECT COUNT(*) INTO activity_count
FROM activities
WHERE contact_id = contact_uuid
  AND created_at > NOW() - INTERVAL '30 days';

score := score + LEAST(activity_count * 2, 20);

    -- Company size scoring (if associated with company)
    IF contact_record.company_id IS NOT NULL THEN
SELECT CASE
           WHEN size = 'enterprise' THEN 25
    WHEN size = 'large' THEN 20
    WHEN size = 'medium' THEN 15
    WHEN size = 'small' THEN 10
    ELSE 5
END INTO company_size_score
        FROM companies
        WHERE id = contact_record.company_id;

        score := score + COALESCE(company_size_score, 0);
END IF;

    -- Ensure score is within reasonable bounds
RETURN GREATEST(0, LEAST(score, 100));
END;
$$ LANGUAGE plpgsql;

-- Function to get entity permissions for user
CREATE OR REPLACE FUNCTION get_entity_permissions(
    entity_type_param VARCHAR(50),
    entity_id_param UUID,
    user_uuid UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
user_uuid_val UUID;
    user_record RECORD;
    permissions JSONB := '{}';
    can_view BOOLEAN := FALSE;
    can_edit BOOLEAN := FALSE;
    can_delete BOOLEAN := FALSE;
    can_share BOOLEAN := FALSE;
BEGIN
    user_uuid_val := COALESCE(user_uuid, auth.uid());

    -- Get user details
SELECT * INTO user_record FROM user_profiles WHERE id = user_uuid_val;

IF NOT FOUND THEN
        RETURN permissions;
END IF;

    -- Check permissions based on entity type and user role
CASE entity_type_param
        WHEN 'contacts', 'companies', 'deals' THEN
            can_view := TRUE;
            can_edit := user_record.role IN ('super_admin', 'admin', 'manager', 'sales_rep');
            can_delete := user_record.role IN ('super_admin', 'admin');
            can_share := user_record.role IN ('super_admin', 'admin', 'manager');

WHEN 'documents' THEN
            can_view := auth.can_access_document(entity_id_param);
            can_edit := can_view AND (
                user_record.role IN ('super_admin', 'admin') OR
                EXISTS (
                    SELECT 1 FROM document_collaborators dc
                    WHERE dc.document_id = entity_id_param
                    AND dc.user_id = user_uuid_val
                    AND dc.can_edit = TRUE
                )
            );
            can_delete := user_record.role IN ('super_admin', 'admin');
            can_share := can_edit;

WHEN 'workflows' THEN
            can_view := TRUE;
            can_edit := user_record.role IN ('super_admin', 'admin');
            can_delete := user_record.role IN ('super_admin', 'admin');
            can_share := FALSE;

ELSE
            can_view := TRUE;
            can_edit := user_record.role IN ('super_admin', 'admin');
            can_delete := user_record.role IN ('super_admin');
            can_share := FALSE;
END CASE;

    permissions := jsonb_build_object(
        'can_view', can_view,
        'can_edit', can_edit,
        'can_delete', can_delete,
        'can_share', can_share,
        'user_role', user_record.role
    );

RETURN permissions;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up old data
CREATE OR REPLACE FUNCTION cleanup_old_data()
RETURNS TEXT AS $$
DECLARE
cleanup_summary TEXT := '';
    deleted_count INTEGER;
BEGIN
    -- Clean up old analytics events (older than 2 years)
DELETE FROM analytics_events
WHERE timestamp < NOW() - INTERVAL '2 years';
GET DIAGNOSTICS deleted_count = ROW_COUNT;
cleanup_summary := cleanup_summary || 'Analytics events: ' || deleted_count || E'\n';

    -- Clean up old audit logs (older than 7 years, except for critical actions)
DELETE FROM audit_logs
WHERE timestamp < NOW() - INTERVAL '7 years'
    AND action NOT IN ('delete', 'export', 'login_failed', 'permission_change');
GET DIAGNOSTICS deleted_count = ROW_COUNT;
cleanup_summary := cleanup_summary || 'Audit logs: ' || deleted_count || E'\n';

    -- Clean up old search queries (older than 1 year)
DELETE FROM search_queries
WHERE searched_at < NOW() - INTERVAL '1 year';
GET DIAGNOSTICS deleted_count = ROW_COUNT;
cleanup_summary := cleanup_summary || 'Search queries: ' || deleted_count || E'\n';

    -- Clean up old flag evaluations (older than 6 months)
DELETE FROM flag_evaluations
WHERE evaluated_at < NOW() - INTERVAL '6 months';
GET DIAGNOSTICS deleted_count = ROW_COUNT;
cleanup_summary := cleanup_summary || 'Flag evaluations: ' || deleted_count || E'\n';

    -- Clean up old webhook deliveries (older than 3 months, except failed ones)
DELETE FROM webhook_deliveries
WHERE scheduled_at < NOW() - INTERVAL '3 months'
  AND status != 'failed';
GET DIAGNOSTICS deleted_count = ROW_COUNT;
cleanup_summary := cleanup_summary || 'Webhook deliveries: ' || deleted_count || E'\n';

    -- Clean up soft-deleted records (older than 1 year)
DELETE FROM contacts WHERE deleted_at < NOW() - INTERVAL '1 year';
GET DIAGNOSTICS deleted_count = ROW_COUNT;
cleanup_summary := cleanup_summary || 'Soft-deleted contacts: ' || deleted_count || E'\n';

DELETE FROM companies WHERE deleted_at < NOW() - INTERVAL '1 year';
GET DIAGNOSTICS deleted_count = ROW_COUNT;
cleanup_summary := cleanup_summary || 'Soft-deleted companies: ' || deleted_count || E'\n';

DELETE FROM deals WHERE deleted_at < NOW() - INTERVAL '1 year';
GET DIAGNOSTICS deleted_count = ROW_COUNT;
cleanup_summary := cleanup_summary || 'Soft-deleted deals: ' || deleted_count || E'\n';

    -- Vacuum analyze for performance
    VACUUM ANALYZE;

    cleanup_summary := cleanup_summary || 'Database vacuumed and analyzed.';

RETURN cleanup_summary;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGER FUNCTIONS
-- =====================================================

-- Function to auto-assign deals to pipeline stages
CREATE OR REPLACE FUNCTION auto_assign_deal_stage()
RETURNS TRIGGER AS $$
DECLARE
default_stage_id UUID;
BEGIN
    -- If no stage is specified, assign to first stage of the pipeline
    IF NEW.stage_id IS NULL AND NEW.pipeline_id IS NOT NULL THEN
SELECT id INTO default_stage_id
FROM deal_stages
WHERE pipeline_id = NEW.pipeline_id
ORDER BY position ASC
    LIMIT 1;

NEW.stage_id := default_stage_id;
END IF;

    -- Set initial probability based on stage
    IF NEW.probability IS NULL AND NEW.stage_id IS NOT NULL THEN
SELECT probability INTO NEW.probability
FROM deal_stages
WHERE id = NEW.stage_id;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-assigning deal stages
CREATE TRIGGER auto_assign_deal_stage_trigger
    BEFORE INSERT ON deals
    FOR EACH ROW
    EXECUTE FUNCTION auto_assign_deal_stage();

-- Function to update contact company relationship
CREATE OR REPLACE FUNCTION update_contact_company_relationship()
RETURNS TRIGGER AS $$
BEGIN
    -- When a contact's company changes, update the company's contact count
    IF TG_OP = 'UPDATE' AND OLD.company_id IS DISTINCT FROM NEW.company_id THEN
        -- Decrease count for old company
        IF OLD.company_id IS NOT NULL THEN
UPDATE companies
SET contact_count = contact_count - 1
WHERE id = OLD.company_id;
END IF;

        -- Increase count for new company
        IF NEW.company_id IS NOT NULL THEN
UPDATE companies
SET contact_count = contact_count + 1
WHERE id = NEW.company_id;
END IF;
    ELSIF TG_OP = 'INSERT' AND NEW.company_id IS NOT NULL THEN
        -- Increase count for new contact
UPDATE companies
SET contact_count = contact_count + 1
WHERE id = NEW.company_id;
ELSIF TG_OP = 'DELETE' AND OLD.company_id IS NOT NULL THEN
        -- Decrease count for deleted contact
UPDATE companies
SET contact_count = contact_count - 1
WHERE id = OLD.company_id;
END IF;

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating contact-company relationships
CREATE TRIGGER update_contact_company_relationship_trigger
    AFTER INSERT OR UPDATE OR DELETE ON contacts
    FOR EACH ROW
    EXECUTE FUNCTION update_contact_company_relationship();

-- Function to auto-generate notification for important events
CREATE OR REPLACE FUNCTION auto_generate_notifications()
RETURNS TRIGGER AS $$
DECLARE
notification_data JSONB;
    event_type VARCHAR(100);
BEGIN
    -- Determine event type based on table and operation
    event_type := TG_TABLE_NAME || '_' || lower(TG_OP);

CASE TG_TABLE_NAME
        WHEN 'deals' THEN
            IF TG_OP = 'INSERT' THEN
                notification_data := jsonb_build_object(
                    'deal_id', NEW.id,
                    'deal_title', NEW.title,
                    'deal_value', NEW.value,
                    'organization_id', NEW.organization_id
                );
                PERFORM process_notification_rules('deal_created', notification_data);
            ELSIF TG_OP = 'UPDATE' AND OLD.status != NEW.status AND NEW.status = 'won' THEN
                notification_data := jsonb_build_object(
                    'deal_id', NEW.id,
                    'deal_title', NEW.title,
                    'deal_value', NEW.value,
                    'organization_id', NEW.organization_id
                );
                PERFORM process_notification_rules('deal_won', notification_data);
END IF;

WHEN 'activities' THEN
            IF TG_OP = 'INSERT' AND NEW.scheduled_at IS NOT NULL THEN
                notification_data := jsonb_build_object(
                    'activity_id', NEW.id,
                    'activity_title', NEW.title,
                    'activity_type', NEW.type,
                    'scheduled_at', NEW.scheduled_at,
                    'organization_id', NEW.organization_id,
                    'owner_id', NEW.owner_id
                );
                PERFORM process_notification_rules('activity_scheduled', notification_data);
END IF;
END CASE;

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Triggers for auto-generating notifications
CREATE TRIGGER auto_generate_deal_notifications_trigger
    AFTER INSERT OR UPDATE ON deals
                        FOR EACH ROW
                        EXECUTE FUNCTION auto_generate_notifications();

CREATE TRIGGER auto_generate_activity_notifications_trigger
    AFTER INSERT ON activities
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_notifications();

-- =====================================================
-- SCHEDULED FUNCTION SETUP
-- =====================================================

-- Function to run daily maintenance tasks
CREATE OR REPLACE FUNCTION run_daily_maintenance()
RETURNS TEXT AS $$
DECLARE
result_summary TEXT := '';
    org_record RECORD;
BEGIN
    result_summary := 'Daily maintenance started at ' || NOW() || E'\n';

    -- Update lead scores for all contacts
FOR org_record IN SELECT id FROM organizations LOOP
UPDATE contacts
SET lead_score = calculate_lead_score(id)
WHERE organization_id = org_record.id
  AND deleted_at IS NULL;
END LOOP;
    result_summary := result_summary || 'Lead scores updated' || E'\n';

    -- Update user segment memberships
    PERFORM update_user_segment_membership(id)
    FROM user_segments
    WHERE auto_update = TRUE;
    result_summary := result_summary || 'User segments updated' || E'\n';

    -- Calculate daily analytics
FOR org_record IN SELECT id FROM organizations LOOP
                                 -- Update search suggestions
    PERFORM update_search_suggestions(org_record.id);

-- Calculate analytics for yesterday
PERFORM calculate_workflow_analytics(
            w.id,
            CURRENT_DATE - 1,
            CURRENT_DATE,
            'daily'
        ) FROM workflows w WHERE w.organization_id = org_record.id;
END LOOP;
    result_summary := result_summary || 'Analytics calculated' || E'\n';

    -- Process scheduled workflows and activities
    PERFORM process_activity_sequence_enrollments();
    result_summary := result_summary || 'Scheduled workflows processed' || E'\n';

    -- Check usage limits and send alerts
FOR org_record IN SELECT id FROM organizations LOOP
    PERFORM check_usage_limits(org_record.id);
END LOOP;
    result_summary := result_summary || 'Usage limits checked' || E'\n';

    result_summary := result_summary || 'Daily maintenance completed at ' || NOW();

RETURN result_summary;
END;
$$ LANGUAGE plpgsql;

-- Function to run weekly maintenance tasks
CREATE OR REPLACE FUNCTION run_weekly_maintenance()
RETURNS TEXT AS $$
DECLARE
result_summary TEXT := '';
BEGIN
    result_summary := 'Weekly maintenance started at ' || NOW() || E'\n';

    -- Clean up old data
    result_summary := result_summary || cleanup_old_data() || E'\n';

    -- Update database statistics
    ANALYZE;
    result_summary := result_summary || 'Database statistics updated' || E'\n';

    -- Generate weekly reports
INSERT INTO revenue_analytics (
    organization_id,
    period_type,
    period_start,
    period_end
)
SELECT
    id,
    'weekly',
    CURRENT_DATE - INTERVAL '1 week',
    CURRENT_DATE - 1
FROM organizations
ON CONFLICT (organization_id, period_type, period_start) DO NOTHING;

result_summary := result_summary || 'Weekly reports generated' || E'\n';
    result_summary := result_summary || 'Weekly maintenance completed at ' || NOW();

RETURN result_summary;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- HELPER FUNCTIONS FOR EXTERNAL INTEGRATIONS
-- =====================================================

-- Function to queue webhook delivery
CREATE OR REPLACE FUNCTION queue_webhook_delivery(
    webhook_uuid UUID,
    event_type_param VARCHAR(100),
    event_payload JSONB
)
RETURNS UUID AS $$
DECLARE
delivery_id UUID;
BEGIN
    delivery_id := create_webhook_delivery(webhook_uuid, event_type_param, event_payload);

    -- In a real implementation, this would queue the delivery to a background job processor
    -- For now, we'll just mark it as scheduled

RETURN delivery_id;
END;
$$ LANGUAGE plpgsql;

-- Function to sync with external CRM
CREATE OR REPLACE FUNCTION sync_with_external_crm(
    integration_uuid UUID,
    entity_type_param VARCHAR(50),
    entity_id_param UUID,
    operation VARCHAR(20) -- create, update, delete
)
RETURNS BOOLEAN AS $$
DECLARE
integration_record RECORD;
    sync_successful BOOLEAN := FALSE;
BEGIN
    -- Get integration details
SELECT * INTO integration_record
FROM integrations
WHERE id = integration_uuid
  AND status = 'active';

IF NOT FOUND THEN
        RETURN FALSE;
END IF;

    -- Log the sync attempt
INSERT INTO integration_sync_logs (
    integration_id,
    sync_type,
    sync_direction,
    triggered_by,
    status
) VALUES (
             integration_uuid,
             'manual',
             'outbound',
             'system',
             'started'
         );

-- In a real implementation, this would make API calls to external systems
-- For now, we'll simulate success
sync_successful := TRUE;

    -- Update the sync log
UPDATE integration_sync_logs
SET
    status = CASE WHEN sync_successful THEN 'completed' ELSE 'failed' END,
    completed_at = NOW()
WHERE integration_id = integration_uuid
  AND status = 'started'
    ORDER BY started_at DESC
    LIMIT 1;

RETURN sync_successful;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PERFORMANCE MONITORING FUNCTIONS
-- =====================================================

-- Function to get database performance metrics
CREATE OR REPLACE FUNCTION get_database_performance_metrics()
RETURNS TABLE (
    metric_name TEXT,
    metric_value NUMERIC,
    metric_unit TEXT,
    measured_at TIMESTAMPTZ
) AS $$
BEGIN
RETURN QUERY
SELECT
    'total_connections'::TEXT,
    (SELECT count(*) FROM pg_stat_activity)::NUMERIC,
    'connections'::TEXT,
    NOW()
UNION ALL
SELECT
    'active_connections'::TEXT,
    (SELECT count(*) FROM pg_stat_activity WHERE state = 'active')::NUMERIC,
    'connections'::TEXT,
    NOW()
UNION ALL
SELECT
    'database_size'::TEXT,
    (SELECT pg_database_size(current_database()))::NUMERIC,
    'bytes'::TEXT,
    NOW()
UNION ALL
SELECT
    'cache_hit_ratio'::TEXT,
    (SELECT
         CASE WHEN sum(blks_hit + blks_read) = 0 THEN 0
              ELSE sum(blks_hit) * 100.0 / sum(blks_hit + blks_read)
             END
     FROM pg_stat_database WHERE datname = current_database())::NUMERIC,
    'percentage'::TEXT,
    NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to get slow queries
CREATE OR REPLACE FUNCTION get_slow_queries()
RETURNS TABLE (
    query_text TEXT,
    calls BIGINT,
    total_time DOUBLE PRECISION,
    avg_time DOUBLE PRECISION,
    max_time DOUBLE PRECISION
) AS $$
BEGIN
RETURN QUERY
SELECT
    pss.query,
    pss.calls,
    pss.total_exec_time,
    pss.mean_exec_time,
    pss.max_exec_time
FROM pg_stat_statements pss
WHERE pss.mean_exec_time > 100 -- Queries taking more than 100ms on average
ORDER BY pss.mean_exec_time DESC
    LIMIT 20;
EXCEPTION WHEN OTHERS THEN
    -- pg_stat_statements extension might not be installed
    RETURN;
END;
$$ LANGUAGE plpgsql;