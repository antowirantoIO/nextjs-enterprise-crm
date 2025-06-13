-- =====================================================
-- ORGANIZATIONS & WORKSPACES MIGRATION
-- Extended organization features and workspace management
-- Created: 2024-01-01 00:00:03 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- WORKSPACE TABLES
-- =====================================================

-- Workspaces table (sub-organizations or teams)
CREATE TABLE workspaces (
                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                            organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                            parent_workspace_id UUID REFERENCES workspaces(id),

    -- Workspace details
                            name VARCHAR(255) NOT NULL,
                            slug VARCHAR(100) NOT NULL,
                            description TEXT,
                            color VARCHAR(7), -- Hex color code
                            icon VARCHAR(50), -- Icon identifier

    -- Settings
                            is_active BOOLEAN DEFAULT TRUE,
                            is_default BOOLEAN DEFAULT FALSE,

    -- Permissions
                            settings JSONB DEFAULT '{}',

    -- Metadata
                            created_by UUID REFERENCES user_profiles(id),
                            created_at TIMESTAMPTZ DEFAULT NOW(),
                            updated_at TIMESTAMPTZ DEFAULT NOW(),
                            deleted_at TIMESTAMPTZ,

    -- Constraints
                            UNIQUE(organization_id, slug),
                            CHECK (slug ~ '^[a-z0-9-]+$') -- Only lowercase, numbers, and hyphens
    );

-- Workspace members table
CREATE TABLE workspace_members (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
                                   user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Role in workspace
                                   role VARCHAR(50) DEFAULT 'member', -- admin, member, viewer

    -- Permissions
                                   permissions JSONB DEFAULT '{}',

    -- Metadata
                                   joined_at TIMESTAMPTZ DEFAULT NOW(),
                                   invited_by UUID REFERENCES user_profiles(id),

    -- Constraints
                                   UNIQUE(workspace_id, user_id)
);

-- =====================================================
-- TEAMS MANAGEMENT
-- =====================================================

-- Teams table
CREATE TABLE teams (
                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                       organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                       workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,

    -- Team details
                       name VARCHAR(255) NOT NULL,
                       description TEXT,
                       color VARCHAR(7), -- Hex color code

    -- Team lead
                       team_lead_id UUID REFERENCES user_profiles(id),

    -- Settings
                       is_active BOOLEAN DEFAULT TRUE,
                       settings JSONB DEFAULT '{}',

    -- Metadata
                       created_by UUID REFERENCES user_profiles(id),
                       created_at TIMESTAMPTZ DEFAULT NOW(),
                       updated_at TIMESTAMPTZ DEFAULT NOW(),
                       deleted_at TIMESTAMPTZ
);

-- Team members table
CREATE TABLE team_members (
                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                              team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
                              user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Role in team
                              role VARCHAR(50) DEFAULT 'member', -- lead, senior, member

    -- Metadata
                              joined_at TIMESTAMPTZ DEFAULT NOW(),
                              added_by UUID REFERENCES user_profiles(id),

    -- Constraints
                              UNIQUE(team_id, user_id)
);

-- =====================================================
-- ORGANIZATION DOMAINS
-- =====================================================

-- Organization domains table (for SSO and email verification)
CREATE TABLE organization_domains (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Domain details
                                      domain VARCHAR(255) NOT NULL,
                                      is_verified BOOLEAN DEFAULT FALSE,
                                      is_primary BOOLEAN DEFAULT FALSE,

    -- Verification
                                      verification_token VARCHAR(255),
                                      verified_at TIMESTAMPTZ,

    -- Settings
                                      auto_join_enabled BOOLEAN DEFAULT FALSE, -- Auto-join users with this domain
                                      default_role user_role DEFAULT 'viewer',

    -- Metadata
                                      created_by UUID REFERENCES user_profiles(id),
                                      created_at TIMESTAMPTZ DEFAULT NOW(),
                                      updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
                                      UNIQUE(domain),
                                      UNIQUE(organization_id, domain)
);

-- =====================================================
-- ORGANIZATION INVITATIONS
-- =====================================================

-- Organization invitations table
CREATE TABLE organization_invitations (
                                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                          organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                          workspace_id UUID REFERENCES workspaces(id),
                                          team_id UUID REFERENCES teams(id),

    -- Invitation details
                                          email VARCHAR(255) NOT NULL,
                                          role user_role DEFAULT 'viewer',

    -- Invitation token
                                          token VARCHAR(255) NOT NULL UNIQUE,

    -- Status
                                          status VARCHAR(20) DEFAULT 'pending', -- pending, accepted, expired, cancelled

    -- Expiration
                                          expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),

    -- Acceptance tracking
                                          accepted_at TIMESTAMPTZ,
                                          accepted_by UUID REFERENCES user_profiles(id),

    -- Metadata
                                          invited_by UUID REFERENCES user_profiles(id),
                                          created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
                                          UNIQUE(organization_id, email, status) -- Prevent duplicate pending invitations
);

-- =====================================================
-- ORGANIZATION BILLING
-- =====================================================

-- Subscription plans table
CREATE TABLE subscription_plans (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Plan details
                                    name VARCHAR(100) NOT NULL UNIQUE,
                                    slug VARCHAR(50) NOT NULL UNIQUE,
                                    description TEXT,

    -- Pricing
                                    price_monthly DECIMAL(10,2),
                                    price_yearly DECIMAL(10,2),

    -- Limits
                                    max_users INTEGER,
                                    max_contacts INTEGER,
                                    max_storage_gb INTEGER,

    -- Features
                                    features JSONB DEFAULT '{}',

    -- Status
                                    is_active BOOLEAN DEFAULT TRUE,
                                    is_public BOOLEAN DEFAULT TRUE,

    -- Metadata
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Organization subscriptions table
CREATE TABLE organization_subscriptions (
                                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                            organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                            plan_id UUID REFERENCES subscription_plans(id),

    -- Subscription details
                                            status VARCHAR(20) DEFAULT 'active', -- active, cancelled, past_due, unpaid

    -- Billing
                                            billing_cycle VARCHAR(20) DEFAULT 'monthly', -- monthly, yearly
                                            amount DECIMAL(10,2),
                                            currency VARCHAR(3) DEFAULT 'USD',

    -- Dates
                                            current_period_start TIMESTAMPTZ,
                                            current_period_end TIMESTAMPTZ,
                                            trial_start TIMESTAMPTZ,
                                            trial_end TIMESTAMPTZ,
                                            cancelled_at TIMESTAMPTZ,

    -- External references
                                            stripe_subscription_id VARCHAR(255),
                                            stripe_customer_id VARCHAR(255),

    -- Metadata
                                            metadata JSONB DEFAULT '{}',
                                            created_at TIMESTAMPTZ DEFAULT NOW(),
                                            updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- FUNCTIONS FOR ORGANIZATIONS
-- =====================================================

-- Function to create default workspace for organization
CREATE OR REPLACE FUNCTION create_default_workspace()
RETURNS TRIGGER AS $$
DECLARE
default_workspace_id UUID;
BEGIN
    -- Create default workspace
INSERT INTO workspaces (
    organization_id,
    name,
    slug,
    description,
    is_default
) VALUES (
             NEW.id,
             'General',
             'general',
             'Default workspace for ' || NEW.name,
             TRUE
         ) RETURNING id INTO default_workspace_id;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create default workspace
CREATE TRIGGER create_default_workspace_trigger
    AFTER INSERT ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION create_default_workspace();

-- Function to auto-assign users based on domain
CREATE OR REPLACE FUNCTION auto_assign_user_by_domain()
RETURNS TRIGGER AS $$
DECLARE
user_domain VARCHAR(255);
    org_domain RECORD;
BEGIN
    -- Extract domain from email
    user_domain := split_part(NEW.email, '@', 2);

    -- Check if domain has auto-join enabled
SELECT * INTO org_domain
FROM organization_domains
WHERE domain = user_domain
  AND is_verified = TRUE
  AND auto_join_enabled = TRUE;

IF FOUND THEN
        -- Update user profile with organization
UPDATE user_profiles
SET
    organization_id = org_domain.organization_id,
    role = org_domain.default_role,
    status = 'active'
WHERE id = NEW.id;

-- Add to default workspace
INSERT INTO workspace_members (workspace_id, user_id, role)
SELECT w.id, NEW.id, 'member'
FROM workspaces w
WHERE w.organization_id = org_domain.organization_id
  AND w.is_default = TRUE;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-assignment
CREATE TRIGGER auto_assign_user_by_domain_trigger
    AFTER INSERT ON user_profiles
    FOR EACH ROW
    WHEN (NEW.organization_id IS NULL)
    EXECUTE FUNCTION auto_assign_user_by_domain();

-- =====================================================
-- INDEXES
-- =====================================================

-- Workspaces indexes
CREATE INDEX idx_workspaces_organization_id ON workspaces(organization_id);
CREATE INDEX idx_workspaces_slug ON workspaces(organization_id, slug);
CREATE INDEX idx_workspaces_parent ON workspaces(parent_workspace_id);

-- Workspace members indexes
CREATE INDEX idx_workspace_members_workspace_id ON workspace_members(workspace_id);
CREATE INDEX idx_workspace_members_user_id ON workspace_members(user_id);

-- Teams indexes
CREATE INDEX idx_teams_organization_id ON teams(organization_id);
CREATE INDEX idx_teams_workspace_id ON teams(workspace_id);
CREATE INDEX idx_teams_lead ON teams(team_lead_id);

-- Team members indexes
CREATE INDEX idx_team_members_team_id ON team_members(team_id);
CREATE INDEX idx_team_members_user_id ON team_members(user_id);

-- Organization domains indexes
CREATE INDEX idx_organization_domains_org_id ON organization_domains(organization_id);
CREATE INDEX idx_organization_domains_domain ON organization_domains(domain);

-- Invitations indexes
CREATE INDEX idx_organization_invitations_org_id ON organization_invitations(organization_id);
CREATE INDEX idx_organization_invitations_email ON organization_invitations(email);
CREATE INDEX idx_organization_invitations_token ON organization_invitations(token);
CREATE INDEX idx_organization_invitations_status ON organization_invitations(status);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_workspaces_updated_at BEFORE UPDATE ON workspaces FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_organization_domains_updated_at BEFORE UPDATE ON organization_domains FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_subscription_plans_updated_at BEFORE UPDATE ON subscription_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_organization_subscriptions_updated_at BEFORE UPDATE ON organization_subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();