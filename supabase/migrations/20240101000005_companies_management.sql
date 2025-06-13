-- =====================================================
-- COMPANIES MANAGEMENT MIGRATION
-- Extended company features and relationship management
-- Created: 2024-01-01 00:00:05 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- COMPANY HIERARCHIES & RELATIONSHIPS
-- =====================================================

-- Company relationships table (partnerships, subsidiaries, etc.)
CREATE TABLE company_relationships (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- The two companies in relationship
                                       company_a_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
                                       company_b_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,

    -- Relationship details
                                       relationship_type VARCHAR(50) NOT NULL, -- parent, subsidiary, partner, vendor, customer, competitor
                                       description TEXT,

    -- Relationship metadata
                                       started_at DATE,
                                       ended_at DATE,
                                       is_active BOOLEAN DEFAULT TRUE,

    -- Business value
                                       annual_value DECIMAL(15,2),
                                       currency VARCHAR(3) DEFAULT 'USD',

    -- Metadata
                                       created_by UUID REFERENCES user_profiles(id),
                                       created_at TIMESTAMPTZ DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Prevent duplicate relationships
                                       UNIQUE(company_a_id, company_b_id, relationship_type),
    -- Prevent self-relationships
                                       CHECK (company_a_id != company_b_id)
    );

-- =====================================================
-- COMPANY LOCATIONS & OFFICES
-- =====================================================

-- Company locations table
CREATE TABLE company_locations (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,

    -- Location details
                                   name VARCHAR(255), -- Office name (e.g., "New York HQ", "London Branch")
                                   type VARCHAR(50) DEFAULT 'office', -- headquarters, office, branch, warehouse, store

    -- Address details
                                   address_line_1 VARCHAR(255),
                                   address_line_2 VARCHAR(255),
                                   city VARCHAR(100),
                                   state VARCHAR(100),
                                   postal_code VARCHAR(20),
                                   country VARCHAR(100),

    -- Coordinates
                                   latitude DECIMAL(10, 8),
                                   longitude DECIMAL(11, 8),

    -- Contact information
                                   phone VARCHAR(20),
                                   email VARCHAR(255),

    -- Location metadata
                                   is_headquarters BOOLEAN DEFAULT FALSE,
                                   is_active BOOLEAN DEFAULT TRUE,
                                   employee_count INTEGER,

    -- Metadata
                                   created_by UUID REFERENCES user_profiles(id),
                                   created_at TIMESTAMPTZ DEFAULT NOW(),
                                   updated_at TIMESTAMPTZ DEFAULT NOW(),
                                   deleted_at TIMESTAMPTZ
);

-- =====================================================
-- COMPANY FINANCIALS & METRICS
-- =====================================================

-- Company financial records table
CREATE TABLE company_financials (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,

    -- Financial period
                                    fiscal_year INTEGER NOT NULL,
                                    fiscal_quarter INTEGER CHECK (fiscal_quarter >= 1 AND fiscal_quarter <= 4),
                                    period_start DATE,
                                    period_end DATE,

    -- Revenue metrics
                                    revenue DECIMAL(15,2),
                                    gross_profit DECIMAL(15,2),
                                    net_income DECIMAL(15,2),
                                    ebitda DECIMAL(15,2),

    -- Other financial metrics
                                    total_assets DECIMAL(15,2),
                                    total_liabilities DECIMAL(15,2),
                                    equity DECIMAL(15,2),
                                    cash_flow DECIMAL(15,2),

    -- Employee metrics
                                    employee_count INTEGER,

    -- Currency
                                    currency VARCHAR(3) DEFAULT 'USD',

    -- Data source
                                    source VARCHAR(50), -- manual, api, financial_service
                                    confidence_level VARCHAR(20) DEFAULT 'medium', -- low, medium, high

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW(),

                                    UNIQUE(company_id, fiscal_year, fiscal_quarter)
);

-- =====================================================
-- COMPANY TECHNOLOGIES & TOOLS
-- =====================================================

-- Technologies table (what technologies companies use)
CREATE TABLE technologies (
                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Technology details
                              name VARCHAR(255) NOT NULL UNIQUE,
                              slug VARCHAR(100) NOT NULL UNIQUE,
                              description TEXT,
                              category VARCHAR(100), -- crm, marketing, analytics, development, etc.
                              vendor VARCHAR(255),
                              website VARCHAR(500),

    -- Technology metadata
                              logo_url VARCHAR(500),
                              is_active BOOLEAN DEFAULT TRUE,

                              created_at TIMESTAMPTZ DEFAULT NOW(),
                              updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Company technologies (what tech stack each company uses)
CREATE TABLE company_technologies (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
                                      technology_id UUID NOT NULL REFERENCES technologies(id) ON DELETE CASCADE,

    -- Usage details
                                      confidence_level VARCHAR(20) DEFAULT 'medium', -- low, medium, high, confirmed
                                      source VARCHAR(50), -- manual, scraped, api, integration

    -- Usage metadata
                                      started_using_at DATE,
                                      stopped_using_at DATE,
                                      is_currently_using BOOLEAN DEFAULT TRUE,

    -- Additional data
                                      usage_context TEXT, -- How they're using it
                                      spend_estimate DECIMAL(10,2), -- Estimated annual spend

    -- Metadata
                                      detected_at TIMESTAMPTZ DEFAULT NOW(),
                                      created_by UUID REFERENCES user_profiles(id),

                                      UNIQUE(company_id, technology_id)
);

-- =====================================================
-- COMPANY NEWS & SIGNALS
-- =====================================================

-- Company news/signals table (funding, acquisitions, hiring, etc.)
CREATE TABLE company_signals (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,

    -- Signal details
                                 type VARCHAR(50) NOT NULL, -- funding, acquisition, ipo, hiring, layoffs, new_product, etc.
                                 title VARCHAR(500) NOT NULL,
                                 description TEXT,

    -- Signal metadata
                                 amount DECIMAL(15,2), -- For funding, acquisition amounts
                                 currency VARCHAR(3) DEFAULT 'USD',

    -- Source information
                                 source_url VARCHAR(1000),
                                 source_name VARCHAR(255),

    -- Dates
                                 signal_date DATE,

    -- Relevance scoring
                                 relevance_score INTEGER DEFAULT 0, -- 0-100

    -- Status
                                 is_verified BOOLEAN DEFAULT FALSE,
                                 is_relevant BOOLEAN DEFAULT TRUE,

    -- Metadata
                                 created_at TIMESTAMPTZ DEFAULT NOW(),
                                 updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- COMPANY ENRICHMENT & DATA SOURCES
-- =====================================================

-- Company enrichment data table
CREATE TABLE company_enrichment_data (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,

    -- Data source
                                         provider VARCHAR(50) NOT NULL, -- clearbit, crunchbase, linkedin, etc.

    -- Enriched data (flexible JSON structure)
                                         data JSONB NOT NULL,
                                         confidence_score DECIMAL(3,2), -- 0.00 to 1.00

    -- Status
                                         status VARCHAR(20) DEFAULT 'active', -- active, outdated, invalid

    -- Metadata
                                         enriched_at TIMESTAMPTZ DEFAULT NOW(),
                                         expires_at TIMESTAMPTZ,

                                         UNIQUE(company_id, provider)
);

-- Company duplicates table (for deduplication)
CREATE TABLE company_duplicates (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- The companies that are duplicates
                                    primary_company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
                                    duplicate_company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,

    -- Similarity metrics
                                    similarity_score DECIMAL(3,2), -- 0.00 to 1.00
                                    matching_fields TEXT[], -- name, website, domain, phone, etc.

    -- Merge status
                                    status VARCHAR(20) DEFAULT 'pending', -- pending, merged, ignored
                                    merged_at TIMESTAMPTZ,
                                    merged_by UUID REFERENCES user_profiles(id),

    -- Metadata
                                    detected_at TIMESTAMPTZ DEFAULT NOW(),

                                    UNIQUE(primary_company_id, duplicate_company_id)
);

-- =====================================================
-- COMPANY SEGMENTS & CATEGORIZATION
-- =====================================================

-- Company segments table (for organizing companies)
CREATE TABLE company_segments (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Segment details
                                  name VARCHAR(255) NOT NULL,
                                  description TEXT,
                                  color VARCHAR(7), -- Hex color code

    -- Segmentation criteria
                                  criteria JSONB, -- Conditions for auto-assignment

    -- Settings
                                  is_active BOOLEAN DEFAULT TRUE,
                                  auto_assign BOOLEAN DEFAULT FALSE,

    -- Analytics
                                  company_count INTEGER DEFAULT 0,

    -- Metadata
                                  created_by UUID REFERENCES user_profiles(id),
                                  created_at TIMESTAMPTZ DEFAULT NOW(),
                                  updated_at TIMESTAMPTZ DEFAULT NOW(),
                                  deleted_at TIMESTAMPTZ,

                                  UNIQUE(organization_id, name)
);

-- Company segment assignments
CREATE TABLE company_segment_assignments (
                                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                             company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
                                             segment_id UUID NOT NULL REFERENCES company_segments(id) ON DELETE CASCADE,

    -- Assignment details
                                             assigned_at TIMESTAMPTZ DEFAULT NOW(),
                                             assigned_by UUID REFERENCES user_profiles(id),
                                             is_manual BOOLEAN DEFAULT TRUE,

                                             UNIQUE(company_id, segment_id)
);

-- =====================================================
-- FUNCTIONS FOR COMPANIES
-- =====================================================

-- Function to update company segment counts
CREATE OR REPLACE FUNCTION update_company_segment_count()
RETURNS TRIGGER AS $$
DECLARE
segment_uuid UUID;
BEGIN
    -- Get the segment ID
    IF TG_OP = 'INSERT' THEN
        segment_uuid := NEW.segment_id;
    ELSIF TG_OP = 'DELETE' THEN
        segment_uuid := OLD.segment_id;
END IF;

    -- Update the count
UPDATE company_segments
SET company_count = (
    SELECT COUNT(*)
    FROM company_segment_assignments
    WHERE segment_id = segment_uuid
)
WHERE id = segment_uuid;

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating segment counts
CREATE TRIGGER update_company_segment_count_trigger
    AFTER INSERT OR DELETE ON company_segment_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_company_segment_count();

-- Function to detect duplicate companies
CREATE OR REPLACE FUNCTION detect_company_duplicates()
RETURNS TRIGGER AS $$
DECLARE
potential_duplicate RECORD;
    similarity DECIMAL(3,2);
    domain_a VARCHAR(255);
    domain_b VARCHAR(255);
BEGIN
    -- Extract domain from website for comparison
    domain_a := regexp_replace(
        regexp_replace(NEW.website, '^https?://(www\.)?', ''),
        '/.*$', ''
    );

    -- Look for potential duplicates
FOR potential_duplicate IN
SELECT id, name, website, phone, email FROM companies
WHERE organization_id = NEW.organization_id
  AND id != NEW.id
        AND (
            similarity(name, NEW.name) > 0.8 OR
            (website IS NOT NULL AND NEW.website IS NOT NULL) OR
            (phone IS NOT NULL AND phone = NEW.phone) OR
            (email IS NOT NULL AND email = NEW.email)
        )
    LOOP
        similarity := 0.0;

-- Name similarity = 40%
similarity := similarity + (similarity(potential_duplicate.name, NEW.name) * 0.4);

        -- Website/domain similarity = 35%
        IF potential_duplicate.website IS NOT NULL AND NEW.website IS NOT NULL THEN
            domain_b := regexp_replace(
                regexp_replace(potential_duplicate.website, '^https?://(www\.)?', ''),
                '/.*$', ''
            );

            IF domain_a = domain_b THEN
                similarity := similarity + 0.35;
END IF;
END IF;

        -- Phone match = 15%
        IF potential_duplicate.phone = NEW.phone THEN
            similarity := similarity + 0.15;
END IF;

        -- Email match = 10%
        IF potential_duplicate.email = NEW.email THEN
            similarity := similarity + 0.10;
END IF;

        -- Insert duplicate record if similarity > 70%
        IF similarity > 0.7 THEN
            INSERT INTO company_duplicates (
                organization_id, primary_company_id, duplicate_company_id,
                similarity_score, matching_fields
            ) VALUES (
                NEW.organization_id, potential_duplicate.id, NEW.id,
                similarity, ARRAY['name', 'website', 'phone', 'email']
            ) ON CONFLICT (primary_company_id, duplicate_company_id) DO NOTHING;
END IF;
END LOOP;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for duplicate detection
CREATE TRIGGER detect_company_duplicates_trigger
    AFTER INSERT ON companies
    FOR EACH ROW
    EXECUTE FUNCTION detect_company_duplicates();

-- Function to auto-assign companies to segments
CREATE OR REPLACE FUNCTION auto_assign_company_segments()
RETURNS TRIGGER AS $$
DECLARE
segment RECORD;
BEGIN
    -- Check each auto-assign segment
FOR segment IN
SELECT id, criteria FROM company_segments
WHERE organization_id = NEW.organization_id
  AND auto_assign = TRUE
  AND is_active = TRUE
    LOOP
        -- Simple criteria evaluation (can be extended)
        -- For now, check industry and size
        IF (segment.criteria->>'industry' IS NULL OR
            segment.criteria->>'industry' = NEW.industry) AND
           (segment.criteria->>'size' IS NULL OR
            segment.criteria->>'size' = NEW.size::TEXT) THEN

INSERT INTO company_segment_assignments (
    company_id, segment_id, assigned_by, is_manual
) VALUES (
    NEW.id, segment.id, auth.uid(), FALSE
    ) ON CONFLICT (company_id, segment_id) DO NOTHING;
END IF;
END LOOP;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-assignment
CREATE TRIGGER auto_assign_company_segments_trigger
    AFTER INSERT ON companies
    FOR EACH ROW
    EXECUTE FUNCTION auto_assign_company_segments();

-- =====================================================
-- INDEXES
-- =====================================================

-- Company relationships indexes
CREATE INDEX idx_company_relationships_org_id ON company_relationships(organization_id);
CREATE INDEX idx_company_relationships_company_a ON company_relationships(company_a_id);
CREATE INDEX idx_company_relationships_company_b ON company_relationships(company_b_id);
CREATE INDEX idx_company_relationships_type ON company_relationships(relationship_type);

-- Company locations indexes
CREATE INDEX idx_company_locations_company_id ON company_locations(company_id);
CREATE INDEX idx_company_locations_type ON company_locations(type);
CREATE INDEX idx_company_locations_country ON company_locations(country);
CREATE INDEX idx_company_locations_coordinates ON company_locations(latitude, longitude);

-- Company financials indexes
CREATE INDEX idx_company_financials_company_id ON company_financials(company_id);
CREATE INDEX idx_company_financials_fiscal_year ON company_financials(fiscal_year);
CREATE INDEX idx_company_financials_revenue ON company_financials(revenue);

-- Technologies indexes
CREATE INDEX idx_technologies_slug ON technologies(slug);
CREATE INDEX idx_technologies_category ON technologies(category);

-- Company technologies indexes
CREATE INDEX idx_company_technologies_company_id ON company_technologies(company_id);
CREATE INDEX idx_company_technologies_technology_id ON company_technologies(technology_id);
CREATE INDEX idx_company_technologies_currently_using ON company_technologies(is_currently_using);

-- Company signals indexes
CREATE INDEX idx_company_signals_company_id ON company_signals(company_id);
CREATE INDEX idx_company_signals_type ON company_signals(type);
CREATE INDEX idx_company_signals_signal_date ON company_signals(signal_date);
CREATE INDEX idx_company_signals_relevance ON company_signals(relevance_score);

-- Company enrichment indexes
CREATE INDEX idx_company_enrichment_company_id ON company_enrichment_data(company_id);
CREATE INDEX idx_company_enrichment_provider ON company_enrichment_data(provider);

-- Company segments indexes
CREATE INDEX idx_company_segments_organization_id ON company_segments(organization_id);
CREATE INDEX idx_company_segment_assignments_company_id ON company_segment_assignments(company_id);
CREATE INDEX idx_company_segment_assignments_segment_id ON company_segment_assignments(segment_id);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_company_relationships_updated_at BEFORE UPDATE ON company_relationships FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_company_locations_updated_at BEFORE UPDATE ON company_locations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_company_financials_updated_at BEFORE UPDATE ON company_financials FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_technologies_updated_at BEFORE UPDATE ON technologies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_company_signals_updated_at BEFORE UPDATE ON company_signals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_company_segments_updated_at BEFORE UPDATE ON company_segments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();