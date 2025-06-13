-- =====================================================
-- NOTIFICATIONS SYSTEM MIGRATION
-- Advanced notification system with channels, preferences, and templates
-- Created: 2024-01-01 00:00:09 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- NOTIFICATION TEMPLATES & CATEGORIES
-- =====================================================

-- Notification categories table
CREATE TABLE notification_categories (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,

    -- Category details
                                         name VARCHAR(255) NOT NULL,
                                         slug VARCHAR(100) NOT NULL,
                                         description TEXT,
                                         icon VARCHAR(50),
                                         color VARCHAR(7), -- Hex color code

    -- Default settings
                                         default_enabled BOOLEAN DEFAULT TRUE,
                                         default_channels notification_channel[] DEFAULT '{in_app}',

    -- Priority
                                         priority INTEGER DEFAULT 0, -- Higher numbers = higher priority

    -- Settings
                                         is_system_category BOOLEAN DEFAULT FALSE,
                                         is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                         created_at TIMESTAMPTZ DEFAULT NOW(),
                                         updated_at TIMESTAMPTZ DEFAULT NOW(),

                                         UNIQUE(organization_id, slug),
                                         UNIQUE(slug) WHERE organization_id IS NULL -- For system categories
);

-- Notification templates table
CREATE TABLE notification_templates (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                        organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
                                        category_id UUID REFERENCES notification_categories(id),

    -- Template identification
                                        template_key VARCHAR(100) NOT NULL, -- Unique key for code reference
                                        name VARCHAR(255) NOT NULL,
                                        description TEXT,

    -- Template content
                                        title_template VARCHAR(500) NOT NULL,
                                        message_template TEXT NOT NULL,
                                        html_template TEXT, -- For rich notifications

    -- Email specific
                                        email_subject_template VARCHAR(500),
                                        email_html_template TEXT,
                                        email_text_template TEXT,

    -- SMS specific
                                        sms_template TEXT,

    -- Push notification specific
                                        push_title_template VARCHAR(255),
                                        push_body_template VARCHAR(500),

    -- Template variables
                                        available_variables JSONB DEFAULT '{}', -- {variable_name: {type, description}}

    -- Settings
                                        is_system_template BOOLEAN DEFAULT FALSE,
                                        is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                        created_by UUID REFERENCES user_profiles(id),
                                        created_at TIMESTAMPTZ DEFAULT NOW(),
                                        updated_at TIMESTAMPTZ DEFAULT NOW(),

                                        UNIQUE(organization_id, template_key),
                                        UNIQUE(template_key) WHERE organization_id IS NULL -- For system templates
);

-- =====================================================
-- NOTIFICATION DELIVERY & TRACKING
-- =====================================================

-- Notification deliveries table (tracking delivery attempts)
CREATE TABLE notification_deliveries (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,

    -- Delivery details
                                         channel notification_channel NOT NULL,
                                         delivery_status VARCHAR(20) DEFAULT 'pending', -- pending, sent, delivered, failed, bounced

    -- Delivery metadata
                                         external_id VARCHAR(255), -- ID from external service (email service, SMS provider, etc.)
                                         provider VARCHAR(50), -- resend, twilio, etc.

    -- Delivery attempts
                                         attempt_count INTEGER DEFAULT 0,
                                         max_attempts INTEGER DEFAULT 3,
                                         next_retry_at TIMESTAMPTZ,

    -- Response tracking
                                         response_code VARCHAR(20),
                                         response_message TEXT,

    -- Engagement tracking
                                         opened_at TIMESTAMPTZ,
                                         clicked_at TIMESTAMPTZ,

    -- Error handling
                                         error_details JSONB,

    -- Timing
                                         sent_at TIMESTAMPTZ,
                                         delivered_at TIMESTAMPTZ,
                                         failed_at TIMESTAMPTZ,

    -- Metadata
                                         created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- NOTIFICATION RULES & AUTOMATION
-- =====================================================

-- Notification rules table (automated notification triggers)
CREATE TABLE notification_rules (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                    category_id UUID REFERENCES notification_categories(id),
                                    template_id UUID REFERENCES notification_templates(id),

    -- Rule details
                                    name VARCHAR(255) NOT NULL,
                                    description TEXT,

    -- Trigger conditions
                                    trigger_event VARCHAR(100) NOT NULL, -- deal_won, contact_created, activity_overdue, etc.
                                    trigger_conditions JSONB, -- Additional conditions to check

    -- Target audience
                                    target_type VARCHAR(50) NOT NULL, -- specific_users, role_based, dynamic, everyone
                                    target_users UUID[], -- Specific user IDs
                                    target_roles user_role[], -- User roles to notify
                                    target_conditions JSONB, -- Dynamic targeting conditions

    -- Delivery settings
                                    delivery_channels notification_channel[] DEFAULT '{in_app}',
                                    delivery_delay_minutes INTEGER DEFAULT 0,

    -- Frequency control
                                    max_frequency_per_hour INTEGER,
                                    max_frequency_per_day INTEGER,

    -- Rule settings
                                    is_active BOOLEAN DEFAULT TRUE,
                                    priority INTEGER DEFAULT 0,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notification rule executions table (tracking rule firing)
CREATE TABLE notification_rule_executions (
                                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                              rule_id UUID NOT NULL REFERENCES notification_rules(id) ON DELETE CASCADE,

    -- Execution details
                                              trigger_data JSONB, -- Data that triggered the rule
                                              execution_status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed

    -- Results
                                              notifications_created INTEGER DEFAULT 0,
                                              target_users_count INTEGER DEFAULT 0,

    -- Error handling
                                              error_message TEXT,

    -- Timing
                                              executed_at TIMESTAMPTZ DEFAULT NOW(),
                                              completed_at TIMESTAMPTZ
);

-- =====================================================
-- NOTIFICATION GROUPS & BATCHING
-- =====================================================

-- Notification groups table (for batching related notifications)
CREATE TABLE notification_groups (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Group details
                                     group_key VARCHAR(255) NOT NULL, -- Key for grouping (e.g., "daily_digest_2024-01-01")
                                     group_type VARCHAR(50) NOT NULL, -- digest, batch, campaign

    -- Group metadata
                                     title VARCHAR(255),
                                     description TEXT,

    -- Delivery settings
                                     delivery_scheduled_at TIMESTAMPTZ,
                                     delivery_status VARCHAR(20) DEFAULT 'pending', -- pending, processing, sent, failed

    -- Statistics
                                     total_notifications INTEGER DEFAULT 0,
                                     total_recipients INTEGER DEFAULT 0,

    -- Metadata
                                     created_at TIMESTAMPTZ DEFAULT NOW(),

                                     UNIQUE(organization_id, group_key)
);

-- Notification group members table
CREATE TABLE notification_group_members (
                                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                            group_id UUID NOT NULL REFERENCES notification_groups(id) ON DELETE CASCADE,
                                            notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,

    -- Member details
                                            position INTEGER DEFAULT 0, -- Order within group

                                            added_at TIMESTAMPTZ DEFAULT NOW(),

                                            UNIQUE(group_id, notification_id)
);

-- =====================================================
-- NOTIFICATION DIGEST & SUMMARIZATION
-- =====================================================

-- Notification digests table
CREATE TABLE notification_digests (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Digest details
                                      digest_type VARCHAR(50) NOT NULL, -- daily, weekly, monthly
                                      digest_date DATE NOT NULL,

    -- Content
                                      summary TEXT,
                                      notifications_count INTEGER DEFAULT 0,
                                      high_priority_count INTEGER DEFAULT 0,

    -- Delivery
                                      is_sent BOOLEAN DEFAULT FALSE,
                                      sent_at TIMESTAMPTZ,
                                      delivery_id UUID REFERENCES notification_deliveries(id),

    -- Metadata
                                      created_at TIMESTAMPTZ DEFAULT NOW(),

                                      UNIQUE(user_id, digest_type, digest_date)
);

-- =====================================================
-- NOTIFICATION CHANNELS & PROVIDERS
-- =====================================================

-- Notification channel providers table
CREATE TABLE notification_channel_providers (
                                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                                organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,

    -- Provider details
                                                channel notification_channel NOT NULL,
                                                provider_name VARCHAR(50) NOT NULL, -- resend, twilio, slack, etc.
                                                provider_config JSONB NOT NULL, -- Provider-specific configuration

    -- Status
                                                is_active BOOLEAN DEFAULT TRUE,
                                                is_default BOOLEAN DEFAULT FALSE,

    -- Rate limiting
                                                rate_limit_per_minute INTEGER,
                                                rate_limit_per_hour INTEGER,
                                                rate_limit_per_day INTEGER,

    -- Usage tracking
                                                messages_sent_today INTEGER DEFAULT 0,
                                                last_message_sent_at TIMESTAMPTZ,

    -- Health monitoring
                                                last_health_check_at TIMESTAMPTZ,
                                                health_status VARCHAR(20) DEFAULT 'unknown', -- healthy, degraded, failed, unknown

    -- Metadata
                                                created_by UUID REFERENCES user_profiles(id),
                                                created_at TIMESTAMPTZ DEFAULT NOW(),
                                                updated_at TIMESTAMPTZ DEFAULT NOW(),

                                                UNIQUE(organization_id, channel, provider_name)
);

-- =====================================================
-- USER NOTIFICATION HISTORY & ANALYTICS
-- =====================================================

-- User notification analytics table
CREATE TABLE user_notification_analytics (
                                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                             user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Analytics period
                                             date DATE NOT NULL,

    -- Delivery metrics
                                             notifications_received INTEGER DEFAULT 0,
                                             notifications_read INTEGER DEFAULT 0,
                                             notifications_clicked INTEGER DEFAULT 0,

    -- Channel breakdown
                                             in_app_received INTEGER DEFAULT 0,
                                             in_app_read INTEGER DEFAULT 0,
                                             email_received INTEGER DEFAULT 0,
                                             email_opened INTEGER DEFAULT 0,
                                             email_clicked INTEGER DEFAULT 0,
                                             sms_received INTEGER DEFAULT 0,
                                             push_received INTEGER DEFAULT 0,
                                             push_opened INTEGER DEFAULT 0,

    -- Engagement metrics
                                             average_read_time_seconds INTEGER DEFAULT 0,

    -- Metadata
                                             calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                             UNIQUE(user_id, date)
);

-- =====================================================
-- FUNCTIONS FOR NOTIFICATIONS
-- =====================================================

-- Function to create notification from template
CREATE OR REPLACE FUNCTION create_notification_from_template(
    template_key_param VARCHAR(100),
    recipient_id UUID,
    variable_values JSONB DEFAULT '{}',
    org_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
template_record RECORD;
    notification_id UUID;
    rendered_title VARCHAR(500);
    rendered_message TEXT;
    category_record RECORD;
BEGIN
    -- Get template
SELECT * INTO template_record
FROM notification_templates
WHERE template_key = template_key_param
  AND (organization_id = org_id OR organization_id IS NULL)
  AND is_active = TRUE
ORDER BY organization_id NULLS LAST -- Prefer org-specific templates
    LIMIT 1;

IF NOT FOUND THEN
        RAISE EXCEPTION 'Notification template not found: %', template_key_param;
END IF;

    -- Get category info
SELECT * INTO category_record
FROM notification_categories
WHERE id = template_record.category_id;

-- Simple template variable replacement (can be enhanced with proper templating engine)
rendered_title := template_record.title_template;
    rendered_message := template_record.message_template;

    -- Replace variables (basic implementation)
FOR key IN SELECT jsonb_object_keys(variable_values) LOOP
               rendered_title := replace(rendered_title, '{{' || key || '}}', variable_values->>key);
rendered_message := replace(rendered_message, '{{' || key || '}}', variable_values->>key);
END LOOP;

    -- Create notification
INSERT INTO notifications (
    organization_id,
    recipient_id,
    type,
    title,
    message,
    channels,
    metadata
) VALUES (
             COALESCE(org_id, auth.user_organization_id()),
             recipient_id,
             COALESCE(category_record.name, 'info')::notification_type,
             rendered_title,
             rendered_message,
             COALESCE(category_record.default_channels, '{in_app}'),
             jsonb_build_object(
                     'template_key', template_key_param,
                     'template_id', template_record.id,
                     'variables', variable_values
             )
         ) RETURNING id INTO notification_id;

RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process notification rules
CREATE OR REPLACE FUNCTION process_notification_rules(
    event_name VARCHAR(100),
    event_data JSONB DEFAULT '{}'
)
RETURNS INTEGER AS $$
DECLARE
rule_record RECORD;
    target_user UUID;
    notifications_created INTEGER := 0;
    execution_id UUID;
    user_org_id UUID;
BEGIN
    -- Get the organization from event data or current user
    user_org_id := COALESCE((event_data->>'organization_id')::UUID, auth.user_organization_id());

    -- Process each matching rule
FOR rule_record IN
SELECT * FROM notification_rules
WHERE trigger_event = event_name
  AND organization_id = user_org_id
  AND is_active = TRUE
ORDER BY priority DESC
    LOOP
-- Create execution record
INSERT INTO notification_rule_executions (
    rule_id,
    trigger_data,
    execution_status
) VALUES (
    rule_record.id,
    event_data,
    'processing'
    ) RETURNING id INTO execution_id;

-- Determine target users based on rule configuration
CASE rule_record.target_type
            WHEN 'specific_users' THEN
                -- Send to specific users
                FOREACH target_user IN ARRAY rule_record.target_users
                LOOP
                    PERFORM create_notification_from_template(
                        (SELECT template_key FROM notification_templates WHERE id = rule_record.template_id),
                        target_user,
                        event_data,
                        user_org_id
                    );
                    notifications_created := notifications_created + 1;
END LOOP;

WHEN 'role_based' THEN
                -- Send to users with specific roles
                FOR target_user IN
SELECT id FROM user_profiles
WHERE organization_id = user_org_id
  AND role = ANY(rule_record.target_roles)
  AND status = 'active'
    LOOP
                    PERFORM create_notification_from_template(
                        (SELECT template_key FROM notification_templates WHERE id = rule_record.template_id),
                        target_user,
                        event_data,
                        user_org_id
                    );
notifications_created := notifications_created + 1;
END LOOP;

WHEN 'everyone' THEN
                -- Send to all active users in organization
                FOR target_user IN
SELECT id FROM user_profiles
WHERE organization_id = user_org_id
  AND status = 'active'
    LOOP
                    PERFORM create_notification_from_template(
                        (SELECT template_key FROM notification_templates WHERE id = rule_record.template_id),
                        target_user,
                        event_data,
                        user_org_id
                    );
notifications_created := notifications_created + 1;
END LOOP;
END CASE;

        -- Update execution record
UPDATE notification_rule_executions
SET
    execution_status = 'completed',
    notifications_created = notifications_created,
    completed_at = NOW()
WHERE id = execution_id;
END LOOP;

RETURN notifications_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update notification analytics
CREATE OR REPLACE FUNCTION update_notification_analytics()
RETURNS TRIGGER AS $$
DECLARE
analytics_date DATE;
BEGIN
    analytics_date := COALESCE(NEW.read_at, NEW.created_at)::DATE;

    -- Update user analytics
INSERT INTO user_notification_analytics (
    user_id,
    date,
    notifications_received,
    notifications_read
) VALUES (
             NEW.recipient_id,
             analytics_date,
             CASE WHEN TG_OP = 'INSERT' THEN 1 ELSE 0 END,
             CASE WHEN NEW.is_read AND OLD.is_read IS DISTINCT FROM NEW.is_read THEN 1 ELSE 0 END
         )
    ON CONFLICT (user_id, date)
    DO UPDATE SET
    notifications_received = user_notification_analytics.notifications_received + EXCLUDED.notifications_received,
               notifications_read = user_notification_analytics.notifications_read + EXCLUDED.notifications_read,
               calculated_at = NOW();

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating analytics
CREATE TRIGGER update_notification_analytics_trigger
    AFTER INSERT OR UPDATE ON notifications
                        FOR EACH ROW
                        EXECUTE FUNCTION update_notification_analytics();

-- Function to clean up old notifications
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
deleted_count INTEGER;
    retention_days INTEGER := 90; -- Default retention period
BEGIN
    -- Delete old notifications (keeping audit trail)
DELETE FROM notifications
WHERE created_at < NOW() - INTERVAL '1 day' * retention_days
  AND is_read = TRUE;

GET DIAGNOSTICS deleted_count = ROW_COUNT;

-- Clean up old deliveries
DELETE FROM notification_deliveries
WHERE created_at < NOW() - INTERVAL '1 day' * retention_days;

-- Clean up old analytics (keep aggregated data)
DELETE FROM user_notification_analytics
WHERE date < CURRENT_DATE - INTERVAL '1 year';

RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Notification categories indexes
CREATE INDEX idx_notification_categories_organization_id ON notification_categories(organization_id);
CREATE INDEX idx_notification_categories_slug ON notification_categories(slug);

-- Notification templates indexes
CREATE INDEX idx_notification_templates_organization_id ON notification_templates(organization_id);
CREATE INDEX idx_notification_templates_template_key ON notification_templates(template_key);
CREATE INDEX idx_notification_templates_category_id ON notification_templates(category_id);

-- Notification deliveries indexes
CREATE INDEX idx_notification_deliveries_notification_id ON notification_deliveries(notification_id);
CREATE INDEX idx_notification_deliveries_channel ON notification_deliveries(channel);
CREATE INDEX idx_notification_deliveries_status ON notification_deliveries(delivery_status);
CREATE INDEX idx_notification_deliveries_sent_at ON notification_deliveries(sent_at);

-- Notification rules indexes
CREATE INDEX idx_notification_rules_organization_id ON notification_rules(organization_id);
CREATE INDEX idx_notification_rules_trigger_event ON notification_rules(trigger_event);
CREATE INDEX idx_notification_rules_active ON notification_rules(is_active);

-- Notification groups indexes
CREATE INDEX idx_notification_groups_organization_id ON notification_groups(organization_id);
CREATE INDEX idx_notification_groups_group_key ON notification_groups(group_key);
CREATE INDEX idx_notification_groups_delivery_scheduled ON notification_groups(delivery_scheduled_at);

-- User notification analytics indexes
CREATE INDEX idx_user_notification_analytics_user_id ON user_notification_analytics(user_id);
CREATE INDEX idx_user_notification_analytics_date ON user_notification_analytics(date);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_notification_categories_updated_at BEFORE UPDATE ON notification_categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_notification_templates_updated_at BEFORE UPDATE ON notification_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_notification_rules_updated_at BEFORE UPDATE ON notification_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_notification_channel_providers_updated_at BEFORE UPDATE ON notification_channel_providers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();