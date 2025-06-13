-- =====================================================
-- INTEGRATIONS & WEBHOOKS MIGRATION
-- Comprehensive third-party integrations and webhook management
-- Created: 2025-06-13 20:13:38 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- INTEGRATION ENHANCEMENTS
-- =====================================================

-- Integration categories table
CREATE TABLE integration_categories (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Category details
                                        name VARCHAR(100) NOT NULL UNIQUE,
                                        slug VARCHAR(100) NOT NULL UNIQUE,
                                        description TEXT,
                                        icon VARCHAR(50),

    -- Category settings
                                        is_active BOOLEAN DEFAULT TRUE,
                                        sort_order INTEGER DEFAULT 0,

                                        created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Integration providers table (available integrations)
CREATE TABLE integration_providers (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       category_id UUID REFERENCES integration_categories(id),

    -- Provider details
                                       name VARCHAR(255) NOT NULL,
                                       slug VARCHAR(100) NOT NULL UNIQUE,
                                       description TEXT,
                                       website_url VARCHAR(500),

    -- Provider branding
                                       logo_url VARCHAR(500),
                                       primary_color VARCHAR(7), -- Hex color

    -- Integration type
                                       integration_type VARCHAR(50) NOT NULL, -- oauth2, api_key, webhook, custom
                                       auth_type VARCHAR(50), -- oauth2, basic, bearer, custom

    -- Configuration schema
                                       config_schema JSONB NOT NULL, -- JSON schema for configuration
                                       auth_schema JSONB, -- JSON schema for authentication

    -- API details
                                       base_url VARCHAR(500),
                                       api_version VARCHAR(20),
                                       rate_limits JSONB, -- Rate limiting information

    -- Webhook support
                                       supports_webhooks BOOLEAN DEFAULT FALSE,
                                       webhook_events JSONB, -- Available webhook events

    -- Features
                                       features JSONB DEFAULT '{}', -- Available features and capabilities

    -- Documentation
                                       documentation_url VARCHAR(500),
                                       setup_instructions TEXT,

    -- Status
                                       is_active BOOLEAN DEFAULT TRUE,
                                       is_beta BOOLEAN DEFAULT FALSE,

    -- Metadata
                                       created_at TIMESTAMPTZ DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enhanced integrations table (replacing basic one)
DROP TABLE IF EXISTS integrations;
CREATE TABLE integrations (
                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                              organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                              provider_id UUID NOT NULL REFERENCES integration_providers(id),

    -- Integration details
                              name VARCHAR(255) NOT NULL,
                              description TEXT,

    -- Configuration
                              config JSONB NOT NULL DEFAULT '{}',

    -- Authentication
                              auth_type VARCHAR(50) NOT NULL,
                              auth_data JSONB DEFAULT '{}', -- Encrypted auth credentials

    -- OAuth specific
                              oauth_access_token TEXT,
                              oauth_refresh_token TEXT,
                              oauth_token_expires_at TIMESTAMPTZ,
                              oauth_scope TEXT[],

    -- API Key specific
                              api_key_encrypted TEXT,
                              api_secret_encrypted TEXT,

    -- Webhook configuration
                              webhook_url VARCHAR(1000),
                              webhook_secret VARCHAR(255),
                              webhook_events TEXT[],

    -- Status and health
                              status integration_status DEFAULT 'inactive',
                              health_status VARCHAR(20) DEFAULT 'unknown', -- healthy, degraded, failed, unknown
                              last_health_check_at TIMESTAMPTZ,
                              health_check_details JSONB,

    -- Sync settings
                              auto_sync BOOLEAN DEFAULT TRUE,
                              sync_interval_minutes INTEGER DEFAULT 60,
                              last_sync_at TIMESTAMPTZ,
                              next_sync_at TIMESTAMPTZ,

    -- Error handling
                              last_error TEXT,
                              error_count INTEGER DEFAULT 0,
                              consecutive_failures INTEGER DEFAULT 0,

    -- Feature toggles
                              enabled_features JSONB DEFAULT '{}',

    -- Usage statistics
                              total_api_calls INTEGER DEFAULT 0,
                              total_data_synced INTEGER DEFAULT 0,
                              last_activity_at TIMESTAMPTZ,

    -- Metadata
                              created_by UUID REFERENCES user_profiles(id),
                              created_at TIMESTAMPTZ DEFAULT NOW(),
                              updated_at TIMESTAMPTZ DEFAULT NOW(),
                              deleted_at TIMESTAMPTZ,

                              UNIQUE(organization_id, provider_id, name)
);

-- =====================================================
-- INTEGRATION SYNC & DATA MAPPING
-- =====================================================

-- Enhanced integration sync logs table
DROP TABLE IF EXISTS integration_sync_logs;
CREATE TABLE integration_sync_logs (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       integration_id UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,

    -- Sync details
                                       sync_type VARCHAR(50) NOT NULL, -- full, incremental, manual, webhook_triggered
                                       sync_direction VARCHAR(20) NOT NULL, -- inbound, outbound, bidirectional

    -- Trigger information
                                       triggered_by VARCHAR(50), -- scheduler, user, webhook, api
                                       triggered_by_user_id UUID REFERENCES user_profiles(id),

    -- Status
                                       status VARCHAR(20) NOT NULL, -- started, processing, completed, failed, cancelled

    -- Progress tracking
                                       total_records INTEGER DEFAULT 0,
                                       processed_records INTEGER DEFAULT 0,
                                       successful_records INTEGER DEFAULT 0,
                                       failed_records INTEGER DEFAULT 0,
                                       skipped_records INTEGER DEFAULT 0,

    -- Data breakdown by entity type
                                       entities_processed JSONB DEFAULT '{}', -- {contacts: 50, companies: 20, deals: 10}

    -- Performance metrics
                                       processing_time_ms INTEGER,
                                       api_calls_made INTEGER DEFAULT 0,
                                       data_transferred_bytes BIGINT DEFAULT 0,

    -- Error handling
                                       error_summary TEXT,
                                       error_details JSONB,
                                       retry_count INTEGER DEFAULT 0,

    -- Sync metadata
                                       sync_metadata JSONB DEFAULT '{}',
                                       external_sync_id VARCHAR(255), -- ID from external system

    -- Timing
                                       started_at TIMESTAMPTZ DEFAULT NOW(),
                                       completed_at TIMESTAMPTZ,

    -- Data quality
                                       data_quality_score DECIMAL(3,2), -- 0.00 to 1.00
                                       quality_issues JSONB
);

-- Integration data mappings table
CREATE TABLE integration_data_mappings (
                                           id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                           integration_id UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,

    -- Mapping details
                                           entity_type VARCHAR(50) NOT NULL, -- contacts, companies, deals, etc.
                                           direction VARCHAR(20) NOT NULL, -- inbound, outbound, bidirectional

    -- Field mappings
                                           field_mappings JSONB NOT NULL, -- {external_field: internal_field}
                                           transformation_rules JSONB, -- Data transformation rules

    -- Filtering and conditions
                                           sync_conditions JSONB, -- When to sync this data
                                           field_filters JSONB, -- Which fields to include/exclude

    -- Conflict resolution
                                           conflict_resolution VARCHAR(50) DEFAULT 'external_wins', -- external_wins, internal_wins, merge, manual

    -- Settings
                                           is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                           created_by UUID REFERENCES user_profiles(id),
                                           created_at TIMESTAMPTZ DEFAULT NOW(),
                                           updated_at TIMESTAMPTZ DEFAULT NOW(),

                                           UNIQUE(integration_id, entity_type, direction)
);

-- Integration field mappings history
CREATE TABLE integration_mapping_history (
                                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                             mapping_id UUID NOT NULL REFERENCES integration_data_mappings(id) ON DELETE CASCADE,
                                             sync_log_id UUID REFERENCES integration_sync_logs(id),

    -- Record details
                                             external_record_id VARCHAR(255) NOT NULL,
                                             internal_record_id UUID,
                                             entity_type VARCHAR(50) NOT NULL,

    -- Operation
                                             operation VARCHAR(20) NOT NULL, -- create, update, delete, skip, error

    -- Data snapshots
                                             external_data JSONB,
                                             internal_data_before JSONB,
                                             internal_data_after JSONB,

    -- Transformation details
                                             transformations_applied JSONB,

    -- Error information
                                             error_message TEXT,

    -- Metadata
                                             processed_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- WEBHOOK ENHANCEMENTS
-- =====================================================

-- Enhanced webhooks table (replacing basic one)
DROP TABLE IF EXISTS webhooks;
CREATE TABLE webhooks (
                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                          organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                          integration_id UUID REFERENCES integrations(id) ON DELETE CASCADE,

    -- Webhook details
                          name VARCHAR(255) NOT NULL,
                          description TEXT,
                          url VARCHAR(1000) NOT NULL,

    -- Security
                          secret VARCHAR(255),
                          signature_header VARCHAR(100) DEFAULT 'X-Signature',
                          signature_method VARCHAR(20) DEFAULT 'hmac-sha256',

    -- Authentication
                          auth_type VARCHAR(50), -- none, bearer, basic, custom
                          auth_headers JSONB, -- Custom authentication headers

    -- Configuration
                          method VARCHAR(10) DEFAULT 'POST',
                          headers JSONB DEFAULT '{}',
                          timeout_seconds INTEGER DEFAULT 30,

    -- Event filtering
                          events TEXT[] NOT NULL,
                          event_filters JSONB, -- Additional filtering conditions

    -- Retry configuration
                          max_retries INTEGER DEFAULT 3,
                          retry_backoff_strategy VARCHAR(20) DEFAULT 'exponential', -- linear, exponential, fixed
                          retry_delay_seconds INTEGER DEFAULT 60,

    -- Rate limiting
                          rate_limit_per_minute INTEGER,
                          rate_limit_burst INTEGER,

    -- Status and health
                          is_active BOOLEAN DEFAULT TRUE,
                          health_status VARCHAR(20) DEFAULT 'unknown', -- healthy, degraded, failed, unknown

    -- Statistics
                          total_deliveries INTEGER DEFAULT 0,
                          successful_deliveries INTEGER DEFAULT 0,
                          failed_deliveries INTEGER DEFAULT 0,
                          last_delivery_at TIMESTAMPTZ,
                          last_success_at TIMESTAMPTZ,
                          last_failure_at TIMESTAMPTZ,

    -- Error tracking
                          consecutive_failures INTEGER DEFAULT 0,
                          last_error_message TEXT,

    -- Metadata
                          created_by UUID REFERENCES user_profiles(id),
                          created_at TIMESTAMPTZ DEFAULT NOW(),
                          updated_at TIMESTAMPTZ DEFAULT NOW(),
                          deleted_at TIMESTAMPTZ
);

-- Enhanced webhook deliveries table
DROP TABLE IF EXISTS webhook_deliveries;
CREATE TABLE webhook_deliveries (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    webhook_id UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,

    -- Delivery details
                                    event_type VARCHAR(100) NOT NULL,
                                    event_id UUID,
                                    payload JSONB NOT NULL,

    -- Request details
                                    request_method VARCHAR(10) NOT NULL,
                                    request_url VARCHAR(1000) NOT NULL,
                                    request_headers JSONB,
                                    request_body TEXT,

    -- Response details
                                    response_status_code INTEGER,
                                    response_headers JSONB,
                                    response_body TEXT,
                                    response_time_ms INTEGER,

    -- Delivery status
                                    status VARCHAR(20) DEFAULT 'pending', -- pending, delivered, failed, cancelled

    -- Retry information
                                    attempt_number INTEGER DEFAULT 1,
                                    max_attempts INTEGER DEFAULT 3,
                                    next_retry_at TIMESTAMPTZ,

    -- Error handling
                                    error_message TEXT,
                                    error_type VARCHAR(50), -- timeout, connection, authentication, server_error, client_error

    -- Security
                                    signature_sent VARCHAR(500),

    -- Timing
                                    scheduled_at TIMESTAMPTZ DEFAULT NOW(),
                                    delivered_at TIMESTAMPTZ,

    -- Metadata
                                    metadata JSONB DEFAULT '{}'
);

-- =====================================================
-- API MANAGEMENT
-- =====================================================

-- API keys table (for incoming API access)
CREATE TABLE api_keys (
                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                          organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Key details
                          name VARCHAR(255) NOT NULL,
                          description TEXT,
                          key_prefix VARCHAR(20) NOT NULL, -- First part of the key (visible)
                          key_hash VARCHAR(255) NOT NULL, -- Hashed full key

    -- Permissions
                          scopes TEXT[] NOT NULL, -- API scopes this key has access to
                          allowed_ips INET[], -- IP restrictions

    -- Rate limiting
                          rate_limit_per_minute INTEGER DEFAULT 1000,
                          rate_limit_per_hour INTEGER DEFAULT 10000,
                          rate_limit_per_day INTEGER DEFAULT 100000,

    -- Usage tracking
                          total_requests INTEGER DEFAULT 0,
                          last_used_at TIMESTAMPTZ,
                          last_used_ip INET,

    -- Key lifecycle
                          expires_at TIMESTAMPTZ,
                          is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                          created_by UUID REFERENCES user_profiles(id),
                          created_at TIMESTAMPTZ DEFAULT NOW(),
                          revoked_at TIMESTAMPTZ,
                          revoked_by UUID REFERENCES user_profiles(id),
                          revocation_reason TEXT
);

-- API usage logs table
CREATE TABLE api_usage_logs (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                api_key_id UUID REFERENCES api_keys(id) ON DELETE SET NULL,

    -- Request details
                                request_method VARCHAR(10) NOT NULL,
                                request_path VARCHAR(1000) NOT NULL,
                                request_query JSONB,
                                request_headers JSONB,

    -- Response details
                                response_status INTEGER NOT NULL,
                                response_time_ms INTEGER,
                                response_size_bytes INTEGER,

    -- Client information
                                client_ip INET,
                                user_agent TEXT,

    -- Rate limiting
                                rate_limit_remaining INTEGER,
                                rate_limit_reset_at TIMESTAMPTZ,

    -- Error information
                                error_message TEXT,

    -- Timestamp
                                timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- MARKETPLACE & APP STORE
-- =====================================================

-- Integration marketplace apps
CREATE TABLE marketplace_apps (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  provider_id UUID NOT NULL REFERENCES integration_providers(id),

    -- App details
                                  name VARCHAR(255) NOT NULL,
                                  slug VARCHAR(100) NOT NULL UNIQUE,
                                  short_description VARCHAR(500),
                                  full_description TEXT,

    -- App assets
                                  icon_url VARCHAR(500),
                                  screenshots JSONB, -- Array of screenshot URLs
                                  video_url VARCHAR(500),

    -- Pricing
                                  pricing_model VARCHAR(50), -- free, freemium, paid, subscription
                                  price_per_month DECIMAL(10,2),
                                  price_per_year DECIMAL(10,2),
                                  has_free_trial BOOLEAN DEFAULT FALSE,
                                  trial_days INTEGER,

    -- App metadata
                                  version VARCHAR(20),
                                  minimum_plan VARCHAR(50), -- Minimum subscription plan required
                                  supported_regions TEXT[],

    -- Ratings and reviews
                                  average_rating DECIMAL(2,1) DEFAULT 0.0,
                                  total_reviews INTEGER DEFAULT 0,
                                  total_installs INTEGER DEFAULT 0,

    -- App status
                                  status VARCHAR(20) DEFAULT 'draft', -- draft, review, approved, published, suspended
                                  is_featured BOOLEAN DEFAULT FALSE,

    -- Developer information
                                  developer_name VARCHAR(255),
                                  developer_website VARCHAR(500),
                                  developer_support_email VARCHAR(255),

    -- Compliance and security
                                  security_review_status VARCHAR(20) DEFAULT 'pending',
                                  compliance_certifications TEXT[],
                                  data_processing_regions TEXT[],

    -- Metadata
                                  published_at TIMESTAMPTZ,
                                  created_at TIMESTAMPTZ DEFAULT NOW(),
                                  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- App installations
CREATE TABLE app_installations (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                   marketplace_app_id UUID NOT NULL REFERENCES marketplace_apps(id),
                                   integration_id UUID REFERENCES integrations(id) ON DELETE CASCADE,

    -- Installation details
                                   installation_status VARCHAR(20) DEFAULT 'active', -- active, suspended, cancelled

    -- Configuration
                                   configuration JSONB DEFAULT '{}',
                                   custom_settings JSONB DEFAULT '{}',

    -- Billing
                                   subscription_status VARCHAR(20), -- trial, active, past_due, cancelled
                                   trial_ends_at TIMESTAMPTZ,
                                   billing_cycle VARCHAR(20), -- monthly, yearly

    -- Usage tracking
                                   last_used_at TIMESTAMPTZ,
                                   usage_metrics JSONB DEFAULT '{}',

    -- Metadata
                                   installed_by UUID REFERENCES user_profiles(id),
                                   installed_at TIMESTAMPTZ DEFAULT NOW(),
                                   uninstalled_at TIMESTAMPTZ,
                                   uninstalled_by UUID REFERENCES user_profiles(id),

                                   UNIQUE(organization_id, marketplace_app_id)
);

-- =====================================================
-- FUNCTIONS FOR INTEGRATIONS
-- =====================================================

-- Function to create webhook delivery
CREATE OR REPLACE FUNCTION create_webhook_delivery(
    webhook_uuid UUID,
    event_type_param VARCHAR(100),
    event_payload JSONB,
    event_id_param UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
delivery_id UUID;
    webhook_record RECORD;
    signature_value VARCHAR(500);
BEGIN
    -- Get webhook configuration
SELECT * INTO webhook_record FROM webhooks WHERE id = webhook_uuid AND is_active = TRUE;

IF NOT FOUND THEN
        RAISE EXCEPTION 'Webhook not found or inactive: %', webhook_uuid;
END IF;

    -- Check if event type is in allowed events
    IF NOT (event_type_param = ANY(webhook_record.events)) THEN
        RETURN NULL; -- Event not configured for this webhook
END IF;

    -- Generate signature if secret is configured
    IF webhook_record.secret IS NOT NULL THEN
        -- This would use actual HMAC implementation
        signature_value := 'sha256=' || encode(hmac(event_payload::text, webhook_record.secret, 'sha256'), 'hex');
END IF;

    -- Create delivery record
INSERT INTO webhook_deliveries (
    webhook_id,
    event_type,
    event_id,
    payload,
    request_method,
    request_url,
    request_headers,
    signature_sent,
    max_attempts
) VALUES (
             webhook_uuid,
             event_type_param,
             event_id_param,
             event_payload,
             webhook_record.method,
             webhook_record.url,
             webhook_record.headers,
             signature_value,
             webhook_record.max_retries + 1
         ) RETURNING id INTO delivery_id;

-- Update webhook statistics
UPDATE webhooks
SET total_deliveries = total_deliveries + 1
WHERE id = webhook_uuid;

RETURN delivery_id;
END;
$$ LANGUAGE plpgsql;

-- Function to process webhook delivery result
CREATE OR REPLACE FUNCTION process_webhook_delivery_result(
    delivery_uuid UUID,
    status_code INTEGER,
    response_body_param TEXT,
    response_time_param INTEGER,
    error_message_param TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
delivery_record RECORD;
    webhook_uuid UUID;
    is_success BOOLEAN;
    should_retry BOOLEAN := FALSE;
    next_retry TIMESTAMPTZ;
BEGIN
    -- Get delivery record
SELECT * INTO delivery_record FROM webhook_deliveries WHERE id = delivery_uuid;
webhook_uuid := delivery_record.webhook_id;

    -- Determine if delivery was successful
    is_success := (status_code >= 200 AND status_code < 300);

    -- Update delivery record
UPDATE webhook_deliveries
SET
    response_status_code = status_code,
    response_body = response_body_param,
    response_time_ms = response_time_param,
    error_message = error_message_param,
    status = CASE WHEN is_success THEN 'delivered' ELSE 'failed' END,
    delivered_at = NOW()
WHERE id = delivery_uuid;

-- Handle retry logic for failed deliveries
IF NOT is_success AND delivery_record.attempt_number < delivery_record.max_attempts THEN
        should_retry := TRUE;

        -- Calculate next retry time based on backoff strategy
SELECT
    CASE
        WHEN w.retry_backoff_strategy = 'exponential' THEN
            NOW() + INTERVAL '1 second' * (w.retry_delay_seconds * POWER(2, delivery_record.attempt_number - 1))
    WHEN w.retry_backoff_strategy = 'linear' THEN
    NOW() + INTERVAL '1 second' * (w.retry_delay_seconds * delivery_record.attempt_number)
    ELSE
    NOW() + INTERVAL '1 second' * w.retry_delay_seconds
END
INTO next_retry
        FROM webhooks w
        WHERE w.id = webhook_uuid;

        -- Schedule retry
INSERT INTO webhook_deliveries (
    webhook_id,
    event_type,
    event_id,
    payload,
    request_method,
    request_url,
    request_headers,
    signature_sent,
    attempt_number,
    max_attempts,
    scheduled_at
) SELECT
      webhook_id,
      event_type,
      event_id,
      payload,
      request_method,
      request_url,
      request_headers,
      signature_sent,
      attempt_number + 1,
      max_attempts,
      next_retry
FROM webhook_deliveries
WHERE id = delivery_uuid;
END IF;

    -- Update webhook statistics
UPDATE webhooks
SET
    successful_deliveries = successful_deliveries + CASE WHEN is_success THEN 1 ELSE 0 END,
    failed_deliveries = failed_deliveries + CASE WHEN is_success THEN 0 ELSE 1 END,
    consecutive_failures = CASE WHEN is_success THEN 0 ELSE consecutive_failures + 1 END,
    last_delivery_at = NOW(),
    last_success_at = CASE WHEN is_success THEN NOW() ELSE last_success_at END,
    last_failure_at = CASE WHEN is_success THEN last_failure_at ELSE NOW() END,
    last_error_message = CASE WHEN is_success THEN NULL ELSE error_message_param END,
    health_status = CASE
                        WHEN is_success THEN 'healthy'
                        WHEN consecutive_failures >= 5 THEN 'failed'
                        WHEN consecutive_failures >= 3 THEN 'degraded'
                        ELSE health_status
        END
WHERE id = webhook_uuid;
END;
$$ LANGUAGE plpgsql;

-- Function to sync integration data
CREATE OR REPLACE FUNCTION sync_integration_data(
    integration_uuid UUID,
    sync_type_param VARCHAR(50) DEFAULT 'incremental',
    entity_types TEXT[] DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
sync_log_id UUID;
    integration_record RECORD;
    total_processed INTEGER := 0;
BEGIN
    -- Get integration details
SELECT * INTO integration_record FROM integrations WHERE id = integration_uuid;

IF NOT FOUND THEN
        RAISE EXCEPTION 'Integration not found: %', integration_uuid;
END IF;

    -- Create sync log
INSERT INTO integration_sync_logs (
    integration_id,
    sync_type,
    sync_direction,
    triggered_by,
    triggered_by_user_id,
    status
) VALUES (
             integration_uuid,
             sync_type_param,
             'bidirectional',
             'manual',
             auth.uid(),
             'started'
         ) RETURNING id INTO sync_log_id;

-- Update integration last sync
UPDATE integrations
SET
    last_sync_at = NOW(),
    next_sync_at = NOW() + INTERVAL '1 minute' * sync_interval_minutes
WHERE id = integration_uuid;

-- The actual sync logic would be implemented in the application layer
-- This is just a placeholder that marks the sync as completed
UPDATE integration_sync_logs
SET
    status = 'completed',
    completed_at = NOW(),
    processed_records = total_processed,
    successful_records = total_processed
WHERE id = sync_log_id;

RETURN sync_log_id;
END;
$$ LANGUAGE plpgsql;

-- Function to generate API key
CREATE OR REPLACE FUNCTION generate_api_key(
    key_name VARCHAR(255),
    key_scopes TEXT[],
    org_uuid UUID DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
full_key TEXT;
    key_prefix VARCHAR(20);
    key_hash VARCHAR(255);
    api_key_id UUID;
    user_org_id UUID;
BEGIN
    -- Get organization
    user_org_id := COALESCE(org_uuid, auth.user_organization_id());

    -- Generate random key
    full_key := 'eck_' || encode(gen_random_bytes(32), 'base64');
    full_key := replace(full_key, '/', '_');
    full_key := replace(full_key, '+', '-');
    full_key := replace(full_key, '=', '');

    -- Extract prefix (first 12 characters)
    key_prefix := left(full_key, 12);

    -- Hash the full key
    key_hash := encode(digest(full_key, 'sha256'), 'hex');

    -- Store API key
INSERT INTO api_keys (
    organization_id,
    name,
    key_prefix,
    key_hash,
    scopes,
    created_by
) VALUES (
             user_org_id,
             key_name,
             key_prefix,
             key_hash,
             key_scopes,
             auth.uid()
         ) RETURNING id INTO api_key_id;

RETURN full_key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- INDEXES
-- =====================================================

-- Integration providers indexes
CREATE INDEX idx_integration_providers_category_id ON integration_providers(category_id);
CREATE INDEX idx_integration_providers_slug ON integration_providers(slug);
CREATE INDEX idx_integration_providers_active ON integration_providers(is_active);

-- Integrations indexes
CREATE INDEX idx_integrations_organization_id ON integrations(organization_id);
CREATE INDEX idx_integrations_provider_id ON integrations(provider_id);
CREATE INDEX idx_integrations_status ON integrations(status);
CREATE INDEX idx_integrations_next_sync ON integrations(next_sync_at) WHERE auto_sync = TRUE;

-- Integration sync logs indexes
CREATE INDEX idx_integration_sync_logs_integration_id ON integration_sync_logs(integration_id);
CREATE INDEX idx_integration_sync_logs_started_at ON integration_sync_logs(started_at);
CREATE INDEX idx_integration_sync_logs_status ON integration_sync_logs(status);

-- Webhook deliveries indexes
CREATE INDEX idx_webhook_deliveries_webhook_id ON webhook_deliveries(webhook_id);
CREATE INDEX idx_webhook_deliveries_status ON webhook_deliveries(status);
CREATE INDEX idx_webhook_deliveries_scheduled_at ON webhook_deliveries(scheduled_at);
CREATE INDEX idx_webhook_deliveries_event_type ON webhook_deliveries(event_type);

-- API usage logs indexes
CREATE INDEX idx_api_usage_logs_organization_id ON api_usage_logs(organization_id);
CREATE INDEX idx_api_usage_logs_api_key_id ON api_usage_logs(api_key_id);
CREATE INDEX idx_api_usage_logs_timestamp ON api_usage_logs(timestamp);

-- Marketplace apps indexes
CREATE INDEX idx_marketplace_apps_provider_id ON marketplace_apps(provider_id);
CREATE INDEX idx_marketplace_apps_status ON marketplace_apps(status);
CREATE INDEX idx_marketplace_apps_featured ON marketplace_apps(is_featured);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_integration_providers_updated_at BEFORE UPDATE ON integration_providers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_integrations_updated_at BEFORE UPDATE ON integrations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_integration_data_mappings_updated_at BEFORE UPDATE ON integration_data_mappings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_webhooks_updated_at BEFORE UPDATE ON webhooks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_marketplace_apps_updated_at BEFORE UPDATE ON marketplace_apps FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();