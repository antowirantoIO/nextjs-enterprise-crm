-- =====================================================
-- PERFORMANCE INDEXES MIGRATION
-- Advanced indexing strategy for optimal performance
-- Created: 2025-06-13 20:36:35 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- COMPOSITE INDEXES FOR COMMON QUERY PATTERNS
-- =====================================================

-- User profiles composite indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_org_role_status
    ON user_profiles(organization_id, role, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_org_active
    ON user_profiles(organization_id, status)
    WHERE status = 'active' AND deleted_at IS NULL;

-- Contacts composite indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_org_status_created
    ON contacts(organization_id, status, created_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_org_company_status
    ON contacts(organization_id, company_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_org_owner_status
    ON contacts(organization_id, owner_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_lead_score_status
    ON contacts(organization_id, lead_score DESC, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_last_activity
    ON contacts(organization_id, last_activity_at DESC NULLS LAST)
    WHERE deleted_at IS NULL;

-- Companies composite indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_companies_org_size_industry
    ON companies(organization_id, size, industry)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_companies_org_owner_status
    ON companies(organization_id, owner_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_companies_org_created
    ON companies(organization_id, created_at DESC)
    WHERE deleted_at IS NULL;

-- Deals composite indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_org_pipeline_stage
    ON deals(organization_id, pipeline_id, stage_id)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_org_status_value
    ON deals(organization_id, status, value DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_org_owner_status
    ON deals(organization_id, owner_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_org_contact_status
    ON deals(organization_id, contact_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_org_company_status
    ON deals(organization_id, company_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_close_date_status
    ON deals(organization_id, expected_close_date, status)
    WHERE status = 'open' AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_probability_value
    ON deals(organization_id, probability DESC, value DESC)
    WHERE status = 'open' AND deleted_at IS NULL;

-- Activities composite indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_org_owner_scheduled
    ON activities(organization_id, owner_id, scheduled_at DESC NULLS LAST)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_org_type_status
    ON activities(organization_id, type, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_org_contact_type
    ON activities(organization_id, contact_id, type)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_org_deal_type
    ON activities(organization_id, deal_id, type)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_overdue
    ON activities(organization_id, owner_id, scheduled_at)
    WHERE status = 'scheduled' AND scheduled_at < NOW() AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_today
    ON activities(organization_id, owner_id)
    WHERE DATE(scheduled_at) = CURRENT_DATE AND deleted_at IS NULL;

-- =====================================================
-- NOTIFICATION PERFORMANCE INDEXES
-- =====================================================

-- Notifications indexes for efficient querying
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_recipient_unread
    ON notifications(recipient_id, created_at DESC)
    WHERE is_read = FALSE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_org_type_created
    ON notifications(organization_id, type, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifications_recipient_type_read
    ON notifications(recipient_id, type, is_read, created_at DESC);

-- Notification deliveries for monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notification_deliveries_status_created
    ON notification_deliveries(delivery_status, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notification_deliveries_retry
    ON notification_deliveries(next_retry_at)
    WHERE delivery_status = 'failed' AND attempt_number < max_attempts;

-- =====================================================
-- ANALYTICS PERFORMANCE INDEXES
-- =====================================================

-- Analytics events for reporting
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_events_org_name_timestamp
    ON analytics_events(organization_id, event_name, timestamp DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_events_user_timestamp
    ON analytics_events(user_id, timestamp DESC)
    WHERE user_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_events_session_timestamp
    ON analytics_events(session_id, timestamp)
    WHERE session_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_analytics_events_revenue
    ON analytics_events(organization_id, timestamp)
    WHERE revenue_amount IS NOT NULL AND revenue_amount > 0;

-- Report executions for performance monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_report_executions_report_executed
    ON report_executions(report_id, executed_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_report_executions_user_executed
    ON report_executions(executed_by, executed_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_report_executions_status_time
    ON report_executions(status, execution_time_ms DESC)
    WHERE execution_time_ms IS NOT NULL;

-- =====================================================
-- DOCUMENT PERFORMANCE INDEXES
-- =====================================================

-- Documents for access control and search
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_org_access_updated
    ON documents(organization_id, access_level, updated_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_org_type_status
    ON documents(organization_id, document_type, status)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_folder_updated
    ON documents(folder_id, updated_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_documents_creator_updated
    ON documents(created_by, updated_at DESC)
    WHERE deleted_at IS NULL;

-- Document access logs for analytics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_document_access_logs_doc_date
    ON document_access_logs(document_id, accessed_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_document_access_logs_user_date
    ON document_access_logs(user_id, accessed_at DESC)
    WHERE user_id IS NOT NULL;

-- =====================================================
-- INTEGRATION PERFORMANCE INDEXES
-- =====================================================

-- Integrations for monitoring and management
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_integrations_org_status_updated
    ON integrations(organization_id, status, updated_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_integrations_provider_status
    ON integrations(provider_id, status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_integrations_next_sync
    ON integrations(next_sync_at)
    WHERE auto_sync = TRUE AND status = 'active';

-- Integration sync logs for monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_integration_sync_logs_integration_started
    ON integration_sync_logs(integration_id, started_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_integration_sync_logs_status_started
    ON integration_sync_logs(status, started_at DESC);

-- Webhook deliveries for retry and monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_webhook_deliveries_webhook_scheduled
    ON webhook_deliveries(webhook_id, scheduled_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_webhook_deliveries_status_scheduled
    ON webhook_deliveries(status, scheduled_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_webhook_deliveries_retry_due
    ON webhook_deliveries(next_retry_at)
    WHERE status = 'failed' AND next_retry_at IS NOT NULL;

-- =====================================================
-- WORKFLOW PERFORMANCE INDEXES
-- =====================================================

-- Workflows for execution and monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflows_org_active_updated
    ON workflows(organization_id, is_active, updated_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflows_next_scheduled
    ON workflows(next_scheduled_run)
    WHERE schedule_cron IS NOT NULL AND is_active = TRUE;

-- Workflow executions for monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflow_executions_workflow_started
    ON workflow_executions(workflow_id, started_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflow_executions_status_started
    ON workflow_executions(status, started_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflow_executions_running
    ON workflow_executions(workflow_id, started_at)
    WHERE status IN ('pending', 'running');

-- Workflow step executions for debugging
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflow_step_executions_execution_order
    ON workflow_step_executions(execution_id, step_order);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflow_step_executions_status_started
    ON workflow_step_executions(status, started_at DESC);

-- =====================================================
-- COLLABORATION PERFORMANCE INDEXES
-- =====================================================

-- Collaboration spaces for access control

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collaboration_spaces_org_status_updated
    ON collaboration_spaces(organization_id, status, updated_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_collaboration_spaces_related_entities
    ON collaboration_spaces(organization_id, related_deal_id)
    WHERE related_deal_id IS NOT NULL;

-- Space members for access control
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_space_members_user_status
    ON space_members(user_id, status)
    WHERE status = 'active';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_space_members_space_role
    ON space_members(space_id, role, status);

-- Team messages for real-time chat
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_team_messages_space_created
    ON team_messages(space_id, created_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_team_messages_thread
    ON team_messages(parent_message_id, created_at)
    WHERE parent_message_id IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_team_messages_mentions
    ON team_messages USING GIN(mentions)
    WHERE array_length(mentions, 1) > 0;

-- Board cards for project management
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_board_cards_board_column_position
    ON board_cards(board_id, column_id, position);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_board_cards_assigned_due
    ON board_cards USING GIN(assigned_to)
    WHERE due_date IS NOT NULL AND is_archived = FALSE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_board_cards_overdue
    ON board_cards(board_id, due_date)
    WHERE due_date < NOW() AND completed_at IS NULL AND is_archived = FALSE;

-- =====================================================
-- BILLING PERFORMANCE INDEXES
-- =====================================================

-- Subscriptions for billing operations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_org_subscriptions_org_status_billing
    ON organization_subscriptions(organization_id, status, next_billing_date);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_org_subscriptions_billing_due
    ON organization_subscriptions(next_billing_date)
    WHERE status = 'active' AND auto_renew = TRUE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_org_subscriptions_trial_expiring
    ON organization_subscriptions(trial_end)
    WHERE status = 'trial' AND trial_end BETWEEN NOW() AND NOW() + INTERVAL '7 days';

-- Invoices for billing management
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_invoices_org_status_due
    ON invoices(organization_id, status, due_date);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_invoices_overdue
    ON invoices(due_date, status)
    WHERE status IN ('sent', 'overdue') AND due_date < CURRENT_DATE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_invoices_payment_tracking
    ON invoices(organization_id, amount_due DESC)
    WHERE amount_due > 0;

-- Payments for transaction tracking
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_org_status_processed
    ON payments(organization_id, status, processed_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_subscription_processed
    ON payments(subscription_id, processed_at DESC)
    WHERE status = 'succeeded';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_failed_retry
    ON payments(organization_id, failed_at DESC)
    WHERE status = 'failed';

-- Usage metrics for monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_usage_metrics_org_metric_date
    ON usage_metrics(organization_id, metric_name, measurement_date DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_usage_metrics_subscription_date
    ON usage_metrics(subscription_id, measurement_date DESC)
    WHERE subscription_id IS NOT NULL;

-- =====================================================
-- FEATURE FLAGS PERFORMANCE INDEXES
-- =====================================================

-- Feature flags for evaluation
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feature_flags_org_status_key
    ON feature_flags(organization_id, status, flag_key)
    WHERE status != 'disabled';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feature_flags_global_active
    ON feature_flags(flag_key, status)
    WHERE organization_id IS NULL AND status != 'disabled';

-- Flag evaluations for analytics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_flag_evaluations_flag_date
    ON flag_evaluations(flag_id, evaluated_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_flag_evaluations_user_flag
    ON flag_evaluations(user_id, flag_id, evaluated_at DESC)
    WHERE user_id IS NOT NULL;

-- User segments for targeting
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_segments_org_active_updated
    ON user_segments(organization_id, is_active, last_calculated_at)
    WHERE auto_update = TRUE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_segment_members_user_segment
    ON user_segment_members(user_id, segment_id);

-- =====================================================
-- SEARCH PERFORMANCE INDEXES
-- =====================================================

-- Search queries for analytics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_search_queries_org_searched
    ON search_queries(organization_id, searched_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_search_queries_user_searched
    ON search_queries(user_id, searched_at DESC)
    WHERE user_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_search_queries_successful
    ON search_queries(organization_id, was_successful, searched_at DESC);

-- Global search index for performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_global_search_index_org_type_updated
    ON global_search_index(organization_id, entity_type, last_updated DESC)
    WHERE is_active = TRUE;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_global_search_index_boost
    ON global_search_index(organization_id, boost_factor DESC)
    WHERE is_active = TRUE AND boost_factor > 1.0;

-- =====================================================
-- AUDIT AND COMPLIANCE INDEXES
-- =====================================================

-- Audit logs for compliance and investigation
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_org_action_timestamp
    ON audit_logs(organization_id, action, timestamp DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_user_timestamp
    ON audit_logs(user_id, timestamp DESC)
    WHERE user_id IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_resource_timestamp
    ON audit_logs(resource_type, resource_id, timestamp DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_high_risk
    ON audit_logs(organization_id, timestamp DESC)
    WHERE risk_score > 70;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_compliance_review
    ON audit_logs(organization_id, compliance_reviewed, timestamp DESC)
    WHERE contains_pii = TRUE OR contains_sensitive_data = TRUE;

-- Security events for monitoring
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_events_org_severity_detected
    ON security_events(organization_id, severity, detected_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_security_events_status_detected
    ON security_events(status, detected_at DESC)
    WHERE status = 'open';

-- =====================================================
-- KNOWLEDGE BASE PERFORMANCE INDEXES
-- =====================================================

-- Knowledge articles for search and access
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_knowledge_articles_org_status_published
    ON knowledge_articles(organization_id, status, published_at DESC)
    WHERE status = 'published';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_knowledge_articles_category_status
    ON knowledge_articles(category_id, status, view_count DESC)
    WHERE status = 'published';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_knowledge_articles_featured
    ON knowledge_articles(organization_id, is_featured, published_at DESC)
    WHERE is_featured = TRUE AND status = 'published';

-- Knowledge base search for analytics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kb_search_queries_org_searched
    ON kb_search_queries(organization_id, searched_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kb_search_queries_successful
    ON kb_search_queries(organization_id, found_answer, searched_at DESC)
    WHERE found_answer = TRUE;

-- Article views for analytics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_article_views_article_viewed
    ON article_views(article_id, viewed_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_article_views_user_viewed
    ON article_views(user_id, viewed_at DESC)
    WHERE user_id IS NOT NULL;

-- =====================================================
-- CUSTOM FIELDS PERFORMANCE INDEXES
-- =====================================================

-- Custom field values for entity queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_custom_field_values_entity_field
    ON custom_field_values(entity_type, entity_id, field_definition_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_custom_field_values_field_text
    ON custom_field_values(field_definition_id, text_value)
    WHERE text_value IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_custom_field_values_field_number
    ON custom_field_values(field_definition_id, number_value)
    WHERE number_value IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_custom_field_values_field_date
    ON custom_field_values(field_definition_id, date_value)
    WHERE date_value IS NOT NULL;

-- Custom field definitions for management
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_custom_field_definitions_org_entity_active
    ON custom_field_definitions(organization_id, entity_type, is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_custom_field_definitions_searchable
    ON custom_field_definitions(organization_id, entity_type)
    WHERE is_searchable = TRUE AND is_active = TRUE;

-- =====================================================
-- PARTIAL INDEXES FOR SPECIFIC CONDITIONS
-- =====================================================

-- Hot data indexes (recent activity)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_recent_activity
    ON contacts(organization_id, last_activity_at DESC)
    WHERE last_activity_at > NOW() - INTERVAL '30 days' AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_recent_open
    ON deals(organization_id, updated_at DESC)
    WHERE status = 'open' AND updated_at > NOW() - INTERVAL '30 days' AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_upcoming
    ON activities(organization_id, owner_id, scheduled_at)
    WHERE status = 'scheduled' AND scheduled_at BETWEEN NOW() AND NOW() + INTERVAL '7 days';

-- High-value data indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_high_value
    ON deals(organization_id, value DESC, expected_close_date)
    WHERE value > 10000 AND status = 'open' AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_high_score
    ON contacts(organization_id, lead_score DESC, last_activity_at DESC)
    WHERE lead_score > 70 AND deleted_at IS NULL;

-- Error and monitoring indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflow_executions_failed
    ON workflow_executions(workflow_id, started_at DESC)
    WHERE status = 'failed';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_integration_sync_logs_failed
    ON integration_sync_logs(integration_id, started_at DESC)
    WHERE status = 'failed';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_webhook_deliveries_failed
    ON webhook_deliveries(webhook_id, scheduled_at DESC)
    WHERE status = 'failed';

-- =====================================================
-- EXPRESSION INDEXES FOR COMPUTED QUERIES
-- =====================================================

-- Date-based expression indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_scheduled_date
    ON activities(organization_id, DATE(scheduled_at))
    WHERE scheduled_at IS NOT NULL AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_close_month
    ON deals(organization_id, DATE_TRUNC('month', expected_close_date))
    WHERE expected_close_date IS NOT NULL AND status = 'open' AND deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_created_month
    ON contacts(organization_id, DATE_TRUNC('month', created_at))
    WHERE deleted_at IS NULL;

-- Text search expression indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_name_lower
    ON contacts(organization_id, LOWER(full_name))
    WHERE deleted_at IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_companies_name_lower
    ON companies(organization_id, LOWER(name))
    WHERE deleted_at IS NULL;

-- =====================================================
-- COVERING INDEXES FOR READ-HEAVY QUERIES
-- =====================================================

-- Contact list queries (avoiding table lookups)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contacts_list_covering
    ON contacts(organization_id, status, created_at DESC)
    INCLUDE (full_name, email, job_title, lead_score, owner_id)
    WHERE deleted_at IS NULL;

-- Deal list queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_deals_list_covering
    ON deals(organization_id, status, updated_at DESC)
    INCLUDE (title, value, stage_id, contact_id, company_id, owner_id)
    WHERE deleted_at IS NULL;

-- Company list queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_companies_list_covering
    ON companies(organization_id, status, created_at DESC)
    INCLUDE (name, industry, size, website, contact_count, owner_id)
    WHERE deleted_at IS NULL;

-- Activity dashboard queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_dashboard_covering
    ON activities(organization_id, owner_id, scheduled_at DESC)
    INCLUDE (title, type, status, contact_id, deal_id)
    WHERE deleted_at IS NULL;

-- =====================================================
-- CLEANUP AND MAINTENANCE INDEXES
-- =====================================================

-- Indexes for cleanup operations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_soft_deleted_cleanup
    ON contacts(deleted_at)
    WHERE deleted_at IS NOT NULL AND deleted_at < NOW() - INTERVAL '1 year';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_old_analytics_events
    ON analytics_events(timestamp)
    WHERE timestamp < NOW() - INTERVAL '2 years';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_old_audit_logs
    ON audit_logs(timestamp)
    WHERE timestamp < NOW() - INTERVAL '7 years';

-- =====================================================
-- INDEX MONITORING VIEWS
-- =====================================================

-- View to monitor index usage
CREATE OR REPLACE VIEW index_usage_stats AS
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- View to identify unused indexes
CREATE OR REPLACE VIEW unused_indexes AS
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- View to monitor table sizes
CREATE OR REPLACE VIEW table_sizes AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- =====================================================
-- INDEX MAINTENANCE FUNCTIONS
-- =====================================================

-- Function to reindex all tables
CREATE OR REPLACE FUNCTION reindex_all_tables()
RETURNS TEXT AS $$
DECLARE
table_record RECORD;
    result_text TEXT := '';
BEGIN
FOR table_record IN
SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP
        EXECUTE 'REINDEX TABLE ' || quote_ident(table_record.tablename);
result_text := result_text || 'Reindexed ' || table_record.tablename || E'\n';
END LOOP;

RETURN result_text;
END;
$$ LANGUAGE plpgsql;

-- Function to analyze table statistics
CREATE OR REPLACE FUNCTION analyze_all_tables()
RETURNS TEXT AS $$
DECLARE
table_record RECORD;
    result_text TEXT := '';
BEGIN
FOR table_record IN
SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP
        EXECUTE 'ANALYZE ' || quote_ident(table_record.tablename);
result_text := result_text || 'Analyzed ' || table_record.tablename || E'\n';
END LOOP;

RETURN result_text;
END;
$$ LANGUAGE plpgsql;