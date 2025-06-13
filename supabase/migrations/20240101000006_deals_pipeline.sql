-- =====================================================
-- DEALS PIPELINE MIGRATION
-- Extended deals features, pipeline management, and forecasting
-- Created: 2024-01-01 00:00:06 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- DEAL PIPELINE ENHANCEMENTS
-- =====================================================

-- Deal stage settings table (additional settings per stage)
CREATE TABLE deal_stage_settings (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     stage_id UUID NOT NULL REFERENCES deal_stages(id) ON DELETE CASCADE,

    -- Stage behavior settings
                                     require_note_on_entry BOOLEAN DEFAULT FALSE,
                                     require_note_on_exit BOOLEAN DEFAULT FALSE,
                                     auto_create_activities JSONB, -- Activities to create when deal enters stage

    -- Time tracking
                                     average_time_in_stage_days INTEGER DEFAULT 0,
                                     max_time_in_stage_days INTEGER,

    -- Automation rules
                                     automation_rules JSONB DEFAULT '{}',

    -- Email templates for this stage
                                     entry_email_template_id UUID REFERENCES email_templates(id),
                                     exit_email_template_id UUID REFERENCES email_templates(id),

                                     created_at TIMESTAMPTZ DEFAULT NOW(),
                                     updated_at TIMESTAMPTZ DEFAULT NOW(),

                                     UNIQUE(stage_id)
);

-- =====================================================
-- DEAL PRODUCTS & LINE ITEMS
-- =====================================================

-- Products/Services table
CREATE TABLE products (
                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                          organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Product details
                          name VARCHAR(255) NOT NULL,
                          sku VARCHAR(100),
                          description TEXT,

    -- Product type
                          type VARCHAR(50) DEFAULT 'product', -- product, service, subscription
                          category VARCHAR(100),

    -- Pricing
                          unit_price DECIMAL(15,2) DEFAULT 0.00,
                          cost DECIMAL(15,2) DEFAULT 0.00,
                          currency VARCHAR(3) DEFAULT 'USD',

    -- Subscription details (for subscription products)
                          billing_period VARCHAR(20), -- monthly, quarterly, yearly
                          trial_period_days INTEGER DEFAULT 0,

    -- Status
                          is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                          created_by UUID REFERENCES user_profiles(id),
                          created_at TIMESTAMPTZ DEFAULT NOW(),
                          updated_at TIMESTAMPTZ DEFAULT NOW(),
                          deleted_at TIMESTAMPTZ,

    -- Search vector
                          search_vector tsvector GENERATED ALWAYS AS (
                              to_tsvector('english',
                                          coalesce(name, '') || ' ' ||
                                          coalesce(sku, '') || ' ' ||
                                          coalesce(description, '') || ' ' ||
                                          coalesce(category, '')
                              )
                              ) STORED
);

-- Deal line items table
CREATE TABLE deal_line_items (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 deal_id UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
                                 product_id UUID REFERENCES products(id),

    -- Item details
                                 name VARCHAR(255) NOT NULL, -- Can override product name
                                 description TEXT,
                                 sku VARCHAR(100),

    -- Quantity and pricing
                                 quantity DECIMAL(10,2) DEFAULT 1.00,
                                 unit_price DECIMAL(15,2) NOT NULL,
                                 discount_percentage DECIMAL(5,2) DEFAULT 0.00,
                                 discount_amount DECIMAL(15,2) DEFAULT 0.00,

    -- Calculated fields
                                 subtotal DECIMAL(15,2) GENERATED ALWAYS AS (
                                     quantity * unit_price
                                     ) STORED,

                                 total_amount DECIMAL(15,2) GENERATED ALWAYS AS (
                                     (quantity * unit_price) - discount_amount - ((quantity * unit_price) * discount_percentage / 100)
                                     ) STORED,

    -- Subscription details
                                 billing_period VARCHAR(20),
                                 subscription_length_months INTEGER,

    -- Position for ordering
                                 position INTEGER DEFAULT 0,

    -- Metadata
                                 created_at TIMESTAMPTZ DEFAULT NOW(),
                                 updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- DEAL FORECASTING & ANALYTICS
-- =====================================================

-- Deal forecasts table (periodic forecasting snapshots)
CREATE TABLE deal_forecasts (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                pipeline_id UUID NOT NULL REFERENCES deal_pipelines(id),

    -- Forecast period
                                forecast_period VARCHAR(20) NOT NULL, -- monthly, quarterly, yearly
                                period_start DATE NOT NULL,
                                period_end DATE NOT NULL,

    -- Forecast metrics
                                total_deals_count INTEGER DEFAULT 0,
                                total_deal_value DECIMAL(15,2) DEFAULT 0.00,
                                weighted_deal_value DECIMAL(15,2) DEFAULT 0.00, -- Value * probability

    -- By stage breakdown
                                stage_breakdown JSONB DEFAULT '{}', -- {stage_id: {count, value, weighted_value}}

    -- Confidence levels
                                best_case_value DECIMAL(15,2) DEFAULT 0.00,
                                worst_case_value DECIMAL(15,2) DEFAULT 0.00,
                                most_likely_value DECIMAL(15,2) DEFAULT 0.00,

    -- Snapshot metadata
                                created_by UUID REFERENCES user_profiles(id),
                                created_at TIMESTAMPTZ DEFAULT NOW(),

                                UNIQUE(organization_id, pipeline_id, forecast_period, period_start)
);

-- Deal stage history table (track deal movement through pipeline)
CREATE TABLE deal_stage_history (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    deal_id UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,

    -- Stage movement
                                    from_stage_id UUID REFERENCES deal_stages(id),
                                    to_stage_id UUID NOT NULL REFERENCES deal_stages(id),

    -- Change details
                                    reason VARCHAR(255),
                                    notes TEXT,

    -- Time tracking
                                    time_in_previous_stage_days INTEGER,

    -- Value changes
                                    previous_value DECIMAL(15,2),
                                    new_value DECIMAL(15,2),

    -- Metadata
                                    moved_by UUID REFERENCES user_profiles(id),
                                    moved_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- DEAL COMPETITORS & COMPETITIVE ANALYSIS
-- =====================================================

-- Competitors table
CREATE TABLE competitors (
                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                             organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Competitor details
                             name VARCHAR(255) NOT NULL,
                             website VARCHAR(500),
                             description TEXT,

    -- Competitive positioning
                             strengths TEXT[],
                             weaknesses TEXT[],

    -- Metadata
                             created_by UUID REFERENCES user_profiles(id),
                             created_at TIMESTAMPTZ DEFAULT NOW(),
                             updated_at TIMESTAMPTZ DEFAULT NOW(),
                             deleted_at TIMESTAMPTZ
);

-- Deal competitors table (which competitors are involved in deals)
CREATE TABLE deal_competitors (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  deal_id UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
                                  competitor_id UUID NOT NULL REFERENCES competitors(id) ON DELETE CASCADE,

    -- Competition details
                                  competitive_position VARCHAR(50), -- winning, losing, even, unknown
                                  likelihood_to_win DECIMAL(3,2), -- 0.00 to 1.00

    -- Intel
                                  their_price DECIMAL(15,2),
                                  their_strengths TEXT,
                                  their_weaknesses TEXT,
                                  our_advantages TEXT,

    -- Status
                                  is_active BOOLEAN DEFAULT TRUE,
                                  eliminated_at TIMESTAMPTZ,
                                  elimination_reason TEXT,

    -- Metadata
                                  added_by UUID REFERENCES user_profiles(id),
                                  added_at TIMESTAMPTZ DEFAULT NOW(),

                                  UNIQUE(deal_id, competitor_id)
);

-- =====================================================
-- DEAL COLLABORATION & TEAM SELLING
-- =====================================================

-- Deal team members table (multiple people working on a deal)
CREATE TABLE deal_team_members (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   deal_id UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
                                   user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Role in deal
                                   role VARCHAR(50) DEFAULT 'team_member', -- owner, team_member, specialist, overlay

    -- Commission/split info
                                   commission_percentage DECIMAL(5,2) DEFAULT 0.00,

    -- Access permissions
                                   can_edit BOOLEAN DEFAULT TRUE,
                                   can_view_financials BOOLEAN DEFAULT FALSE,

    -- Metadata
                                   added_by UUID REFERENCES user_profiles(id),
                                   added_at TIMESTAMPTZ DEFAULT NOW(),

                                   UNIQUE(deal_id, user_id)
);

-- Deal notes table (collaborative notes on deals)
CREATE TABLE deal_notes (
                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                            deal_id UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
                            author_id UUID NOT NULL REFERENCES user_profiles(id),

    -- Note content
                            title VARCHAR(255),
                            content TEXT NOT NULL,
                            note_type VARCHAR(50) DEFAULT 'general', -- general, meeting, call, email, competitive

    -- Visibility
                            is_private BOOLEAN DEFAULT FALSE,
                            visible_to_team_only BOOLEAN DEFAULT FALSE,

    -- Pinning
                            is_pinned BOOLEAN DEFAULT FALSE,

    -- Metadata
                            created_at TIMESTAMPTZ DEFAULT NOW(),
                            updated_at TIMESTAMPTZ DEFAULT NOW(),
                            deleted_at TIMESTAMPTZ
);

-- =====================================================
-- DEAL APPROVAL WORKFLOWS
-- =====================================================

-- Deal approval workflows table
CREATE TABLE deal_approval_workflows (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Workflow details
                                         name VARCHAR(255) NOT NULL,
                                         description TEXT,

    -- Trigger conditions
                                         trigger_conditions JSONB NOT NULL, -- When this workflow should trigger

    -- Approval steps
                                         approval_steps JSONB NOT NULL, -- Array of approval step configurations

    -- Settings
                                         is_active BOOLEAN DEFAULT TRUE,
                                         is_required BOOLEAN DEFAULT FALSE,

    -- Metadata
                                         created_by UUID REFERENCES user_profiles(id),
                                         created_at TIMESTAMPTZ DEFAULT NOW(),
                                         updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deal approvals table
CREATE TABLE deal_approvals (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                deal_id UUID NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
                                workflow_id UUID NOT NULL REFERENCES deal_approval_workflows(id),

    -- Approval details
                                status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected, cancelled
                                current_step INTEGER DEFAULT 1,
                                total_steps INTEGER NOT NULL,

    -- Approval data
                                approval_data JSONB DEFAULT '{}', -- Responses from each step

    -- Timing
                                requested_at TIMESTAMPTZ DEFAULT NOW(),
                                completed_at TIMESTAMPTZ,

    -- Metadata
                                requested_by UUID REFERENCES user_profiles(id)
);

-- Deal approval steps table
CREATE TABLE deal_approval_steps (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     approval_id UUID NOT NULL REFERENCES deal_approvals(id) ON DELETE CASCADE,

    -- Step details
                                     step_number INTEGER NOT NULL,
                                     step_type VARCHAR(50) NOT NULL, -- user_approval, manager_approval, automatic

    -- Approver
                                     approver_id UUID REFERENCES user_profiles(id),
                                     approver_role VARCHAR(50), -- If approval by role instead of specific user

    -- Status
                                     status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected, skipped

    -- Response
                                     response TEXT,
                                     responded_at TIMESTAMPTZ,

    -- Metadata
                                     created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- FUNCTIONS FOR DEALS
-- =====================================================

-- Function to update deal total from line items
CREATE OR REPLACE FUNCTION update_deal_total()
RETURNS TRIGGER AS $$
DECLARE
deal_uuid UUID;
    new_total DECIMAL(15,2);
BEGIN
    -- Get the deal ID
    IF TG_OP = 'DELETE' THEN
        deal_uuid := OLD.deal_id;
ELSE
        deal_uuid := NEW.deal_id;
END IF;

    -- Calculate new total
SELECT COALESCE(SUM(total_amount), 0.00) INTO new_total
FROM deal_line_items
WHERE deal_id = deal_uuid;

-- Update deal value
UPDATE deals
SET value = new_total, updated_at = NOW()
WHERE id = deal_uuid;

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating deal totals
CREATE TRIGGER update_deal_total_trigger
    AFTER INSERT OR UPDATE OR DELETE ON deal_line_items
    FOR EACH ROW
    EXECUTE FUNCTION update_deal_total();

-- Function to track deal stage changes
CREATE OR REPLACE FUNCTION track_deal_stage_change()
RETURNS TRIGGER AS $$
DECLARE
previous_stage_entry_date TIMESTAMPTZ;
    time_in_stage INTEGER;
BEGIN
    -- Only track if stage actually changed
    IF OLD.stage_id IS DISTINCT FROM NEW.stage_id THEN

        -- Calculate time in previous stage
SELECT moved_at INTO previous_stage_entry_date
FROM deal_stage_history
WHERE deal_id = NEW.id
ORDER BY moved_at DESC
    LIMIT 1;

-- If no previous history, use deal creation date
IF previous_stage_entry_date IS NULL THEN
            previous_stage_entry_date := OLD.created_at;
END IF;

        time_in_stage := EXTRACT(EPOCH FROM (NOW() - previous_stage_entry_date)) / 86400; -- Convert to days

        -- Insert stage history record
INSERT INTO deal_stage_history (
    deal_id,
    from_stage_id,
    to_stage_id,
    time_in_previous_stage_days,
    previous_value,
    new_value,
    moved_by
) VALUES (
             NEW.id,
             OLD.stage_id,
             NEW.stage_id,
             time_in_stage,
             OLD.value,
             NEW.value,
             auth.uid()
         );

-- Update stage probability if it changed
IF NEW.stage_id != OLD.stage_id THEN
UPDATE deals
SET probability = (
    SELECT probability
    FROM deal_stages
    WHERE id = NEW.stage_id
)
WHERE id = NEW.id;
END IF;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for tracking stage changes
CREATE TRIGGER track_deal_stage_change_trigger
    AFTER UPDATE ON deals
    FOR EACH ROW
    EXECUTE FUNCTION track_deal_stage_change();

-- Function to auto-create activities when deal enters stage
CREATE OR REPLACE FUNCTION auto_create_stage_activities()
RETURNS TRIGGER AS $$
DECLARE
stage_settings RECORD;
    activity_config JSONB;
BEGIN
    -- Only process if stage changed
    IF OLD.stage_id IS DISTINCT FROM NEW.stage_id THEN

        -- Get stage settings
SELECT * INTO stage_settings
FROM deal_stage_settings
WHERE stage_id = NEW.stage_id;

IF FOUND AND stage_settings.auto_create_activities IS NOT NULL THEN
            -- Loop through activities to create
            FOR activity_config IN
SELECT * FROM jsonb_array_elements(stage_settings.auto_create_activities)
                  LOOP
    INSERT INTO activities (
    organization_id,
    deal_id,
    owner_id,
    type,
    title,
    description,
    scheduled_at,
    created_by
) VALUES (
    NEW.organization_id,
    NEW.id,
    COALESCE((activity_config->>'owner_id')::UUID, NEW.owner_id),
    (activity_config->>'type')::activity_type,
    activity_config->>'title',
    activity_config->>'description',
    CASE
    WHEN activity_config->>'days_from_now' IS NOT NULL
    THEN NOW() + INTERVAL '1 day' * (activity_config->>'days_from_now')::INTEGER
    ELSE NOW() + INTERVAL '1 day'
    END,
    auth.uid()
    );
END LOOP;
END IF;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-creating activities
CREATE TRIGGER auto_create_stage_activities_trigger
    AFTER UPDATE ON deals
    FOR EACH ROW
    EXECUTE FUNCTION auto_create_stage_activities();

-- Function to generate deal forecast
CREATE OR REPLACE FUNCTION generate_deal_forecast(
    org_uuid UUID,
    pipeline_uuid UUID,
    forecast_period_param VARCHAR(20),
    period_start_param DATE,
    period_end_param DATE
)
RETURNS UUID AS $$
DECLARE
forecast_id UUID;
    total_count INTEGER := 0;
    total_value DECIMAL(15,2) := 0.00;
    weighted_value DECIMAL(15,2) := 0.00;
    stage_data JSONB := '{}';
    stage_record RECORD;
BEGIN
    -- Calculate metrics for deals in the forecast period
SELECT
    COUNT(*),
    COALESCE(SUM(value), 0),
    COALESCE(SUM(value * probability / 100), 0)
INTO total_count, total_value, weighted_value
FROM deals d
WHERE d.organization_id = org_uuid
  AND d.pipeline_id = pipeline_uuid
  AND d.expected_close_date BETWEEN period_start_param AND period_end_param
  AND d.status = 'open';

-- Calculate breakdown by stage
FOR stage_record IN
SELECT
    ds.id as stage_id,
    ds.name as stage_name,
    COUNT(d.id) as count,
            COALESCE(SUM(d.value), 0) as value,
            COALESCE(SUM(d.value * d.probability / 100), 0) as weighted_value
FROM deal_stages ds
    LEFT JOIN deals d ON d.stage_id = ds.id
    AND d.organization_id = org_uuid
    AND d.expected_close_date BETWEEN period_start_param AND period_end_param
    AND d.status = 'open'
WHERE ds.pipeline_id = pipeline_uuid
GROUP BY ds.id, ds.name
    LOOP
    stage_data := stage_data || jsonb_build_object(
    stage_record.stage_id::text,
    jsonb_build_object(
    'name', stage_record.stage_name,
    'count', stage_record.count,
    'value', stage_record.value,
    'weighted_value', stage_record.weighted_value
    )
    );
END LOOP;

    -- Insert or update forecast
INSERT INTO deal_forecasts (
    organization_id,
    pipeline_id,
    forecast_period,
    period_start,
    period_end,
    total_deals_count,
    total_deal_value,
    weighted_deal_value,
    stage_breakdown,
    most_likely_value,
    created_by
) VALUES (
             org_uuid,
             pipeline_uuid,
             forecast_period_param,
             period_start_param,
             period_end_param,
             total_count,
             total_value,
             weighted_value,
             stage_data,
             weighted_value, -- Using weighted value as most likely
             auth.uid()
         )
    ON CONFLICT (organization_id, pipeline_id, forecast_period, period_start)
    DO UPDATE SET
    total_deals_count = EXCLUDED.total_deals_count,
               total_deal_value = EXCLUDED.total_deal_value,
               weighted_deal_value = EXCLUDED.weighted_deal_value,
               stage_breakdown = EXCLUDED.stage_breakdown,
               most_likely_value = EXCLUDED.most_likely_value,
               created_at = NOW()
               RETURNING id INTO forecast_id;

RETURN forecast_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Products indexes
CREATE INDEX idx_products_organization_id ON products(organization_id);
CREATE INDEX idx_products_sku ON products(sku);
CREATE INDEX idx_products_type ON products(type);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_search_vector ON products USING GIN(search_vector);

-- Deal line items indexes
CREATE INDEX idx_deal_line_items_deal_id ON deal_line_items(deal_id);
CREATE INDEX idx_deal_line_items_product_id ON deal_line_items(product_id);

-- Deal forecasts indexes
CREATE INDEX idx_deal_forecasts_organization_id ON deal_forecasts(organization_id);
CREATE INDEX idx_deal_forecasts_pipeline_id ON deal_forecasts(pipeline_id);
CREATE INDEX idx_deal_forecasts_period ON deal_forecasts(forecast_period, period_start);

-- Deal stage history indexes
CREATE INDEX idx_deal_stage_history_deal_id ON deal_stage_history(deal_id);
CREATE INDEX idx_deal_stage_history_moved_at ON deal_stage_history(moved_at);

-- Competitors indexes
CREATE INDEX idx_competitors_organization_id ON competitors(organization_id);

-- Deal competitors indexes
CREATE INDEX idx_deal_competitors_deal_id ON deal_competitors(deal_id);
CREATE INDEX idx_deal_competitors_competitor_id ON deal_competitors(competitor_id);

-- Deal team members indexes
CREATE INDEX idx_deal_team_members_deal_id ON deal_team_members(deal_id);
CREATE INDEX idx_deal_team_members_user_id ON deal_team_members(user_id);

-- Deal notes indexes
CREATE INDEX idx_deal_notes_deal_id ON deal_notes(deal_id);
CREATE INDEX idx_deal_notes_author_id ON deal_notes(author_id);
CREATE INDEX idx_deal_notes_created_at ON deal_notes(created_at);

-- Deal approvals indexes
CREATE INDEX idx_deal_approvals_deal_id ON deal_approvals(deal_id);
CREATE INDEX idx_deal_approvals_status ON deal_approvals(status);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_deal_line_items_updated_at BEFORE UPDATE ON deal_line_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_competitors_updated_at BEFORE UPDATE ON competitors FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_deal_notes_updated_at BEFORE UPDATE ON deal_notes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_deal_approval_workflows_updated_at BEFORE UPDATE ON deal_approval_workflows FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();