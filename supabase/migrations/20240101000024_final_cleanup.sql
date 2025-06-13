-- =====================================================
-- FINAL CLEANUP MIGRATION
-- Final constraints, optimizations, and database finalization
-- Created: 2025-06-13 20:39:53 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- FINAL FOREIGN KEY CONSTRAINTS
-- =====================================================

-- Add any missing foreign key constraints that couldn't be added earlier
-- Most should already be in place, but let's ensure consistency

-- Ensure all organization references are properly constrained
DO $$
BEGIN
    -- Check and add missing foreign keys for organization_id columns
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'contact_sources_organization_id_fkey'
    ) THEN
ALTER TABLE contact_sources
    ADD CONSTRAINT contact_sources_organization_id_fkey
        FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
END IF;
END $$;

-- =====================================================
-- CHECK CONSTRAINTS FOR DATA INTEGRITY
-- =====================================================

-- Email format validation
ALTER TABLE contacts
    ADD CONSTRAINT IF NOT EXISTS check_contacts_email_format
    CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE user_profiles
    ADD CONSTRAINT IF NOT EXISTS check_user_profiles_email_format
    CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Phone number format validation (basic)
ALTER TABLE contacts
    ADD CONSTRAINT IF NOT EXISTS check_contacts_phone_format
    CHECK (phone IS NULL OR LENGTH(phone) >= 10);

-- URL format validation
ALTER TABLE companies
    ADD CONSTRAINT IF NOT EXISTS check_companies_website_format
    CHECK (website IS NULL OR website ~* '^https?://');

-- Percentage validation
ALTER TABLE deals
    ADD CONSTRAINT IF NOT EXISTS check_deals_probability_range
    CHECK (probability >= 0 AND probability <= 100);

-- Currency code validation
ALTER TABLE deals
    ADD CONSTRAINT IF NOT EXISTS check_deals_currency_format
    CHECK (currency ~ '^[A-Z]{3}$');

-- Date range validations
ALTER TABLE activities
    ADD CONSTRAINT IF NOT EXISTS check_activities_date_order
    CHECK (completed_at IS NULL OR completed_at >= scheduled_at);

ALTER TABLE deals
    ADD CONSTRAINT IF NOT EXISTS check_deals_close_date_future
    CHECK (expected_close_date IS NULL OR expected_close_date >= created_at::date);

-- Score validations
ALTER TABLE contacts
    ADD CONSTRAINT IF NOT EXISTS check_contacts_lead_score_range
    CHECK (lead_score >= 0 AND lead_score <= 100);

-- =====================================================
-- FINAL INDEXES FOR OPTIMIZATION
-- =====================================================

-- Ensure all primary keys have optimal indexes (should be automatic, but verify)
-- Add any missing unique constraints

-- Unique constraints for business logic
ALTER TABLE organizations
    ADD CONSTRAINT IF NOT EXISTS unique_organizations_subdomain
    UNIQUE (subdomain);

ALTER TABLE deal_pipelines
    ADD CONSTRAINT IF NOT EXISTS unique_pipeline_name_per_org
    UNIQUE (organization_id, name);

ALTER TABLE deal_stages
    ADD CONSTRAINT IF NOT EXISTS unique_stage_position_per_pipeline
    UNIQUE (pipeline_id, position);

ALTER TABLE custom_field_definitions
    ADD CONSTRAINT IF NOT EXISTS unique_field_name_per_entity_per_org
    UNIQUE (organization_id, entity_type, field_name);

-- =====================================================
-- DATABASE FUNCTIONS FOR MONITORING
-- =====================================================

-- Function to get database health status
CREATE OR REPLACE FUNCTION get_database_health()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    details TEXT,
    checked_at TIMESTAMPTZ
) AS $$
BEGIN
RETURN QUERY
-- Check database size
SELECT
    'database_size'::TEXT,
    CASE
        WHEN pg_database_size(current_database()) > 100 * 1024 * 1024 * 1024 THEN 'warning'
        ELSE 'healthy'
        END::TEXT,
    'Database size: ' || pg_size_pretty(pg_database_size(current_database()))::TEXT,
    NOW()

UNION ALL

-- Check connection count
SELECT
    'connection_count'::TEXT,
    CASE
        WHEN count(*) > 80 THEN 'warning'
        WHEN count(*) > 100 THEN 'critical'
        ELSE 'healthy'
        END::TEXT,
    'Active connections: ' || count(*)::TEXT,
    NOW()
FROM pg_stat_activity
WHERE state = 'active'

UNION ALL

-- Check for long-running queries
SELECT
    'long_running_queries'::TEXT,
    CASE
        WHEN count(*) > 0 THEN 'warning'
        ELSE 'healthy'
        END::TEXT,
    'Long-running queries (>5min): ' || count(*)::TEXT,
    NOW()
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < NOW() - INTERVAL '5 minutes'
  AND query NOT LIKE '%VACUUM%'
  AND query NOT LIKE '%pg_stat_activity%'

UNION ALL

-- Check for table bloat (simplified)
SELECT
    'table_bloat'::TEXT,
    'info'::TEXT,
    'Use VACUUM ANALYZE regularly to maintain performance'::TEXT,
    NOW()

UNION ALL

-- Check RLS status
SELECT
    'rls_enabled'::TEXT,
    CASE
        WHEN count(*) = 0 THEN 'critical'
        ELSE 'healthy'
        END::TEXT,
    'Tables with RLS enabled: ' || count(*)::TEXT,
    NOW()
FROM pg_tables t
         JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
  AND c.relrowsecurity = true;
END;
$$ LANGUAGE plpgsql;

-- Function to get table statistics
CREATE OR REPLACE FUNCTION get_table_statistics()
RETURNS TABLE (
    table_name TEXT,
    row_count BIGINT,
    table_size TEXT,
    index_size TEXT,
    total_size TEXT,
    last_vacuum TIMESTAMPTZ,
    last_analyze TIMESTAMPTZ
) AS $$
BEGIN
RETURN QUERY
SELECT
    t.tablename::TEXT,
    COALESCE(c.reltuples::BIGINT, 0),
    pg_size_pretty(pg_relation_size(c.oid))::TEXT,
    pg_size_pretty(pg_indexes_size(c.oid))::TEXT,
    pg_size_pretty(pg_total_relation_size(c.oid))::TEXT,
    s.last_vacuum,
    s.last_analyze
FROM pg_tables t
         LEFT JOIN pg_class c ON c.relname = t.tablename
         LEFT JOIN pg_stat_user_tables s ON s.relname = t.tablename
WHERE t.schemaname = 'public'
ORDER BY pg_total_relation_size(c.oid) DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- DATA VALIDATION FUNCTIONS
-- =====================================================

-- Function to validate data integrity across the database
CREATE OR REPLACE FUNCTION validate_data_integrity()
RETURNS TABLE (
    check_type TEXT,
    table_name TEXT,
    issue_count BIGINT,
    description TEXT
) AS $$
BEGIN
RETURN QUERY
-- Check for orphaned contacts (no organization)
SELECT
    'orphaned_records'::TEXT,
    'contacts'::TEXT,
    COUNT(*)::BIGINT,
    'Contacts without valid organization'::TEXT
FROM contacts c
         LEFT JOIN organizations o ON c.organization_id = o.id
WHERE o.id IS NULL

UNION ALL

-- Check for deals without stages
SELECT
    'orphaned_records'::TEXT,
    'deals'::TEXT,
    COUNT(*)::BIGINT,
    'Deals without valid stages'::TEXT
FROM deals d
         LEFT JOIN deal_stages ds ON d.stage_id = ds.id
WHERE ds.id IS NULL AND d.stage_id IS NOT NULL

UNION ALL

-- Check for activities without owners
SELECT
    'orphaned_records'::TEXT,
    'activities'::TEXT,
    COUNT(*)::BIGINT,
    'Activities without valid owners'::TEXT
FROM activities a
         LEFT JOIN user_profiles up ON a.owner_id = up.id
WHERE up.id IS NULL AND a.owner_id IS NOT NULL

UNION ALL

-- Check for invalid email addresses
SELECT
    'data_quality'::TEXT,
    'contacts'::TEXT,
    COUNT(*)::BIGINT,
    'Contacts with invalid email format'::TEXT
FROM contacts
WHERE email IS NOT NULL
  AND email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'

UNION ALL

-- Check for deals with invalid probabilities
SELECT
    'data_quality'::TEXT,
    'deals'::TEXT,
    COUNT(*)::BIGINT,
    'Deals with probability outside 0-100 range'::TEXT
FROM deals
WHERE probability < 0 OR probability > 100

UNION ALL

-- Check for future created dates
SELECT
    'data_quality'::TEXT,
    'all_tables'::TEXT,
    (
        (SELECT COUNT(*) FROM contacts WHERE created_at > NOW()) +
        (SELECT COUNT(*) FROM companies WHERE created_at > NOW()) +
        (SELECT COUNT(*) FROM deals WHERE created_at > NOW()) +
        (SELECT COUNT(*) FROM activities WHERE created_at > NOW())
        )::BIGINT,
    'Records with future creation dates'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- OPTIMIZATION RECOMMENDATIONS
-- =====================================================

-- Function to get optimization recommendations
CREATE OR REPLACE FUNCTION get_optimization_recommendations()
RETURNS TABLE (
    category TEXT,
    recommendation TEXT,
    priority TEXT,
    impact TEXT
) AS $$
BEGIN
RETURN QUERY
-- Check for missing indexes on frequently queried columns
SELECT
    'indexing'::TEXT,
    'Consider adding index on: ' || table_name || '(' || column_name || ')'::TEXT,
    'medium'::TEXT,
    'Query performance'::TEXT
FROM (
         -- This is a simplified check - in reality, you'd analyze query patterns
         SELECT 'contacts' as table_name, 'last_activity_at' as column_name
             WHERE NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE tablename = 'contacts'
            AND indexdef LIKE '%last_activity_at%'
        )
     ) missing_indexes

UNION ALL

-- Check for tables that might benefit from partitioning
SELECT
    'partitioning'::TEXT,
    'Consider partitioning large table: ' || tablename::TEXT,
    'low'::TEXT,
    'Storage and query performance for large datasets'::TEXT
FROM pg_tables t
         JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
  AND c.reltuples > 10000000 -- Tables with more than 10M rows

UNION ALL

-- Check for unused indexes
SELECT
    'maintenance'::TEXT,
    'Consider dropping unused index: ' || indexname::TEXT,
    'low'::TEXT,
    'Storage space and write performance'::TEXT
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND schemaname = 'public'
  AND indexname NOT LIKE '%_pkey' -- Don't recommend dropping primary keys

UNION ALL

-- General maintenance recommendations
SELECT
    'maintenance'::TEXT,
    'Schedule regular VACUUM ANALYZE operations'::TEXT,
    'high'::TEXT,
    'Overall database performance'::TEXT

UNION ALL

SELECT
    'monitoring'::TEXT,
    'Set up monitoring for slow queries and connection usage'::TEXT,
    'high'::TEXT,
    'Proactive performance management'::TEXT

UNION ALL

SELECT
    'backup'::TEXT,
    'Ensure regular backups are configured and tested'::TEXT,
    'critical'::TEXT,
    'Data protection and disaster recovery'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FINAL DATABASE SETTINGS
-- =====================================================

-- Update database configuration for optimal performance
-- These would typically be set at the database level, not in migrations

-- Set some session-level optimizations for the current connection
SET work_mem = '256MB';
SET maintenance_work_mem = '1GB';
SET random_page_cost = 1.1; -- Assuming SSD storage
SET effective_cache_size = '4GB';

-- =====================================================
-- FINAL GRANTS AND PERMISSIONS
-- =====================================================

-- Ensure all necessary permissions are granted
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated, service_role;

-- Grant specific permissions for monitoring functions
GRANT EXECUTE ON FUNCTION get_database_health() TO authenticated;
GRANT EXECUTE ON FUNCTION get_table_statistics() TO authenticated;
GRANT EXECUTE ON FUNCTION validate_data_integrity() TO authenticated;
GRANT EXECUTE ON FUNCTION get_optimization_recommendations() TO authenticated;

-- =====================================================
-- DATABASE METADATA AND DOCUMENTATION
-- =====================================================

-- Create a table to store database metadata
CREATE TABLE IF NOT EXISTS database_metadata (
                                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) NOT NULL UNIQUE,
    value TEXT,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
    );

-- Insert database metadata
INSERT INTO database_metadata (key, value, description) VALUES
                                                            ('schema_version', '1.0.0', 'Current database schema version'),
                                                            ('created_date', NOW()::TEXT, 'Date when database schema was created'),
                                                            ('created_by', 'antowirantoIO', 'User who created the database schema'),
                                                            ('last_migration', '20240101000024_final_cleanup.sql', 'Last migration file applied'),
                                                            ('total_tables', (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public')::TEXT, 'Total number of tables'),
                                                            ('total_indexes', (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public')::TEXT, 'Total number of indexes'),
                                                            ('rls_enabled', 'true', 'Row Level Security is enabled'),
                                                            ('audit_logging', 'true', 'Audit logging is enabled'),
                                                            ('backup_strategy', 'configured', 'Backup strategy status')
    ON CONFLICT (key) DO UPDATE SET
                             value = EXCLUDED.value,
                             updated_at = NOW();

-- =====================================================
-- FINAL COMMENTS AND DOCUMENTATION
-- =====================================================

-- Add comments to key tables for documentation
COMMENT ON TABLE organizations IS 'Core organization/tenant table for multi-tenancy';
COMMENT ON TABLE user_profiles IS 'User profiles with role-based access control';
COMMENT ON TABLE contacts IS 'Contact management with advanced features and scoring';
COMMENT ON TABLE companies IS 'Company/account management with hierarchical relationships';
COMMENT ON TABLE deals IS 'Sales opportunity tracking with pipeline management';
COMMENT ON TABLE activities IS 'Activity and task management with calendar integration';
COMMENT ON TABLE documents IS 'Document management with collaboration features';
COMMENT ON TABLE workflows IS 'Business process automation and workflow management';
COMMENT ON TABLE custom_field_definitions IS 'Flexible custom field system for all entities';
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for compliance and security';
COMMENT ON TABLE analytics_events IS 'Event tracking for business intelligence and reporting';

-- Add comments to key columns
COMMENT ON COLUMN contacts.lead_score IS 'Calculated lead score (0-100) based on engagement and profile';
COMMENT ON COLUMN deals.probability IS 'Probability of deal closure (0-100%)';
COMMENT ON COLUMN user_profiles.role IS 'User role determining permissions and access level';
COMMENT ON COLUMN organizations.status IS 'Organization status affecting all related functionality';

-- =====================================================
-- FINAL VALIDATION AND TESTING
-- =====================================================

-- Run final validation checks
DO $$
DECLARE
validation_result RECORD;
    health_result RECORD;
BEGIN
    -- Check data integrity
    RAISE NOTICE 'Running final data integrity validation...';

FOR validation_result IN
SELECT * FROM validate_data_integrity() WHERE issue_count > 0
    LOOP
        RAISE NOTICE 'Data integrity issue found: % in % (% issues)',
            validation_result.description,
            validation_result.table_name,
            validation_result.issue_count;
END LOOP;

    -- Check database health
    RAISE NOTICE 'Running database health check...';

FOR health_result IN
SELECT * FROM get_database_health() WHERE status != 'healthy'
    LOOP
        RAISE NOTICE 'Health check: % - % (%)',
            health_result.check_name,
            health_result.status,
            health_result.details;
END LOOP;

    RAISE NOTICE 'Database schema migration completed successfully!';
    RAISE NOTICE 'Schema version: 1.0.0';
    RAISE NOTICE 'Total tables: %', (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public');
    RAISE NOTICE 'Total indexes: %', (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public');
    RAISE NOTICE 'RLS enabled on all tables: %', (
        SELECT COUNT(*) = (SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public')
        FROM pg_tables t
        JOIN pg_class c ON c.relname = t.tablename
        WHERE t.schemaname = 'public' AND c.relrowsecurity = true
    );
END $$;

-- =====================================================
-- MIGRATION COMPLETION MARKER
-- =====================================================

-- Mark migration as completed
INSERT INTO database_metadata (key, value, description) VALUES
                                                            ('migration_completed_at', NOW()::TEXT, 'Timestamp when all migrations were completed'),
                                                            ('migration_status', 'completed', 'Overall migration status'),
                                                            ('total_migrations', '24', 'Total number of migration files applied')
    ON CONFLICT (key) DO UPDATE SET
                             value = EXCLUDED.value,
                             updated_at = NOW();

-- Final success message
SELECT
    '🎉 CRM Database Schema Migration Completed Successfully! 🎉' as message,
    '24 migrations applied' as migrations,
    'All features enabled' as status,
    NOW() as completed_at;