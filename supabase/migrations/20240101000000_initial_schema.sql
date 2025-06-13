-- =====================================================
-- ENTERPRISE CRM DATABASE SCHEMA
-- Initial Setup with Core Tables
-- Created: 2025-06-13 19:53:08 UTC
-- Author: antowirantoIO
-- =====================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch";

-- =====================================================
-- ENUMS
-- =====================================================

-- User status enum
CREATE TYPE user_status AS ENUM (
    'active',
    'inactive',
    'suspended',
    'pending_verification'
);

-- User role enum
CREATE TYPE user_role AS ENUM (
    'super_admin',
    'admin',
    'manager',
    'sales_rep',
    'support',
    'viewer'
);

-- Contact status enum
CREATE TYPE contact_status AS ENUM (
    'lead',
    'prospect',
    'customer',
    'inactive',
    'lost'
);

-- Company size enum
CREATE TYPE company_size AS ENUM (
    'startup',
    'small',
    'medium',
    'large',
    'enterprise'
);

-- Deal status enum
CREATE TYPE deal_status AS ENUM (
    'open',
    'won',
    'lost',
    'on_hold'
);

-- Deal priority enum
CREATE TYPE deal_priority AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);

-- Activity type enum
CREATE TYPE activity_type AS ENUM (
    'call',
    'email',
    'meeting',
    'task',
    'note',
    'sms',
    'demo',
    'proposal'
);

-- Activity status enum
CREATE TYPE activity_status AS ENUM (
    'pending',
    'completed',
    'cancelled',
    'rescheduled'
);

-- Document type enum
CREATE TYPE document_type AS ENUM (
    'contract',
    'proposal',
    'invoice',
    'presentation',
    'image',
    'pdf',
    'spreadsheet',
    'other'
);

-- Notification type enum
CREATE TYPE notification_type AS ENUM (
    'info',
    'success',
    'warning',
    'error',
    'reminder'
);

-- Integration status enum
CREATE TYPE integration_status AS ENUM (
    'active',
    'inactive',
    'error',
    'pending'
);

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Organizations table
CREATE TABLE organizations (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               name VARCHAR(255) NOT NULL,
                               slug VARCHAR(100) UNIQUE NOT NULL,
                               description TEXT,
                               website VARCHAR(500),
                               logo_url VARCHAR(500),
                               industry VARCHAR(100),
                               size company_size DEFAULT 'small',
                               founded_year INTEGER,
                               headquarters JSONB, -- {country, state, city, address}
                               timezone VARCHAR(50) DEFAULT 'UTC',
                               business_hours JSONB, -- {start_time, end_time, days}
                               settings JSONB DEFAULT '{}', -- Organization-specific settings
                               subscription_plan VARCHAR(50) DEFAULT 'free',
                               subscription_status VARCHAR(20) DEFAULT 'active',
                               billing_email VARCHAR(255),
                               trial_ends_at TIMESTAMPTZ,
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),
                               deleted_at TIMESTAMPTZ
);

-- Users table (extends Supabase auth.users)
CREATE TABLE user_profiles (
                               id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
                               organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
                               email VARCHAR(255) NOT NULL UNIQUE,
                               first_name VARCHAR(100),
                               last_name VARCHAR(100),
                               full_name VARCHAR(255) GENERATED ALWAYS AS (
                                   CASE
                                       WHEN first_name IS NOT NULL AND last_name IS NOT NULL
                                           THEN first_name || ' ' || last_name
                                       WHEN first_name IS NOT NULL
                                           THEN first_name
                                       WHEN last_name IS NOT NULL
                                           THEN last_name
                                       ELSE email
                                       END
                                   ) STORED,
                               avatar_url VARCHAR(500),
                               phone VARCHAR(20),
                               job_title VARCHAR(100),
                               department VARCHAR(100),
                               location JSONB, -- {country, state, city}
                               timezone VARCHAR(50) DEFAULT 'UTC',
                               language VARCHAR(10) DEFAULT 'en',
                               role user_role DEFAULT 'viewer',
                               status user_status DEFAULT 'pending_verification',
                               permissions JSONB DEFAULT '{}', -- Custom permissions
                               preferences JSONB DEFAULT '{}', -- User preferences
                               last_login_at TIMESTAMPTZ,
                               email_verified_at TIMESTAMPTZ,
                               phone_verified_at TIMESTAMPTZ,
                               two_factor_enabled BOOLEAN DEFAULT FALSE,
                               two_factor_secret VARCHAR(255),
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),
                               deleted_at TIMESTAMPTZ
);

-- Contacts table
CREATE TABLE contacts (
                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                          organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                          owner_id UUID REFERENCES user_profiles(id),
                          first_name VARCHAR(100),
                          last_name VARCHAR(100),
                          full_name VARCHAR(255) GENERATED ALWAYS AS (
                              CASE
                                  WHEN first_name IS NOT NULL AND last_name IS NOT NULL
                                      THEN first_name || ' ' || last_name
                                  WHEN first_name IS NOT NULL
                                      THEN first_name
                                  WHEN last_name IS NOT NULL
                                      THEN last_name
                                  ELSE 'Unnamed Contact'
                                  END
                              ) STORED,
                          email VARCHAR(255),
                          phone VARCHAR(20),
                          mobile VARCHAR(20),
                          avatar_url VARCHAR(500),
                          job_title VARCHAR(100),
                          department VARCHAR(100),
                          company_id UUID REFERENCES companies(id),
                          status contact_status DEFAULT 'lead',
                          source VARCHAR(100), -- lead source
                          rating INTEGER CHECK (rating >= 1 AND rating <= 5),

    -- Contact details
                          birthday DATE,
                          address JSONB, -- {street, city, state, country, postal_code}
                          social_profiles JSONB, -- {linkedin, twitter, facebook, etc}

    -- CRM specific
                          lead_score INTEGER DEFAULT 0,
                          lifecycle_stage VARCHAR(50),
                          tags TEXT[], -- array of tags
                          notes TEXT,

    -- Custom fields
                          custom_fields JSONB DEFAULT '{}',

    -- Tracking
                          created_by UUID REFERENCES user_profiles(id),
                          last_contacted_at TIMESTAMPTZ,
                          last_activity_at TIMESTAMPTZ,

    -- Metadata
                          created_at TIMESTAMPTZ DEFAULT NOW(),
                          updated_at TIMESTAMPTZ DEFAULT NOW(),
                          deleted_at TIMESTAMPTZ,

    -- Search vector for full-text search
                          search_vector tsvector GENERATED ALWAYS AS (
                              to_tsvector('english',
                                          coalesce(first_name, '') || ' ' ||
                                          coalesce(last_name, '') || ' ' ||
                                          coalesce(email, '') || ' ' ||
                                          coalesce(phone, '') || ' ' ||
                                          coalesce(job_title, '') || ' ' ||
                                          coalesce(notes, '')
                              )
                              ) STORED
);

-- Companies table
CREATE TABLE companies (
                           id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                           organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                           owner_id UUID REFERENCES user_profiles(id),
                           name VARCHAR(255) NOT NULL,
                           slug VARCHAR(255),
                           description TEXT,
                           website VARCHAR(500),
                           logo_url VARCHAR(500),

    -- Company details
                           industry VARCHAR(100),
                           size company_size DEFAULT 'small',
                           employee_count INTEGER,
                           annual_revenue DECIMAL(15,2),
                           founded_year INTEGER,

    -- Contact information
                           email VARCHAR(255),
                           phone VARCHAR(20),
                           address JSONB, -- {street, city, state, country, postal_code}

    -- Social and online presence
                           social_profiles JSONB, -- {linkedin, twitter, facebook, etc}

    -- CRM specific
                           status VARCHAR(50) DEFAULT 'active',
                           rating INTEGER CHECK (rating >= 1 AND rating <= 5),
                           lead_score INTEGER DEFAULT 0,
                           lifecycle_stage VARCHAR(50),
                           tags TEXT[], -- array of tags

    -- Parent company relationship
                           parent_company_id UUID REFERENCES companies(id),

    -- Custom fields
                           custom_fields JSONB DEFAULT '{}',

    -- Tracking
                           created_by UUID REFERENCES user_profiles(id),
                           last_contacted_at TIMESTAMPTZ,
                           last_activity_at TIMESTAMPTZ,

    -- Metadata
                           created_at TIMESTAMPTZ DEFAULT NOW(),
                           updated_at TIMESTAMPTZ DEFAULT NOW(),
                           deleted_at TIMESTAMPTZ,

    -- Search vector for full-text search
                           search_vector tsvector GENERATED ALWAYS AS (
                               to_tsvector('english',
                                           coalesce(name, '') || ' ' ||
                                           coalesce(description, '') || ' ' ||
                                           coalesce(industry, '') || ' ' ||
                                           coalesce(website, '')
                               )
                               ) STORED
);

-- Add the missing reference to companies in contacts
-- (This needs to be added after companies table is created)
-- ALTER TABLE contacts ADD CONSTRAINT fk_contacts_company
-- FOREIGN KEY (company_id) REFERENCES companies(id);

-- Deal pipelines table
CREATE TABLE deal_pipelines (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                name VARCHAR(255) NOT NULL,
                                description TEXT,
                                is_default BOOLEAN DEFAULT FALSE,
                                position INTEGER NOT NULL DEFAULT 0,
                                created_by UUID REFERENCES user_profiles(id),
                                created_at TIMESTAMPTZ DEFAULT NOW(),
                                updated_at TIMESTAMPTZ DEFAULT NOW(),
                                deleted_at TIMESTAMPTZ
);

-- Deal stages table
CREATE TABLE deal_stages (
                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                             pipeline_id UUID NOT NULL REFERENCES deal_pipelines(id) ON DELETE CASCADE,
                             name VARCHAR(255) NOT NULL,
                             description TEXT,
                             position INTEGER NOT NULL DEFAULT 0,
                             probability DECIMAL(5,2) DEFAULT 0.00 CHECK (probability >= 0 AND probability <= 100),
                             is_closed BOOLEAN DEFAULT FALSE,
                             is_won BOOLEAN DEFAULT FALSE,
                             created_at TIMESTAMPTZ DEFAULT NOW(),
                             updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Deals table
CREATE TABLE deals (
                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                       organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                       pipeline_id UUID NOT NULL REFERENCES deal_pipelines(id),
                       stage_id UUID NOT NULL REFERENCES deal_stages(id),
                       owner_id UUID REFERENCES user_profiles(id),

    -- Deal basic info
                       title VARCHAR(255) NOT NULL,
                       description TEXT,
                       value DECIMAL(15,2) DEFAULT 0.00,
                       currency VARCHAR(3) DEFAULT 'USD',

    -- Relationships
                       contact_id UUID REFERENCES contacts(id),
                       company_id UUID REFERENCES companies(id),

    -- Deal specifics
                       status deal_status DEFAULT 'open',
                       priority deal_priority DEFAULT 'medium',
                       probability DECIMAL(5,2) DEFAULT 0.00 CHECK (probability >= 0 AND probability <= 100),

    -- Important dates
                       expected_close_date DATE,
                       actual_close_date DATE,
                       last_activity_date DATE,

    -- Deal source and tracking
                       source VARCHAR(100), -- lead source
                       tags TEXT[], -- array of tags

    -- Custom fields
                       custom_fields JSONB DEFAULT '{}',

    -- Tracking
                       created_by UUID REFERENCES user_profiles(id),
                       won_at TIMESTAMPTZ,
                       lost_at TIMESTAMPTZ,
                       lost_reason TEXT,

    -- Metadata
                       created_at TIMESTAMPTZ DEFAULT NOW(),
                       updated_at TIMESTAMPTZ DEFAULT NOW(),
                       deleted_at TIMESTAMPTZ,

    -- Search vector for full-text search
                       search_vector tsvector GENERATED ALWAYS AS (
                           to_tsvector('english',
                                       coalesce(title, '') || ' ' ||
                                       coalesce(description, '')
                           )
                           ) STORED
);

-- Activities table
CREATE TABLE activities (
                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                            organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                            owner_id UUID REFERENCES user_profiles(id),

    -- Activity details
                            type activity_type NOT NULL,
                            status activity_status DEFAULT 'pending',
                            title VARCHAR(255) NOT NULL,
                            description TEXT,

    -- Relationships (polymorphic)
                            contact_id UUID REFERENCES contacts(id),
                            company_id UUID REFERENCES companies(id),
                            deal_id UUID REFERENCES deals(id),

    -- Scheduling
                            scheduled_at TIMESTAMPTZ,
                            duration_minutes INTEGER DEFAULT 30,
                            completed_at TIMESTAMPTZ,

    -- Location and participants
                            location VARCHAR(500),
                            participants JSONB, -- Array of participant objects

    -- Communication specific
                            subject VARCHAR(500), -- for emails
                            body TEXT, -- email body or detailed notes

    -- Tracking and metadata
                            is_completed BOOLEAN DEFAULT FALSE,
                            reminder_at TIMESTAMPTZ,

    -- Custom fields
                            custom_fields JSONB DEFAULT '{}',

    -- Metadata
                            created_by UUID REFERENCES user_profiles(id),
                            created_at TIMESTAMPTZ DEFAULT NOW(),
                            updated_at TIMESTAMPTZ DEFAULT NOW(),
                            deleted_at TIMESTAMPTZ,

    -- Search vector for full-text search
                            search_vector tsvector GENERATED ALWAYS AS (
                                to_tsvector('english',
                                            coalesce(title, '') || ' ' ||
                                            coalesce(description, '') || ' ' ||
                                            coalesce(subject, '') || ' ' ||
                                            coalesce(body, '')
                                )
                                ) STORED
);

-- =====================================================
-- INDEXES
-- =====================================================

-- Organizations indexes
CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_subscription ON organizations(subscription_plan, subscription_status);
CREATE INDEX idx_organizations_created_at ON organizations(created_at);

-- User profiles indexes
CREATE INDEX idx_user_profiles_organization_id ON user_profiles(organization_id);
CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);
CREATE INDEX idx_user_profiles_status ON user_profiles(status);
CREATE INDEX idx_user_profiles_full_name ON user_profiles(full_name);
CREATE INDEX idx_user_profiles_created_at ON user_profiles(created_at);

-- Contacts indexes
CREATE INDEX idx_contacts_organization_id ON contacts(organization_id);
CREATE INDEX idx_contacts_owner_id ON contacts(owner_id);
CREATE INDEX idx_contacts_company_id ON contacts(company_id);
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_contacts_phone ON contacts(phone);
CREATE INDEX idx_contacts_status ON contacts(status);
CREATE INDEX idx_contacts_full_name ON contacts(full_name);
CREATE INDEX idx_contacts_created_at ON contacts(created_at);
CREATE INDEX idx_contacts_last_activity ON contacts(last_activity_at);
CREATE INDEX idx_contacts_search_vector ON contacts USING GIN(search_vector);
CREATE INDEX idx_contacts_tags ON contacts USING GIN(tags);

-- Companies indexes
CREATE INDEX idx_companies_organization_id ON companies(organization_id);
CREATE INDEX idx_companies_owner_id ON companies(owner_id);
CREATE INDEX idx_companies_name ON companies(name);
CREATE INDEX idx_companies_slug ON companies(slug);
CREATE INDEX idx_companies_industry ON companies(industry);
CREATE INDEX idx_companies_size ON companies(size);
CREATE INDEX idx_companies_created_at ON companies(created_at);
CREATE INDEX idx_companies_search_vector ON companies USING GIN(search_vector);
CREATE INDEX idx_companies_tags ON companies USING GIN(tags);

-- Deal pipelines indexes
CREATE INDEX idx_deal_pipelines_organization_id ON deal_pipelines(organization_id);
CREATE INDEX idx_deal_pipelines_position ON deal_pipelines(position);

-- Deal stages indexes
CREATE INDEX idx_deal_stages_pipeline_id ON deal_stages(pipeline_id);
CREATE INDEX idx_deal_stages_position ON deal_stages(position);

-- Deals indexes
CREATE INDEX idx_deals_organization_id ON deals(organization_id);
CREATE INDEX idx_deals_pipeline_id ON deals(pipeline_id);
CREATE INDEX idx_deals_stage_id ON deals(stage_id);
CREATE INDEX idx_deals_owner_id ON deals(owner_id);
CREATE INDEX idx_deals_contact_id ON deals(contact_id);
CREATE INDEX idx_deals_company_id ON deals(company_id);
CREATE INDEX idx_deals_status ON deals(status);
CREATE INDEX idx_deals_priority ON deals(priority);
CREATE INDEX idx_deals_value ON deals(value);
CREATE INDEX idx_deals_expected_close_date ON deals(expected_close_date);
CREATE INDEX idx_deals_created_at ON deals(created_at);
CREATE INDEX idx_deals_search_vector ON deals USING GIN(search_vector);
CREATE INDEX idx_deals_tags ON deals USING GIN(tags);

-- Activities indexes
CREATE INDEX idx_activities_organization_id ON activities(organization_id);
CREATE INDEX idx_activities_owner_id ON activities(owner_id);
CREATE INDEX idx_activities_contact_id ON activities(contact_id);
CREATE INDEX idx_activities_company_id ON activities(company_id);
CREATE INDEX idx_activities_deal_id ON activities(deal_id);
CREATE INDEX idx_activities_type ON activities(type);
CREATE INDEX idx_activities_status ON activities(status);
CREATE INDEX idx_activities_scheduled_at ON activities(scheduled_at);
CREATE INDEX idx_activities_completed_at ON activities(completed_at);
CREATE INDEX idx_activities_created_at ON activities(created_at);
CREATE INDEX idx_activities_search_vector ON activities USING GIN(search_vector);

-- Composite indexes for common queries
CREATE INDEX idx_contacts_org_status ON contacts(organization_id, status);
CREATE INDEX idx_companies_org_industry ON companies(organization_id, industry);
CREATE INDEX idx_deals_org_status ON deals(organization_id, status);
CREATE INDEX idx_activities_org_type_status ON activities(organization_id, type, status);

-- =====================================================
-- TRIGGERS FOR UPDATED_AT
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to all tables with updated_at
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_deal_pipelines_updated_at BEFORE UPDATE ON deal_pipelines FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_deals_updated_at BEFORE UPDATE ON deals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_activities_updated_at BEFORE UPDATE ON activities FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON TABLE organizations IS 'Multi-tenant organizations/workspaces';
COMMENT ON TABLE user_profiles IS 'Extended user profiles linked to Supabase auth';
COMMENT ON TABLE contacts IS 'Individual contacts in the CRM';
COMMENT ON TABLE companies IS 'Companies/accounts in the CRM';
COMMENT ON TABLE deal_pipelines IS 'Configurable sales pipelines';
COMMENT ON TABLE deal_stages IS 'Stages within sales pipelines';
COMMENT ON TABLE deals IS 'Sales opportunities/deals';
COMMENT ON TABLE activities IS 'All CRM activities (calls, emails, meetings, etc.)';

COMMENT ON COLUMN contacts.search_vector IS 'Full-text search vector for contacts';
COMMENT ON COLUMN companies.search_vector IS 'Full-text search vector for companies';
COMMENT ON COLUMN deals.search_vector IS 'Full-text search vector for deals';
COMMENT ON COLUMN activities.search_vector IS 'Full-text search vector for activities';