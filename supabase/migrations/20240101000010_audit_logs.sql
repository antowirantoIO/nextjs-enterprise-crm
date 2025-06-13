-- =====================================================
-- AUDIT LOGS MIGRATION
-- Comprehensive audit logging and compliance tracking
-- Created: 2025-06-13 20:10:08 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- AUDIT LOG ENHANCEMENTS
-- =====================================================

-- Audit log categories table
CREATE TABLE audit_log_categories (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Category details
                                      name VARCHAR(100) NOT NULL UNIQUE,
                                      description TEXT,
                                      severity VARCHAR(20) DEFAULT 'medium', -- low, medium, high, critical

    -- Retention settings
                                      retention_days INTEGER DEFAULT 2555, -- ~7 years default

    -- Compliance flags
                                      is_compliance_required BOOLEAN DEFAULT FALSE,
                                      compliance_frameworks TEXT[], -- SOX, GDPR, HIPAA, etc.

    -- Settings
                                      is_active BOOLEAN DEFAULT TRUE,

                                      created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enhanced audit logs table (replacing the basic one from initial schema)
DROP TABLE IF EXISTS audit_logs;
CREATE TABLE audit_logs (
                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                            organization_id UUID REFERENCES organizations(id),
                            category_id UUID REFERENCES audit_log_categories(id),
                            user_id UUID REFERENCES user_profiles(id),

    -- Action details
                            action VARCHAR(50) NOT NULL, -- create, update, delete, view, login, logout, export, etc.
                            resource_type VARCHAR(50) NOT NULL, -- contacts, companies, deals, etc.
                            resource_id UUID,
                            resource_name VARCHAR(255), -- Human-readable name of the resource

    -- Change tracking
                            old_values JSONB,
                            new_values JSONB,
                            changed_fields TEXT[],

    -- Request context
                            session_id VARCHAR(255),
                            ip_address INET,
                            user_agent TEXT,
                            request_id VARCHAR(100),
                            request_method VARCHAR(10), -- GET, POST, PUT, DELETE
                            request_url VARCHAR(1000),

    -- Geographic context
                            country VARCHAR(100),
                            city VARCHAR(100),
                            timezone VARCHAR(50),

    -- Device context
                            device_type VARCHAR(50), -- desktop, mobile, tablet
                            browser VARCHAR(100),
                            operating_system VARCHAR(100),

    -- Risk assessment
                            risk_score INTEGER DEFAULT 0, -- 0-100
                            risk_factors TEXT[], -- unusual_time, new_location, bulk_action, etc.

    -- Tags and categorization
                            tags TEXT[],
                            severity VARCHAR(20) DEFAULT 'medium',

    -- Success/failure
                            success BOOLEAN DEFAULT TRUE,
                            error_message TEXT,

    -- Additional metadata
                            metadata JSONB DEFAULT '{}',

    -- Timing
                            timestamp TIMESTAMPTZ DEFAULT NOW(),
                            duration_ms INTEGER, -- How long the action took

    -- Data classification
                            contains_pii BOOLEAN DEFAULT FALSE,
                            contains_sensitive_data BOOLEAN DEFAULT FALSE,
                            data_classification VARCHAR(50), -- public, internal, confidential, restricted

    -- Compliance tracking
                            compliance_reviewed BOOLEAN DEFAULT FALSE,
                            compliance_reviewed_by UUID REFERENCES user_profiles(id),
                            compliance_reviewed_at TIMESTAMPTZ,
                            compliance_notes TEXT
);

-- =====================================================
-- AUDIT TRAIL RELATIONSHIPS
-- =====================================================

-- Audit trail sessions table (grouping related actions)
CREATE TABLE audit_trail_sessions (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      organization_id UUID REFERENCES organizations(id),
                                      user_id UUID REFERENCES user_profiles(id),

    -- Session details
                                      session_token VARCHAR(255) NOT NULL UNIQUE,
                                      session_start TIMESTAMPTZ DEFAULT NOW(),
                                      session_end TIMESTAMPTZ,

    -- Session context
                                      login_method VARCHAR(50), -- password, sso, oauth, api_key
                                      ip_address INET,
                                      user_agent TEXT,

    -- Session statistics
                                      total_actions INTEGER DEFAULT 0,
                                      high_risk_actions INTEGER DEFAULT 0,

    -- Session outcome
                                      is_suspicious BOOLEAN DEFAULT FALSE,
                                      logout_reason VARCHAR(50), -- normal, timeout, forced, security

    -- Metadata
                                      metadata JSONB DEFAULT '{}'
);

-- Audit log relationships table (linking related audit entries)
CREATE TABLE audit_log_relationships (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         parent_log_id UUID NOT NULL REFERENCES audit_logs(id) ON DELETE CASCADE,
                                         child_log_id UUID NOT NULL REFERENCES audit_logs(id) ON DELETE CASCADE,

    -- Relationship type
                                         relationship_type VARCHAR(50) NOT NULL, -- caused_by, part_of, follows, triggers
                                         description TEXT,

                                         created_at TIMESTAMPTZ DEFAULT NOW(),

                                         UNIQUE(parent_log_id, child_log_id)
);

-- =====================================================
-- DATA RETENTION & ARCHIVAL
-- =====================================================

-- Audit log retention policies table
CREATE TABLE audit_log_retention_policies (
                                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                              organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,

    -- Policy details
                                              name VARCHAR(255) NOT NULL,
                                              description TEXT,

    -- Retention rules
                                              default_retention_days INTEGER DEFAULT 2555, -- ~7 years
                                              category_specific_rules JSONB, -- {category_id: retention_days}

    -- Legal hold settings
                                              legal_hold_enabled BOOLEAN DEFAULT FALSE,
                                              legal_hold_reason TEXT,
                                              legal_hold_contact VARCHAR(255),

    -- Archival settings
                                              archive_after_days INTEGER DEFAULT 365,
                                              archive_location VARCHAR(255), -- cold storage location

    -- Compliance requirements
                                              compliance_frameworks TEXT[],
                                              minimum_retention_days INTEGER DEFAULT 365,

    -- Policy status
                                              is_active BOOLEAN DEFAULT TRUE,
                                              effective_from DATE DEFAULT CURRENT_DATE,
                                              effective_until DATE,

    -- Metadata
                                              created_by UUID REFERENCES user_profiles(id),
                                              approved_by UUID REFERENCES user_profiles(id),
                                              created_at TIMESTAMPTZ DEFAULT NOW(),
                                              updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit log archives table (for long-term storage)
CREATE TABLE audit_log_archives (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID REFERENCES organizations(id),

    -- Archive details
                                    archive_name VARCHAR(255) NOT NULL,
                                    archive_path VARCHAR(1000), -- Path to archived data

    -- Archive period
                                    period_start DATE NOT NULL,
                                    period_end DATE NOT NULL,

    -- Archive statistics
                                    total_records INTEGER DEFAULT 0,
                                    compressed_size_bytes BIGINT,
                                    original_size_bytes BIGINT,

    -- Archive integrity
                                    checksum VARCHAR(255),
                                    encryption_key_id VARCHAR(255),

    -- Archive status
                                    status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    completed_at TIMESTAMPTZ,

                                    UNIQUE(organization_id, archive_name)
);

-- =====================================================
-- SECURITY MONITORING & ALERTS
-- =====================================================

-- Security events table (flagged audit events)
CREATE TABLE security_events (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 organization_id UUID REFERENCES organizations(id),
                                 audit_log_id UUID REFERENCES audit_logs(id) ON DELETE CASCADE,

    -- Event classification
                                 event_type VARCHAR(50) NOT NULL, -- suspicious_login, data_breach, privilege_escalation, etc.
                                 severity VARCHAR(20) DEFAULT 'medium', -- low, medium, high, critical

    -- Event details
                                 title VARCHAR(255) NOT NULL,
                                 description TEXT,

    -- Risk assessment
                                 risk_score INTEGER DEFAULT 0, -- 0-100
                                 threat_indicators TEXT[],

    -- Response tracking
                                 status VARCHAR(20) DEFAULT 'open', -- open, investigating, resolved, false_positive
                                 assigned_to UUID REFERENCES user_profiles(id),

    -- Investigation details
                                 investigation_notes TEXT,
                                 resolution_summary TEXT,

    -- External references
                                 external_ticket_id VARCHAR(255),

    -- Timing
                                 detected_at TIMESTAMPTZ DEFAULT NOW(),
                                 acknowledged_at TIMESTAMPTZ,
                                 resolved_at TIMESTAMPTZ,

    -- Metadata
                                 metadata JSONB DEFAULT '{}'
);

-- Security alert rules table
CREATE TABLE security_alert_rules (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,

    -- Rule details
                                      name VARCHAR(255) NOT NULL,
                                      description TEXT,

    -- Rule conditions
                                      conditions JSONB NOT NULL, -- Complex conditions for triggering alerts

    -- Alert settings
                                      severity VARCHAR(20) DEFAULT 'medium',
                                      event_type VARCHAR(50) NOT NULL,

    -- Notification settings
                                      notify_users UUID[], -- User IDs to notify
                                      notify_roles user_role[], -- Roles to notify
                                      notification_channels notification_channel[] DEFAULT '{in_app,email}',

    -- Rate limiting
                                      cooldown_minutes INTEGER DEFAULT 60, -- Prevent spam alerts
                                      max_alerts_per_hour INTEGER DEFAULT 10,

    -- Rule status
                                      is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                      created_by UUID REFERENCES user_profiles(id),
                                      created_at TIMESTAMPTZ DEFAULT NOW(),
                                      updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- COMPLIANCE & REPORTING
-- =====================================================

-- Compliance reports table
CREATE TABLE compliance_reports (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Report details
                                    name VARCHAR(255) NOT NULL,
                                    framework VARCHAR(50) NOT NULL, -- SOX, GDPR, HIPAA, SOC2, etc.
                                    report_type VARCHAR(50) NOT NULL, -- annual, quarterly, incident, custom

    -- Report period
                                    period_start DATE NOT NULL,
                                    period_end DATE NOT NULL,

    -- Report content
                                    summary TEXT,
                                    findings JSONB, -- Structured findings
                                    recommendations TEXT[],

    -- Report files
                                    report_file_path VARCHAR(1000),
                                    supporting_documents_paths TEXT[],

    -- Report status
                                    status VARCHAR(20) DEFAULT 'draft', -- draft, review, approved, submitted

    -- Approval workflow
                                    prepared_by UUID REFERENCES user_profiles(id),
                                    reviewed_by UUID REFERENCES user_profiles(id),
                                    approved_by UUID REFERENCES user_profiles(id),

    -- External submission
                                    submitted_to VARCHAR(255), -- Regulatory body or auditor
                                    submission_reference VARCHAR(255),
                                    submitted_at TIMESTAMPTZ,

    -- Metadata
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Compliance checkpoints table
CREATE TABLE compliance_checkpoints (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                        organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Checkpoint details
                                        name VARCHAR(255) NOT NULL,
                                        framework VARCHAR(50) NOT NULL,
                                        control_id VARCHAR(100), -- Control identifier from framework

    -- Checkpoint criteria
                                        description TEXT NOT NULL,
                                        requirements JSONB, -- Specific requirements to check

    -- Assessment
                                        last_assessment_date DATE,
                                        last_assessment_result VARCHAR(20), -- compliant, non_compliant, partially_compliant, not_assessed
                                        last_assessment_score INTEGER, -- 0-100
                                        last_assessment_notes TEXT,

    -- Remediation
                                        remediation_required BOOLEAN DEFAULT FALSE,
                                        remediation_plan TEXT,
                                        remediation_due_date DATE,
                                        remediation_owner UUID REFERENCES user_profiles(id),

    -- Schedule
                                        assessment_frequency VARCHAR(20) DEFAULT 'annually', -- daily, weekly, monthly, quarterly, annually
                                        next_assessment_due DATE,

    -- Status
                                        is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                        created_by UUID REFERENCES user_profiles(id),
                                        created_at TIMESTAMPTZ DEFAULT NOW(),
                                        updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- FUNCTIONS FOR AUDIT LOGGING
-- =====================================================

-- Enhanced function to create audit log entry
CREATE OR REPLACE FUNCTION create_audit_log(
    p_action VARCHAR(50),
    p_resource_type VARCHAR(50),
    p_resource_id UUID DEFAULT NULL,
    p_resource_name VARCHAR(255) DEFAULT NULL,
    p_old_values JSONB DEFAULT NULL,
    p_new_values JSONB DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}',
    p_session_id VARCHAR(255) DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
audit_id UUID;
    user_org_id UUID;
    category_id UUID;
    risk_score INTEGER := 0;
    risk_factors TEXT[] := '{}';
    session_record RECORD;
BEGIN
    -- Get current user's organization
SELECT organization_id INTO user_org_id
FROM user_profiles
WHERE id = auth.uid();

-- Get appropriate category
SELECT id INTO category_id
FROM audit_log_categories
WHERE name = p_resource_type
   OR name = 'general';

-- Calculate risk score based on various factors
-- Time-based risk (outside business hours)
IF EXTRACT(hour FROM NOW()) < 8 OR EXTRACT(hour FROM NOW()) > 18 THEN
        risk_score := risk_score + 10;
        risk_factors := risk_factors || 'unusual_time';
END IF;

    -- Action-based risk
    IF p_action IN ('delete', 'export', 'bulk_update') THEN
        risk_score := risk_score + 20;
        risk_factors := risk_factors || 'high_risk_action';
END IF;

    -- Bulk operation detection
    IF p_metadata ? 'batch_size' AND (p_metadata->>'batch_size')::INTEGER > 10 THEN
        risk_score := risk_score + 15;
        risk_factors := risk_factors || 'bulk_operation';
END IF;

    -- Check for session context
    IF p_session_id IS NOT NULL THEN
SELECT * INTO session_record
FROM audit_trail_sessions
WHERE session_token = p_session_id;

IF NOT FOUND THEN
            -- Create new session if it doesn't exist
            INSERT INTO audit_trail_sessions (
                organization_id,
                user_id,
                session_token,
                ip_address,
                user_agent
            ) VALUES (
                user_org_id,
                auth.uid(),
                p_session_id,
                p_ip_address,
                p_user_agent
            );
END IF;
END IF;

    -- Create audit log entry
INSERT INTO audit_logs (
    organization_id,
    category_id,
    user_id,
    action,
    resource_type,
    resource_id,
    resource_name,
    old_values,
    new_values,
    changed_fields,
    session_id,
    ip_address,
    user_agent,
    risk_score,
    risk_factors,
    metadata,
    contains_pii,
    contains_sensitive_data
) VALUES (
             user_org_id,
             category_id,
             auth.uid(),
             p_action,
             p_resource_type,
             p_resource_id,
             p_resource_name,
             p_old_values,
             p_new_values,
             CASE
                 WHEN p_old_values IS NOT NULL AND p_new_values IS NOT NULL
                     THEN (SELECT array_agg(key) FROM jsonb_each(p_new_values) WHERE key IN (SELECT jsonb_object_keys(p_old_values)))
    ELSE NULL
END,
        p_session_id,
        p_ip_address,
        p_user_agent,
        risk_score,
        risk_factors,
        p_metadata,
        -- Simple PII detection (can be enhanced)
        (p_new_values::text ~* '(email|phone|ssn|credit.card)' OR p_old_values::text ~* '(email|phone|ssn|credit.card)'),
        (p_metadata ? 'sensitive' AND (p_metadata->>'sensitive')::BOOLEAN)
    ) RETURNING id INTO audit_id;

    -- Update session statistics
    IF p_session_id IS NOT NULL THEN
UPDATE audit_trail_sessions
SET
    total_actions = total_actions + 1,
    high_risk_actions = high_risk_actions + CASE WHEN risk_score > 50 THEN 1 ELSE 0 END
WHERE session_token = p_session_id;
END IF;

    -- Check security alert rules
    PERFORM check_security_alert_rules(audit_id);

RETURN audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check security alert rules
CREATE OR REPLACE FUNCTION check_security_alert_rules(audit_log_uuid UUID)
RETURNS VOID AS $$
DECLARE
audit_record RECORD;
    rule_record RECORD;
    should_alert BOOLEAN;
BEGIN
    -- Get the audit log record
SELECT * INTO audit_record FROM audit_logs WHERE id = audit_log_uuid;

-- Check each active security rule
FOR rule_record IN
SELECT * FROM security_alert_rules
WHERE organization_id = audit_record.organization_id
  AND is_active = TRUE
    LOOP
        should_alert := FALSE;

-- Simple rule evaluation (can be enhanced with proper rule engine)
-- Check risk score threshold
IF rule_record.conditions ? 'min_risk_score' THEN
            IF audit_record.risk_score >= (rule_record.conditions->>'min_risk_score')::INTEGER THEN
                should_alert := TRUE;
END IF;
END IF;

        -- Check specific actions
        IF rule_record.conditions ? 'actions' THEN
            IF audit_record.action = ANY(ARRAY(SELECT jsonb_array_elements_text(rule_record.conditions->'actions'))) THEN
                should_alert := TRUE;
END IF;
END IF;

        -- Check time-based rules (after hours access)
        IF rule_record.conditions ? 'after_hours' AND (rule_record.conditions->>'after_hours')::BOOLEAN THEN
            IF EXTRACT(hour FROM audit_record.timestamp) < 8 OR EXTRACT(hour FROM audit_record.timestamp) > 18 THEN
                should_alert := TRUE;
END IF;
END IF;

        -- Create security event if rule matches
        IF should_alert THEN
            -- Check cooldown to prevent spam
            IF NOT EXISTS (
                SELECT 1 FROM security_events
                WHERE organization_id = audit_record.organization_id
                AND event_type = rule_record.event_type
                AND detected_at > NOW() - INTERVAL '1 minute' * rule_record.cooldown_minutes
            ) THEN
                INSERT INTO security_events (
                    organization_id,
                    audit_log_id,
                    event_type,
                    severity,
                    title,
                    description,
                    risk_score
                ) VALUES (
                    audit_record.organization_id,
                    audit_log_uuid,
                    rule_record.event_type,
                    rule_record.severity,
                    rule_record.name || ' - ' || audit_record.action || ' on ' || audit_record.resource_type,
                    'Security rule triggered: ' || rule_record.description,
                    audit_record.risk_score
                );

                -- Send notifications (would integrate with notification system)
                PERFORM process_notification_rules(
                    'security_alert',
                    jsonb_build_object(
                        'organization_id', audit_record.organization_id,
                        'event_type', rule_record.event_type,
                        'severity', rule_record.severity,
                        'audit_log_id', audit_log_uuid
                    )
                );
END IF;
END IF;
END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to archive old audit logs
CREATE OR REPLACE FUNCTION archive_audit_logs(
    org_uuid UUID,
    archive_before_date DATE
)
RETURNS UUID AS $$
DECLARE
archive_id UUID;
    archived_count INTEGER;
    archive_name VARCHAR(255);
BEGIN
    archive_name := 'audit_logs_' || org_uuid || '_' || archive_before_date;

    -- Create archive record
INSERT INTO audit_log_archives (
    organization_id,
    archive_name,
    period_start,
    period_end,
    status
) VALUES (
             org_uuid,
             archive_name,
             '2000-01-01'::DATE, -- From beginning
             archive_before_date,
             'processing'
         ) RETURNING id INTO archive_id;

-- Count records to be archived
SELECT COUNT(*) INTO archived_count
FROM audit_logs
WHERE organization_id = org_uuid
  AND timestamp::DATE < archive_before_date;

-- In a real implementation, you would:
-- 1. Export the data to cold storage (S3, etc.)
-- 2. Compress and encrypt the data
-- 3. Generate checksums for integrity
-- 4. Delete the original records

-- For now, we'll just mark as completed
UPDATE audit_log_archives
SET
    status = 'completed',
    total_records = archived_count,
    completed_at = NOW()
WHERE id = archive_id;

RETURN archive_id;
END;
$$ LANGUAGE plpgsql;

-- Function to generate compliance report
CREATE OR REPLACE FUNCTION generate_compliance_report(
    org_uuid UUID,
    framework_param VARCHAR(50),
    period_start_param DATE,
    period_end_param DATE
)
RETURNS UUID AS $$
DECLARE
report_id UUID;
    total_logs INTEGER;
    high_risk_events INTEGER;
    findings JSONB := '{}';
BEGIN
    -- Count total audit logs in period
SELECT COUNT(*) INTO total_logs
FROM audit_logs
WHERE organization_id = org_uuid
  AND timestamp::DATE BETWEEN period_start_param AND period_end_param;

-- Count high-risk events
SELECT COUNT(*) INTO high_risk_events
FROM audit_logs
WHERE organization_id = org_uuid
  AND timestamp::DATE BETWEEN period_start_param AND period_end_param
  AND risk_score > 70;

-- Build findings object
findings := jsonb_build_object(
        'total_audit_events', total_logs,
        'high_risk_events', high_risk_events,
        'compliance_score', CASE
            WHEN high_risk_events = 0 THEN 100
            ELSE GREATEST(0, 100 - (high_risk_events * 100 / NULLIF(total_logs, 0)))
        END
    );

    -- Create compliance report
INSERT INTO compliance_reports (
    organization_id,
    name,
    framework,
    report_type,
    period_start,
    period_end,
    summary,
    findings,
    status,
    prepared_by
) VALUES (
             org_uuid,
             framework_param || ' Compliance Report - ' || period_start_param || ' to ' || period_end_param,
             framework_param,
             'custom',
             period_start_param,
             period_end_param,
             'Automated compliance report covering audit events and security monitoring.',
             findings,
             'draft',
             auth.uid()
         ) RETURNING id INTO report_id;

RETURN report_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Enhanced audit logs indexes
CREATE INDEX idx_audit_logs_organization_id ON audit_logs(organization_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_session_id ON audit_logs(session_id);
CREATE INDEX idx_audit_logs_ip_address ON audit_logs(ip_address);
CREATE INDEX idx_audit_logs_risk_score ON audit_logs(risk_score);
CREATE INDEX idx_audit_logs_compliance ON audit_logs(contains_pii, contains_sensitive_data);

-- Composite indexes for common queries
CREATE INDEX idx_audit_logs_org_timestamp ON audit_logs(organization_id, timestamp);
CREATE INDEX idx_audit_logs_user_action ON audit_logs(user_id, action);
CREATE INDEX idx_audit_logs_resource_timestamp ON audit_logs(resource_type, resource_id, timestamp);

-- Security events indexes
CREATE INDEX idx_security_events_organization_id ON security_events(organization_id);
CREATE INDEX idx_security_events_severity ON security_events(severity);
CREATE INDEX idx_security_events_status ON security_events(status);
CREATE INDEX idx_security_events_detected_at ON security_events(detected_at);

-- Compliance indexes
CREATE INDEX idx_compliance_reports_organization_id ON compliance_reports(organization_id);
CREATE INDEX idx_compliance_reports_framework ON compliance_reports(framework);
CREATE INDEX idx_compliance_reports_period ON compliance_reports(period_start, period_end);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_audit_log_retention_policies_updated_at BEFORE UPDATE ON audit_log_retention_policies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_security_alert_rules_updated_at BEFORE UPDATE ON security_alert_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_compliance_reports_updated_at BEFORE UPDATE ON compliance_reports FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_compliance_checkpoints_updated_at BEFORE UPDATE ON compliance_checkpoints FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();