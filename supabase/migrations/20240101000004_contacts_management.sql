-- =====================================================
-- CONTACTS MANAGEMENT MIGRATION
-- Extended contacts features and relationship management
-- Created: 2024-01-01 00:00:04 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- CONTACT SOURCES & CAMPAIGNS
-- =====================================================

-- Contact sources table
CREATE TABLE contact_sources (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Source details
                                 name VARCHAR(255) NOT NULL,
                                 slug VARCHAR(100) NOT NULL,
                                 description TEXT,
                                 type VARCHAR(50), -- website, social, referral, event, import, etc.

    -- Tracking
                                 is_active BOOLEAN DEFAULT TRUE,

    -- Analytics
                                 total_contacts INTEGER DEFAULT 0,
                                 conversion_rate DECIMAL(5,2) DEFAULT 0.00,

    -- Metadata
                                 created_by UUID REFERENCES user_profiles(id),
                                 created_at TIMESTAMPTZ DEFAULT NOW(),
                                 updated_at TIMESTAMPTZ DEFAULT NOW(),

                                 UNIQUE(organization_id, slug)
);

-- Contact lists table (for segmentation)
CREATE TABLE contact_lists (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- List details
                               name VARCHAR(255) NOT NULL,
                               description TEXT,

    -- List type
                               type VARCHAR(50) DEFAULT 'manual', -- manual, smart, imported

    -- Smart list criteria (for dynamic lists)
                               criteria JSONB,

    -- Settings
                               is_active BOOLEAN DEFAULT TRUE,
                               auto_update BOOLEAN DEFAULT FALSE, -- For smart lists

    -- Analytics
                               contact_count INTEGER DEFAULT 0,
                               last_updated_count_at TIMESTAMPTZ,

    -- Metadata
                               created_by UUID REFERENCES user_profiles(id),
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),
                               deleted_at TIMESTAMPTZ
);

-- Contact list members (many-to-many relationship)
CREATE TABLE contact_list_members (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      list_id UUID NOT NULL REFERENCES contact_lists(id) ON DELETE CASCADE,
                                      contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,

    -- Membership details
                                      added_at TIMESTAMPTZ DEFAULT NOW(),
                                      added_by UUID REFERENCES user_profiles(id),

    -- For tracking changes in smart lists
                                      is_manual BOOLEAN DEFAULT TRUE,

                                      UNIQUE(list_id, contact_id)
);

-- =====================================================
-- CONTACT RELATIONSHIPS
-- =====================================================

-- Contact relationships table (who knows whom)
CREATE TABLE contact_relationships (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- The two contacts in relationship
                                       contact_a_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
                                       contact_b_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,

    -- Relationship details
                                       relationship_type VARCHAR(50) NOT NULL, -- colleague, friend, family, business_partner, etc.
                                       description TEXT,

    -- Relationship strength (1-5)
                                       strength INTEGER CHECK (strength >= 1 AND strength <= 5),

    -- Status
                                       is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                       created_by UUID REFERENCES user_profiles(id),
                                       created_at TIMESTAMPTZ DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Prevent duplicate relationships
                                       UNIQUE(contact_a_id, contact_b_id, relationship_type),
    -- Prevent self-relationships
                                       CHECK (contact_a_id != contact_b_id)
    );

-- =====================================================
-- CONTACT INTERACTIONS TRACKING
-- =====================================================

-- Contact interactions table (detailed interaction history)
CREATE TABLE contact_interactions (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                      contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
                                      user_id UUID REFERENCES user_profiles(id),

    -- Interaction details
                                      type VARCHAR(50) NOT NULL, -- email_sent, email_opened, email_clicked, call_made, meeting_attended, etc.
                                      channel VARCHAR(50), -- email, phone, sms, social, in_person, etc.

    -- Content
                                      subject VARCHAR(500),
                                      description TEXT,

    -- External references
                                      email_id VARCHAR(255), -- Reference to email service
                                      campaign_id UUID, -- Reference to campaign

    -- Engagement metrics
                                      duration_seconds INTEGER,
                                      engagement_score INTEGER DEFAULT 0,

    -- Metadata
                                      properties JSONB DEFAULT '{}',
                                      occurred_at TIMESTAMPTZ DEFAULT NOW(),
                                      created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- CONTACT SCORING & LIFECYCLE
-- =====================================================

-- Contact scoring rules table
CREATE TABLE contact_scoring_rules (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Rule details
                                       name VARCHAR(255) NOT NULL,
                                       description TEXT,

    -- Scoring criteria
                                       event_type VARCHAR(50) NOT NULL, -- email_opened, form_submitted, page_visited, etc.
                                       conditions JSONB, -- Additional conditions
                                       score_change INTEGER NOT NULL, -- Can be positive or negative

    -- Rule settings
                                       is_active BOOLEAN DEFAULT TRUE,
                                       max_applications INTEGER, -- How many times this rule can apply to same contact

    -- Metadata
                                       created_by UUID REFERENCES user_profiles(id),
                                       created_at TIMESTAMPTZ DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Contact scores history table
CREATE TABLE contact_score_history (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
                                       scoring_rule_id UUID REFERENCES contact_scoring_rules(id),

    -- Score change details
                                       previous_score INTEGER NOT NULL,
                                       score_change INTEGER NOT NULL,
                                       new_score INTEGER NOT NULL,
                                       reason VARCHAR(255),

    -- Metadata
                                       created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- CONTACT PREFERENCES & COMMUNICATION
-- =====================================================

-- Contact communication preferences
CREATE TABLE contact_communication_preferences (
                                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                                   contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,

    -- Email preferences
                                                   email_opt_in BOOLEAN DEFAULT TRUE,
                                                   email_marketing BOOLEAN DEFAULT TRUE,
                                                   email_newsletters BOOLEAN DEFAULT TRUE,
                                                   email_product_updates BOOLEAN DEFAULT TRUE,

    -- Communication preferences
                                                   preferred_contact_method VARCHAR(20) DEFAULT 'email', -- email, phone, sms
                                                   preferred_contact_time VARCHAR(50), -- morning, afternoon, evening
                                                   timezone VARCHAR(50),

    -- Language preferences
                                                   language VARCHAR(10) DEFAULT 'en',

    -- Do not contact settings
                                                   do_not_call BOOLEAN DEFAULT FALSE,
                                                   do_not_email BOOLEAN DEFAULT FALSE,
                                                   do_not_sms BOOLEAN DEFAULT FALSE,

    -- Unsubscribe tracking
                                                   unsubscribed_at TIMESTAMPTZ,
                                                   unsubscribe_reason TEXT,

    -- Metadata
                                                   updated_at TIMESTAMPTZ DEFAULT NOW(),

                                                   UNIQUE(contact_id)
);

-- =====================================================
-- CONTACT ENRICHMENT & DATA SOURCES
-- =====================================================

-- Contact enrichment data table
CREATE TABLE contact_enrichment_data (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,

    -- Data source
                                         provider VARCHAR(50) NOT NULL, -- clearbit, zoominfo, apollo, etc.

    -- Enriched data
                                         data JSONB NOT NULL,
                                         confidence_score DECIMAL(3,2), -- 0.00 to 1.00

    -- Status
                                         status VARCHAR(20) DEFAULT 'active', -- active, outdated, invalid

    -- Metadata
                                         enriched_at TIMESTAMPTZ DEFAULT NOW(),
                                         expires_at TIMESTAMPTZ,

                                         UNIQUE(contact_id, provider)
);

-- Contact duplicates table (for deduplication)
CREATE TABLE contact_duplicates (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- The contacts that are duplicates
                                    primary_contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
                                    duplicate_contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,

    -- Similarity metrics
                                    similarity_score DECIMAL(3,2), -- 0.00 to 1.00
                                    matching_fields TEXT[], -- email, phone, name, etc.

    -- Merge status
                                    status VARCHAR(20) DEFAULT 'pending', -- pending, merged, ignored
                                    merged_at TIMESTAMPTZ,
                                    merged_by UUID REFERENCES user_profiles(id),

    -- Metadata
                                    detected_at TIMESTAMPTZ DEFAULT NOW(),

                                    UNIQUE(primary_contact_id, duplicate_contact_id)
);

-- =====================================================
-- CONTACT IMPORT/EXPORT
-- =====================================================

-- Contact imports table
CREATE TABLE contact_imports (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Import details
                                 name VARCHAR(255) NOT NULL,
                                 source VARCHAR(100), -- csv, excel, api, integration
                                 file_name VARCHAR(255),
                                 file_path VARCHAR(1000),

    -- Import configuration
                                 field_mapping JSONB, -- How CSV columns map to contact fields
                                 import_settings JSONB DEFAULT '{}',

    -- Status tracking
                                 status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed

    -- Results
                                 total_rows INTEGER DEFAULT 0,
                                 processed_rows INTEGER DEFAULT 0,
                                 successful_imports INTEGER DEFAULT 0,
                                 failed_imports INTEGER DEFAULT 0,
                                 duplicate_skips INTEGER DEFAULT 0,

    -- Error handling
                                 error_details JSONB,

    -- Metadata
                                 started_by UUID REFERENCES user_profiles(id),
                                 started_at TIMESTAMPTZ DEFAULT NOW(),
                                 completed_at TIMESTAMPTZ
);

-- Contact import errors table
CREATE TABLE contact_import_errors (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       import_id UUID NOT NULL REFERENCES contact_imports(id) ON DELETE CASCADE,

    -- Error details
                                       row_number INTEGER NOT NULL,
                                       row_data JSONB,
                                       error_type VARCHAR(50), -- validation, duplicate, missing_required, etc.
                                       error_message TEXT,

    -- Resolution
                                       is_resolved BOOLEAN DEFAULT FALSE,
                                       resolved_at TIMESTAMPTZ,
                                       resolved_by UUID REFERENCES user_profiles(id),

                                       created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- FUNCTIONS FOR CONTACTS
-- =====================================================

-- Function to update contact score
CREATE OR REPLACE FUNCTION update_contact_score(
    contact_uuid UUID,
    event_type_param VARCHAR(50),
    additional_properties JSONB DEFAULT '{}'
)
RETURNS INTEGER AS $$
DECLARE
current_score INTEGER;
    score_change INTEGER := 0;
    new_score INTEGER;
    rule RECORD;
    org_id UUID;
BEGIN
    -- Get contact's organization and current score
SELECT organization_id, lead_score INTO org_id, current_score
FROM contacts WHERE id = contact_uuid;

-- Apply scoring rules
FOR rule IN
SELECT * FROM contact_scoring_rules
WHERE organization_id = org_id
  AND event_type = event_type_param
  AND is_active = TRUE
    LOOP
        -- Check if rule conditions are met
        IF rule.conditions IS NULL OR
           jsonb_extract_path(additional_properties, variadic string_to_array(rule.conditions->>'field', '.')) = rule.conditions->'value' THEN

            -- Check max applications
            IF rule.max_applications IS NULL OR
               (SELECT COUNT(*) FROM contact_score_history
                WHERE contact_id = contact_uuid AND scoring_rule_id = rule.id) < rule.max_applications THEN

                score_change := score_change + rule.score_change;

-- Record score change
INSERT INTO contact_score_history (
    contact_id, scoring_rule_id, previous_score, score_change, new_score, reason
) VALUES (
             contact_uuid, rule.id, current_score, rule.score_change,
             current_score + score_change, rule.name
         );
END IF;
END IF;
END LOOP;

    -- Update contact score
    new_score := GREATEST(0, current_score + score_change); -- Don't allow negative scores

UPDATE contacts
SET lead_score = new_score, last_activity_at = NOW()
WHERE id = contact_uuid;

RETURN new_score;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-create communication preferences
CREATE OR REPLACE FUNCTION create_contact_preferences()
RETURNS TRIGGER AS $$
BEGIN
INSERT INTO contact_communication_preferences (contact_id)
VALUES (NEW.id);

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for creating communication preferences
CREATE TRIGGER create_contact_preferences_trigger
    AFTER INSERT ON contacts
    FOR EACH ROW
    EXECUTE FUNCTION create_contact_preferences();

-- Function to update contact list counts
CREATE OR REPLACE FUNCTION update_contact_list_count()
RETURNS TRIGGER AS $$
DECLARE
list_uuid UUID;
BEGIN
    -- Get the list ID
    IF TG_OP = 'INSERT' THEN
        list_uuid := NEW.list_id;
    ELSIF TG_OP = 'DELETE' THEN
        list_uuid := OLD.list_id;
END IF;

    -- Update the count
UPDATE contact_lists
SET
    contact_count = (SELECT COUNT(*) FROM contact_list_members WHERE list_id = list_uuid),
    last_updated_count_at = NOW()
WHERE id = list_uuid;

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating list counts
CREATE TRIGGER update_contact_list_count_trigger
    AFTER INSERT OR DELETE ON contact_list_members
    FOR EACH ROW
    EXECUTE FUNCTION update_contact_list_count();

-- Function to detect duplicate contacts
CREATE OR REPLACE FUNCTION detect_contact_duplicates()
RETURNS TRIGGER AS $$
DECLARE
potential_duplicate RECORD;
    similarity DECIMAL(3,2);
BEGIN
    -- Look for potential duplicates based on email or phone
FOR potential_duplicate IN
SELECT id FROM contacts
WHERE organization_id = NEW.organization_id
  AND id != NEW.id
        AND (
            (email IS NOT NULL AND email = NEW.email) OR
            (phone IS NOT NULL AND phone = NEW.phone) OR
            (similarity(full_name, NEW.full_name) > 0.8)
        )
    LOOP
        -- Calculate similarity score
        similarity := 0.0;

-- Email match = 40% similarity
IF (SELECT email FROM contacts WHERE id = potential_duplicate.id) = NEW.email THEN
            similarity := similarity + 0.4;
END IF;

        -- Phone match = 30% similarity
        IF (SELECT phone FROM contacts WHERE id = potential_duplicate.id) = NEW.phone THEN
            similarity := similarity + 0.3;
END IF;

        -- Name similarity = 30%
        similarity := similarity + (similarity(
            (SELECT full_name FROM contacts WHERE id = potential_duplicate.id),
            NEW.full_name
        ) * 0.3);

        -- Insert duplicate record if similarity > 70%
        IF similarity > 0.7 THEN
            INSERT INTO contact_duplicates (
                organization_id, primary_contact_id, duplicate_contact_id,
                similarity_score, matching_fields
            ) VALUES (
                NEW.organization_id, potential_duplicate.id, NEW.id,
                similarity, ARRAY['email', 'phone', 'name']
            ) ON CONFLICT (primary_contact_id, duplicate_contact_id) DO NOTHING;
END IF;
END LOOP;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for duplicate detection
CREATE TRIGGER detect_contact_duplicates_trigger
    AFTER INSERT ON contacts
    FOR EACH ROW
    EXECUTE FUNCTION detect_contact_duplicates();

-- =====================================================
-- INDEXES
-- =====================================================

-- Contact sources indexes
CREATE INDEX idx_contact_sources_organization_id ON contact_sources(organization_id);
CREATE INDEX idx_contact_sources_slug ON contact_sources(organization_id, slug);
CREATE INDEX idx_contact_sources_type ON contact_sources(type);

-- Contact lists indexes
CREATE INDEX idx_contact_lists_organization_id ON contact_lists(organization_id);
CREATE INDEX idx_contact_lists_type ON contact_lists(type);
CREATE INDEX idx_contact_lists_active ON contact_lists(is_active);

-- Contact list members indexes
CREATE INDEX idx_contact_list_members_list_id ON contact_list_members(list_id);
CREATE INDEX idx_contact_list_members_contact_id ON contact_list_members(contact_id);

-- Contact relationships indexes
CREATE INDEX idx_contact_relationships_org_id ON contact_relationships(organization_id);
CREATE INDEX idx_contact_relationships_contact_a ON contact_relationships(contact_a_id);
CREATE INDEX idx_contact_relationships_contact_b ON contact_relationships(contact_b_id);
CREATE INDEX idx_contact_relationships_type ON contact_relationships(relationship_type);

-- Contact interactions indexes
CREATE INDEX idx_contact_interactions_org_id ON contact_interactions(organization_id);
CREATE INDEX idx_contact_interactions_contact_id ON contact_interactions(contact_id);
CREATE INDEX idx_contact_interactions_type ON contact_interactions(type);
CREATE INDEX idx_contact_interactions_occurred_at ON contact_interactions(occurred_at);

-- Contact scoring indexes
CREATE INDEX idx_contact_scoring_rules_org_id ON contact_scoring_rules(organization_id);
CREATE INDEX idx_contact_scoring_rules_event_type ON contact_scoring_rules(event_type);
CREATE INDEX idx_contact_score_history_contact_id ON contact_score_history(contact_id);

-- Contact enrichment indexes
CREATE INDEX idx_contact_enrichment_contact_id ON contact_enrichment_data(contact_id);
CREATE INDEX idx_contact_enrichment_provider ON contact_enrichment_data(provider);

-- Contact duplicates indexes
CREATE INDEX idx_contact_duplicates_org_id ON contact_duplicates(organization_id);
CREATE INDEX idx_contact_duplicates_primary ON contact_duplicates(primary_contact_id);
CREATE INDEX idx_contact_duplicates_status ON contact_duplicates(status);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_contact_sources_updated_at BEFORE UPDATE ON contact_sources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_contact_lists_updated_at BEFORE UPDATE ON contact_lists FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_contact_relationships_updated_at BEFORE UPDATE ON contact_relationships FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_contact_scoring_rules_updated_at BEFORE UPDATE ON contact_scoring_rules FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_contact_communication_preferences_updated_at BEFORE UPDATE ON contact_communication_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();