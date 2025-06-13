-- =====================================================
-- BILLING & SUBSCRIPTIONS MIGRATION
-- Comprehensive billing, subscription, and payment management
-- Created: 2025-06-13 20:29:09 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- SUBSCRIPTION PLANS & PRICING
-- =====================================================

-- Enhanced subscription plans table (replacing basic one)
DROP TABLE IF EXISTS subscription_plans;
CREATE TABLE subscription_plans (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Plan identification
                                    name VARCHAR(100) NOT NULL UNIQUE,
                                    slug VARCHAR(50) NOT NULL UNIQUE,
                                    description TEXT,

    -- Plan type and billing
                                    plan_type VARCHAR(50) DEFAULT 'subscription', -- subscription, one_time, usage_based, custom
                                    billing_period VARCHAR(20) DEFAULT 'monthly', -- monthly, quarterly, yearly, one_time

    -- Pricing
                                    price_monthly DECIMAL(10,2),
                                    price_quarterly DECIMAL(10,2),
                                    price_yearly DECIMAL(10,2),
                                    setup_fee DECIMAL(10,2) DEFAULT 0.00,

    -- Currency and localization
                                    currency VARCHAR(3) DEFAULT 'USD',
                                    supported_currencies JSONB DEFAULT '["USD"]',

    -- Usage-based pricing
                                    usage_based_pricing JSONB, -- Configuration for usage-based billing
                                    overage_pricing JSONB, -- Pricing for exceeding limits

    -- Plan limits and features
                                    max_users INTEGER,
                                    max_contacts INTEGER,
                                    max_companies INTEGER,
                                    max_deals INTEGER,
                                    max_storage_gb INTEGER,
                                    max_api_calls_per_month INTEGER,
                                    max_integrations INTEGER,
                                    max_custom_fields INTEGER,

    -- Feature flags
                                    features JSONB DEFAULT '{}', -- Available features for this plan
                                    restrictions JSONB DEFAULT '{}', -- Feature restrictions

    -- Plan availability
                                    is_active BOOLEAN DEFAULT TRUE,
                                    is_public BOOLEAN DEFAULT TRUE,
                                    is_trial_available BOOLEAN DEFAULT TRUE,
                                    trial_days INTEGER DEFAULT 14,

    -- Plan targeting
                                    target_market VARCHAR(50), -- startup, small_business, enterprise, enterprise_plus
                                    recommended_users VARCHAR(50), -- 1-10, 11-50, 51-200, 200+

    -- Plan ordering and display
                                    sort_order INTEGER DEFAULT 0,
                                    is_featured BOOLEAN DEFAULT FALSE,
                                    is_most_popular BOOLEAN DEFAULT FALSE,

    -- External integration
                                    stripe_price_id_monthly VARCHAR(255),
                                    stripe_price_id_quarterly VARCHAR(255),
                                    stripe_price_id_yearly VARCHAR(255),
                                    stripe_product_id VARCHAR(255),

    -- Plan metadata
                                    metadata JSONB DEFAULT '{}',

    -- Lifecycle
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW(),
                                    deprecated_at TIMESTAMPTZ,

                                    CHECK (slug ~ '^[a-z0-9-]+$') -- Only lowercase, numbers, and hyphens
    );

-- Plan add-ons table
CREATE TABLE plan_addons (
                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Add-on details
                             name VARCHAR(100) NOT NULL,
                             slug VARCHAR(50) NOT NULL UNIQUE,
                             description TEXT,

    -- Add-on type
                             addon_type VARCHAR(50) NOT NULL, -- storage, users, integrations, features, support

    -- Pricing
                             price_monthly DECIMAL(10,2),
                             price_yearly DECIMAL(10,2),
                             price_per_unit DECIMAL(10,2), -- For quantity-based add-ons

    -- Add-on configuration
                             unit_type VARCHAR(50), -- users, gb, api_calls, integrations
                             min_quantity INTEGER DEFAULT 1,
                             max_quantity INTEGER,
                             increment_quantity INTEGER DEFAULT 1,

    -- Feature configuration
                             features_added JSONB DEFAULT '{}',
                             limits_added JSONB DEFAULT '{}',

    -- Availability
                             is_active BOOLEAN DEFAULT TRUE,
                             compatible_plans UUID[], -- Plan IDs this add-on is compatible with

    -- External integration
                             stripe_price_id VARCHAR(255),

    -- Metadata
                             created_at TIMESTAMPTZ DEFAULT NOW(),
                             updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- ORGANIZATION SUBSCRIPTIONS
-- =====================================================

-- Enhanced organization subscriptions table (replacing basic one)
DROP TABLE IF EXISTS organization_subscriptions;
CREATE TABLE organization_subscriptions (
                                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                            organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                            plan_id UUID NOT NULL REFERENCES subscription_plans(id),

    -- Subscription details
                                            subscription_name VARCHAR(255), -- Custom name for this subscription

    -- Billing configuration
                                            billing_cycle VARCHAR(20) NOT NULL, -- monthly, quarterly, yearly
                                            billing_email VARCHAR(255),

    -- Subscription status
                                            status VARCHAR(20) DEFAULT 'active', -- trial, active, past_due, cancelled, paused, expired

    -- Subscription periods
                                            current_period_start TIMESTAMPTZ NOT NULL,
                                            current_period_end TIMESTAMPTZ NOT NULL,

    -- Trial information
                                            trial_start TIMESTAMPTZ,
                                            trial_end TIMESTAMPTZ,
                                            trial_days_used INTEGER DEFAULT 0,

    -- Pricing and amounts
                                            base_amount DECIMAL(10,2) NOT NULL,
                                            discount_amount DECIMAL(10,2) DEFAULT 0.00,
                                            total_amount DECIMAL(10,2) NOT NULL,
                                            currency VARCHAR(3) DEFAULT 'USD',

    -- Usage tracking
                                            current_usage JSONB DEFAULT '{}', -- Current usage metrics
                                            usage_limits JSONB DEFAULT '{}', -- Usage limits for this subscription

    -- Subscription lifecycle
                                            started_at TIMESTAMPTZ DEFAULT NOW(),
                                            cancelled_at TIMESTAMPTZ,
                                            cancelled_by UUID REFERENCES user_profiles(id),
                                            cancellation_reason TEXT,
                                            cancellation_type VARCHAR(50), -- immediate, end_of_period, downgrade

    -- Renewal and changes
                                            auto_renew BOOLEAN DEFAULT TRUE,
                                            next_billing_date TIMESTAMPTZ,
                                            pending_changes JSONB, -- Changes to apply at next billing cycle

    -- Payment information
                                            payment_method_id VARCHAR(255), -- Reference to payment method
                                            last_payment_at TIMESTAMPTZ,
                                            next_payment_attempt_at TIMESTAMPTZ,
                                            failed_payment_count INTEGER DEFAULT 0,

    -- External integration
                                            stripe_subscription_id VARCHAR(255) UNIQUE,
                                            stripe_customer_id VARCHAR(255),

    -- Notifications
                                            billing_notifications_enabled BOOLEAN DEFAULT TRUE,
                                            usage_notifications_enabled BOOLEAN DEFAULT TRUE,

    -- Metadata
                                            metadata JSONB DEFAULT '{}',
                                            created_at TIMESTAMPTZ DEFAULT NOW(),
                                            updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Subscription add-ons table
CREATE TABLE subscription_addons (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     subscription_id UUID NOT NULL REFERENCES organization_subscriptions(id) ON DELETE CASCADE,
                                     addon_id UUID NOT NULL REFERENCES plan_addons(id),

    -- Add-on configuration
                                     quantity INTEGER DEFAULT 1,
                                     unit_price DECIMAL(10,2) NOT NULL,
                                     total_price DECIMAL(10,2) NOT NULL,

    -- Add-on period
                                     started_at TIMESTAMPTZ DEFAULT NOW(),
                                     ended_at TIMESTAMPTZ,

    -- Status
                                     is_active BOOLEAN DEFAULT TRUE,

    -- External integration
                                     stripe_subscription_item_id VARCHAR(255),

                                     UNIQUE(subscription_id, addon_id)
);

-- =====================================================
-- BILLING & INVOICING
-- =====================================================

-- Invoices table
CREATE TABLE invoices (
                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                          organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                          subscription_id UUID REFERENCES organization_subscriptions(id),

    -- Invoice identification
                          invoice_number VARCHAR(50) NOT NULL UNIQUE,

    -- Invoice details
                          invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
                          due_date DATE NOT NULL,

    -- Invoice amounts
                          subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
                          tax_amount DECIMAL(10,2) DEFAULT 0.00,
                          discount_amount DECIMAL(10,2) DEFAULT 0.00,
                          total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
                          amount_paid DECIMAL(10,2) DEFAULT 0.00,
                          amount_due DECIMAL(10,2) GENERATED ALWAYS AS (total_amount - amount_paid) STORED,
                          currency VARCHAR(3) DEFAULT 'USD',

    -- Invoice status
                          status VARCHAR(20) DEFAULT 'draft', -- draft, sent, paid, overdue, cancelled, refunded

    -- Payment information
                          payment_terms INTEGER DEFAULT 30, -- Days
                          paid_at TIMESTAMPTZ,

    -- Billing addresses
                          billing_address JSONB,
                          shipping_address JSONB,

    -- Invoice metadata
                          description TEXT,
                          notes TEXT,
                          terms_and_conditions TEXT,

    -- External integration
                          stripe_invoice_id VARCHAR(255) UNIQUE,

    -- File references
                          pdf_url VARCHAR(1000),

    -- Metadata
                          created_by UUID REFERENCES user_profiles(id),
                          created_at TIMESTAMPTZ DEFAULT NOW(),
                          updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Invoice line items table
CREATE TABLE invoice_line_items (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,

    -- Line item details
                                    description TEXT NOT NULL,
                                    quantity DECIMAL(10,3) DEFAULT 1.000,
                                    unit_price DECIMAL(10,2) NOT NULL,
                                    total_amount DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,

    -- Line item type
                                    item_type VARCHAR(50) DEFAULT 'subscription', -- subscription, addon, usage, one_time, discount

    -- Period for subscription items
                                    period_start DATE,
                                    period_end DATE,

    -- References
                                    plan_id UUID REFERENCES subscription_plans(id),
                                    addon_id UUID REFERENCES plan_addons(id),

    -- Tax information
                                    tax_rate DECIMAL(5,4) DEFAULT 0.0000,
                                    tax_amount DECIMAL(10,2) DEFAULT 0.00,

    -- External integration
                                    stripe_line_item_id VARCHAR(255),

    -- Metadata
                                    metadata JSONB DEFAULT '{}',
                                    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- PAYMENTS & TRANSACTIONS
-- =====================================================

-- Payment methods table
CREATE TABLE payment_methods (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Payment method details
                                 method_type VARCHAR(50) NOT NULL, -- card, bank_account, paypal, wire_transfer

    -- Card information (masked)
                                 card_brand VARCHAR(20), -- visa, mastercard, amex, etc.
                                 card_last_four VARCHAR(4),
                                 card_exp_month INTEGER,
                                 card_exp_year INTEGER,

    -- Bank account information (masked)
                                 bank_name VARCHAR(100),
                                 account_last_four VARCHAR(4),
                                 account_type VARCHAR(20), -- checking, savings

    -- Payment method status
                                 is_default BOOLEAN DEFAULT FALSE,
                                 is_verified BOOLEAN DEFAULT FALSE,

    -- External integration
                                 stripe_payment_method_id VARCHAR(255) UNIQUE,

    -- Metadata
                                 created_by UUID REFERENCES user_profiles(id),
                                 created_at TIMESTAMPTZ DEFAULT NOW(),
                                 updated_at TIMESTAMPTZ DEFAULT NOW(),
                                 deleted_at TIMESTAMPTZ
);

-- Payments table
CREATE TABLE payments (
                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                          organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                          invoice_id UUID REFERENCES invoices(id),
                          subscription_id UUID REFERENCES organization_subscriptions(id),
                          payment_method_id UUID REFERENCES payment_methods(id),

    -- Payment details
                          amount DECIMAL(10,2) NOT NULL,
                          currency VARCHAR(3) DEFAULT 'USD',

    -- Payment status
                          status VARCHAR(20) DEFAULT 'pending', -- pending, processing, succeeded, failed, cancelled, refunded

    -- Payment type
                          payment_type VARCHAR(50) DEFAULT 'automatic', -- automatic, manual, retry

    -- Payment timing
                          processed_at TIMESTAMPTZ,
                          failed_at TIMESTAMPTZ,

    -- Payment provider details
                          provider VARCHAR(50) DEFAULT 'stripe', -- stripe, paypal, manual, bank_transfer
                          provider_transaction_id VARCHAR(255),
                          provider_fee DECIMAL(10,2) DEFAULT 0.00,

    -- Failure information
                          failure_code VARCHAR(100),
                          failure_message TEXT,

    -- Refund information
                          refunded_amount DECIMAL(10,2) DEFAULT 0.00,
                          refunded_at TIMESTAMPTZ,
                          refund_reason TEXT,

    -- External integration
                          stripe_payment_intent_id VARCHAR(255),
                          stripe_charge_id VARCHAR(255),

    -- Metadata
                          metadata JSONB DEFAULT '{}',
                          created_at TIMESTAMPTZ DEFAULT NOW(),
                          updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- USAGE TRACKING & METERING
-- =====================================================

-- Usage metrics table
CREATE TABLE usage_metrics (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                               subscription_id UUID REFERENCES organization_subscriptions(id),

    -- Metric details
                               metric_name VARCHAR(100) NOT NULL, -- users, contacts, storage_gb, api_calls, etc.
                               metric_value DECIMAL(15,4) NOT NULL,
                               metric_unit VARCHAR(50), -- count, gb, mb, requests, etc.

    -- Measurement period
                               measurement_date DATE NOT NULL,
                               measurement_hour INTEGER, -- For hourly metrics (0-23)

    -- Aggregation level
                               aggregation_level VARCHAR(20) DEFAULT 'daily', -- hourly, daily, monthly

    -- Usage context
                               usage_category VARCHAR(50), -- core, addon, overage

    -- Metadata
                               recorded_at TIMESTAMPTZ DEFAULT NOW(),
                               metadata JSONB DEFAULT '{}',

                               UNIQUE(organization_id, metric_name, measurement_date, measurement_hour)
);

-- Usage alerts table
CREATE TABLE usage_alerts (
                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                              organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                              subscription_id UUID REFERENCES organization_subscriptions(id),

    -- Alert configuration
                              metric_name VARCHAR(100) NOT NULL,
                              alert_type VARCHAR(50) NOT NULL, -- threshold, approaching_limit, limit_exceeded
                              threshold_percentage DECIMAL(5,2), -- Percentage of limit to trigger alert
                              threshold_value DECIMAL(15,4), -- Absolute value to trigger alert

    -- Alert status
                              is_active BOOLEAN DEFAULT TRUE,
                              last_triggered_at TIMESTAMPTZ,
                              trigger_count INTEGER DEFAULT 0,

    -- Notification settings
                              notify_users UUID[] DEFAULT '{}',
                              notify_emails TEXT[] DEFAULT '{}',
                              notification_frequency VARCHAR(20) DEFAULT 'daily', -- immediate, daily, weekly

    -- Metadata
                              created_by UUID REFERENCES user_profiles(id),
                              created_at TIMESTAMPTZ DEFAULT NOW(),
                              updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- BILLING ANALYTICS & REPORTING
-- =====================================================

-- Revenue analytics table
CREATE TABLE revenue_analytics (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   organization_id UUID REFERENCES organizations(id), -- NULL for global analytics

    -- Analytics period
                                   period_type VARCHAR(20) NOT NULL, -- daily, weekly, monthly, quarterly, yearly
                                   period_start DATE NOT NULL,
                                   period_end DATE NOT NULL,

    -- Revenue metrics
                                   gross_revenue DECIMAL(15,2) DEFAULT 0.00,
                                   net_revenue DECIMAL(15,2) DEFAULT 0.00,
                                   recurring_revenue DECIMAL(15,2) DEFAULT 0.00,
                                   one_time_revenue DECIMAL(15,2) DEFAULT 0.00,

    -- Customer metrics
                                   new_customers INTEGER DEFAULT 0,
                                   churned_customers INTEGER DEFAULT 0,
                                   total_active_customers INTEGER DEFAULT 0,

    -- Subscription metrics
                                   new_subscriptions INTEGER DEFAULT 0,
                                   cancelled_subscriptions INTEGER DEFAULT 0,
                                   upgraded_subscriptions INTEGER DEFAULT 0,
                                   downgraded_subscriptions INTEGER DEFAULT 0,

    -- MRR (Monthly Recurring Revenue) breakdown
                                   mrr_total DECIMAL(15,2) DEFAULT 0.00,
                                   mrr_new DECIMAL(15,2) DEFAULT 0.00,
                                   mrr_expansion DECIMAL(15,2) DEFAULT 0.00,
                                   mrr_contraction DECIMAL(15,2) DEFAULT 0.00,
                                   mrr_churn DECIMAL(15,2) DEFAULT 0.00,

    -- Other KPIs
                                   average_revenue_per_user DECIMAL(10,2) DEFAULT 0.00,
                                   customer_lifetime_value DECIMAL(15,2) DEFAULT 0.00,
                                   churn_rate DECIMAL(5,2) DEFAULT 0.00,

    -- Plan breakdown
                                   plan_breakdown JSONB DEFAULT '{}', -- Revenue by plan

    -- Metadata
                                   calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                   UNIQUE(organization_id, period_type, period_start)
);

-- =====================================================
-- FUNCTIONS FOR BILLING
-- =====================================================

-- Function to calculate current usage
CREATE OR REPLACE FUNCTION calculate_current_usage(
    org_uuid UUID,
    metric_name_param VARCHAR(100)
)
RETURNS DECIMAL(15,4) AS $$
DECLARE
current_usage_val DECIMAL(15,4) := 0;
    current_month_start DATE;
    current_month_end DATE;
BEGIN
    -- Get current month boundaries
    current_month_start := date_trunc('month', CURRENT_DATE)::DATE;
    current_month_end := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- Calculate usage based on metric type
CASE metric_name_param
        WHEN 'users' THEN
SELECT COUNT(*) INTO current_usage_val
FROM user_profiles
WHERE organization_id = org_uuid
  AND status = 'active'
  AND deleted_at IS NULL;

WHEN 'contacts' THEN
SELECT COUNT(*) INTO current_usage_val
FROM contacts
WHERE organization_id = org_uuid
  AND deleted_at IS NULL;

WHEN 'companies' THEN
SELECT COUNT(*) INTO current_usage_val
FROM companies
WHERE organization_id = org_uuid
  AND deleted_at IS NULL;

WHEN 'deals' THEN
SELECT COUNT(*) INTO current_usage_val
FROM deals
WHERE organization_id = org_uuid
  AND deleted_at IS NULL;

WHEN 'storage_gb' THEN
SELECT COALESCE(SUM(file_size), 0) / (1024.0 * 1024.0 * 1024.0) INTO current_usage_val
FROM documents
WHERE organization_id = org_uuid
  AND deleted_at IS NULL;

WHEN 'api_calls' THEN
SELECT COUNT(*) INTO current_usage_val
FROM api_usage_logs
WHERE organization_id = org_uuid
  AND timestamp >= current_month_start
  AND timestamp <= current_month_end;

ELSE
            -- For custom metrics, get from usage_metrics table
SELECT COALESCE(MAX(metric_value), 0) INTO current_usage_val
FROM usage_metrics
WHERE organization_id = org_uuid
  AND metric_name = metric_name_param
  AND measurement_date >= current_month_start
  AND measurement_date <= current_month_end;
END CASE;

RETURN current_usage_val;
END;
$$ LANGUAGE plpgsql;

-- Function to check usage limits and trigger alerts
CREATE OR REPLACE FUNCTION check_usage_limits(
    org_uuid UUID
)
RETURNS VOID AS $$
DECLARE
subscription_record RECORD;
    alert_record RECORD;
    current_usage_val DECIMAL(15,4);
    usage_limit DECIMAL(15,4);
    usage_percentage DECIMAL(5,2);
BEGIN
    -- Get active subscription
SELECT * INTO subscription_record
FROM organization_subscriptions
WHERE organization_id = org_uuid
  AND status = 'active';

IF NOT FOUND THEN
        RETURN;
END IF;

    -- Check each usage alert
FOR alert_record IN
SELECT * FROM usage_alerts
WHERE organization_id = org_uuid
  AND subscription_id = subscription_record.id
  AND is_active = TRUE
    LOOP
        -- Calculate current usage
        current_usage_val := calculate_current_usage(org_uuid, alert_record.metric_name);

-- Get usage limit from subscription
usage_limit := (subscription_record.usage_limits ->> alert_record.metric_name)::DECIMAL;

        IF usage_limit IS NOT NULL AND usage_limit > 0 THEN
            usage_percentage := (current_usage_val / usage_limit) * 100;

            -- Check if alert should be triggered
            IF (alert_record.threshold_percentage IS NOT NULL AND
                usage_percentage >= alert_record.threshold_percentage) OR
               (alert_record.threshold_value IS NOT NULL AND
                current_usage_val >= alert_record.threshold_value) THEN

                -- Trigger alert (in real implementation, this would send notifications)
UPDATE usage_alerts
SET
    last_triggered_at = NOW(),
    trigger_count = trigger_count + 1
WHERE id = alert_record.id;

-- Create notification
PERFORM process_notification_rules(
                    'usage_alert_triggered',
                    jsonb_build_object(
                        'organization_id', org_uuid,
                        'metric_name', alert_record.metric_name,
                        'current_usage', current_usage_val,
                        'usage_limit', usage_limit,
                        'usage_percentage', usage_percentage
                    )
                );
END IF;
END IF;
END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to generate invoice
CREATE OR REPLACE FUNCTION generate_invoice(
    org_uuid UUID,
    subscription_uuid UUID,
    billing_period_start DATE,
    billing_period_end DATE
)
RETURNS UUID AS $$
DECLARE
invoice_id UUID;
    subscription_record RECORD;
    plan_record RECORD;
    invoice_number_val VARCHAR(50);
    subtotal_val DECIMAL(10,2) := 0.00;
BEGIN
    -- Get subscription and plan details
SELECT s.*, p.* INTO subscription_record
FROM organization_subscriptions s
         JOIN subscription_plans p ON s.plan_id = p.id
WHERE s.id = subscription_uuid;

-- Generate invoice number
invoice_number_val := 'INV-' || TO_CHAR(NOW(), 'YYYYMM') || '-' ||
                         LPAD(EXTRACT(EPOCH FROM NOW())::TEXT, 10, '0');

    -- Calculate subtotal (base subscription + add-ons + usage)
    subtotal_val := subscription_record.base_amount;

    -- Add add-on costs
SELECT COALESCE(SUM(total_price), 0) INTO subtotal_val
FROM subscription_addons
WHERE subscription_id = subscription_uuid
  AND is_active = TRUE;

subtotal_val := subscription_record.base_amount + subtotal_val;

    -- Create invoice
INSERT INTO invoices (
    organization_id,
    subscription_id,
    invoice_number,
    invoice_date,
    due_date,
    subtotal,
    total_amount,
    currency,
    status
) VALUES (
             org_uuid,
             subscription_uuid,
             invoice_number_val,
             CURRENT_DATE,
             CURRENT_DATE + INTERVAL '30 days',
             subtotal_val,
             subtotal_val, -- Simplified - no tax calculation
             subscription_record.currency,
             'sent'
         ) RETURNING id INTO invoice_id;

-- Add line items
INSERT INTO invoice_line_items (
    invoice_id,
    description,
    quantity,
    unit_price,
    item_type,
    period_start,
    period_end,
    plan_id
) VALUES (
             invoice_id,
             plan_record.name || ' - ' || subscription_record.billing_cycle,
             1,
             subscription_record.base_amount,
             'subscription',
             billing_period_start,
             billing_period_end,
             subscription_record.plan_id
         );

RETURN invoice_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Subscription plans indexes
CREATE INDEX idx_subscription_plans_slug ON subscription_plans(slug);
CREATE INDEX idx_subscription_plans_active ON subscription_plans(is_active);
CREATE INDEX idx_subscription_plans_public ON subscription_plans(is_public);

-- Organization subscriptions indexes
CREATE INDEX idx_org_subscriptions_organization_id ON organization_subscriptions(organization_id);
CREATE INDEX idx_org_subscriptions_plan_id ON organization_subscriptions(plan_id);
CREATE INDEX idx_org_subscriptions_status ON organization_subscriptions(status);
CREATE INDEX idx_org_subscriptions_billing_date ON organization_subscriptions(next_billing_date);
CREATE INDEX idx_org_subscriptions_stripe ON organization_subscriptions(stripe_subscription_id);

-- Invoices indexes
CREATE INDEX idx_invoices_organization_id ON invoices(organization_id);
CREATE INDEX idx_invoices_subscription_id ON invoices(subscription_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_due_date ON invoices(due_date);
CREATE INDEX idx_invoices_invoice_number ON invoices(invoice_number);

-- Payments indexes
CREATE INDEX idx_payments_organization_id ON payments(organization_id);
CREATE INDEX idx_payments_invoice_id ON payments(invoice_id);
CREATE INDEX idx_payments_subscription_id ON payments(subscription_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_processed_at ON payments(processed_at);

-- Usage metrics indexes
CREATE INDEX idx_usage_metrics_organization_id ON usage_metrics(organization_id);
CREATE INDEX idx_usage_metrics_subscription_id ON usage_metrics(subscription_id);
CREATE INDEX idx_usage_metrics_metric_name ON usage_metrics(metric_name);
CREATE INDEX idx_usage_metrics_measurement_date ON usage_metrics(measurement_date);

-- Revenue analytics indexes
CREATE INDEX idx_revenue_analytics_organization_id ON revenue_analytics(organization_id);
CREATE INDEX idx_revenue_analytics_period ON revenue_analytics(period_type, period_start);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_subscription_plans_updated_at BEFORE UPDATE ON subscription_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_organization_subscriptions_updated_at BEFORE UPDATE ON organization_subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_plan_addons_updated_at BEFORE UPDATE ON plan_addons FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_invoices_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payment_methods_updated_at BEFORE UPDATE ON payment_methods FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payments_updated_at BEFORE UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_usage_alerts_updated_at BEFORE UPDATE ON usage_alerts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();