-- =====================================================
-- SEARCH INDEXES MIGRATION
-- Advanced search capabilities and full-text indexing
-- Created: 2025-06-13 20:32:55 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- FULL-TEXT SEARCH CONFIGURATION
-- =====================================================

-- Create custom text search configuration
CREATE TEXT SEARCH CONFIGURATION crm_search (COPY = english);

-- Add custom dictionaries for CRM-specific terms
CREATE TEXT SEARCH DICTIONARY crm_dict (
    TEMPLATE = simple,
    STOPWORDS = english
);

-- =====================================================
-- SEARCH VECTORS UPDATE (Add missing ones)
-- =====================================================

-- Update contacts search vector to include more fields
ALTER TABLE contacts
DROP COLUMN IF EXISTS search_vector CASCADE;

ALTER TABLE contacts
    ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('crm_search', coalesce(first_name, '')), 'A') ||
        setweight(to_tsvector('crm_search', coalesce(last_name, '')), 'A') ||
        setweight(to_tsvector('crm_search', coalesce(full_name, '')), 'A') ||
        setweight(to_tsvector('crm_search', coalesce(email, '')), 'B') ||
        setweight(to_tsvector('crm_search', coalesce(phone, '')), 'B') ||
        setweight(to_tsvector('crm_search', coalesce(job_title, '')), 'C') ||
        setweight(to_tsvector('crm_search', coalesce(description, '')), 'D') ||
        setweight(to_tsvector('crm_search', coalesce(array_to_string(tags, ' '), '')), 'C')
        ) STORED;

-- Update companies search vector
ALTER TABLE companies
DROP COLUMN IF EXISTS search_vector CASCADE;

ALTER TABLE companies
    ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('crm_search', coalesce(name, '')), 'A') ||
        setweight(to_tsvector('crm_search', coalesce(website, '')), 'B') ||
        setweight(to_tsvector('crm_search', coalesce(industry, '')), 'B') ||
        setweight(to_tsvector('crm_search', coalesce(description, '')), 'C') ||
        setweight(to_tsvector('crm_search', coalesce(address, '')), 'D') ||
        setweight(to_tsvector('crm_search', coalesce(array_to_string(tags, ' '), '')), 'C')
        ) STORED;

-- Update deals search vector
ALTER TABLE deals
DROP COLUMN IF EXISTS search_vector CASCADE;

ALTER TABLE deals
    ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('crm_search', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('crm_search', coalesce(description, '')), 'C') ||
        setweight(to_tsvector('crm_search', coalesce(array_to_string(tags, ' '), '')), 'C')
        ) STORED;

-- Update activities search vector
ALTER TABLE activities
DROP COLUMN IF EXISTS search_vector CASCADE;

ALTER TABLE activities
    ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('crm_search', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('crm_search', coalesce(description, '')), 'C') ||
        setweight(to_tsvector('crm_search', coalesce(outcome, '')), 'D')
        ) STORED;

-- =====================================================
-- ADVANCED SEARCH TABLES
-- =====================================================

-- Global search index table (unified search across all entities)
CREATE TABLE global_search_index (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Indexed entity details
                                     entity_type VARCHAR(50) NOT NULL,
                                     entity_id UUID NOT NULL,

    -- Searchable content
                                     title VARCHAR(500) NOT NULL,
                                     subtitle VARCHAR(500),
                                     description TEXT,

    -- Search vector
                                     search_vector tsvector,

    -- Metadata for search results
                                     metadata JSONB DEFAULT '{}',
                                     url_path VARCHAR(1000), -- Deep link to the entity

    -- Boost factors for relevance
                                     boost_factor DECIMAL(3,2) DEFAULT 1.0,

    -- Entity status
                                     is_active BOOLEAN DEFAULT TRUE,

    -- Timestamps
                                     indexed_at TIMESTAMPTZ DEFAULT NOW(),
                                     last_updated TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
                                     UNIQUE(organization_id, entity_type, entity_id)
);

-- Search queries table (for analytics and suggestions)
CREATE TABLE search_queries (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                user_id UUID REFERENCES user_profiles(id),

    -- Query details
                                query_text TEXT NOT NULL,
                                query_type VARCHAR(50) DEFAULT 'global', -- global, contacts, companies, deals, activities

    -- Search filters
                                filters JSONB DEFAULT '{}',
                                entity_types TEXT[] DEFAULT '{}',

    -- Search results
                                results_count INTEGER DEFAULT 0,
                                results_entities JSONB DEFAULT '[]', -- Array of {entity_type, entity_id, score}

    -- User interaction
                                clicked_result_entity_type VARCHAR(50),
                                clicked_result_entity_id UUID,
                                clicked_position INTEGER,

    -- Search performance
                                search_time_ms INTEGER,

    -- Search context
                                search_source VARCHAR(50) DEFAULT 'main_search', -- main_search, quick_search, global_command
                                page_context VARCHAR(100),

    -- Search outcome
                                was_successful BOOLEAN,
                                refinement_needed BOOLEAN DEFAULT FALSE,

    -- Metadata
                                session_id VARCHAR(255),
                                ip_address INET,
                                user_agent TEXT,
                                searched_at TIMESTAMPTZ DEFAULT NOW()
);

-- Search suggestions table
CREATE TABLE search_suggestions (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Suggestion details
                                    suggestion_text VARCHAR(255) NOT NULL,
                                    suggestion_type VARCHAR(50) DEFAULT 'query', -- query, entity, filter

    -- Suggestion context
                                    entity_type VARCHAR(50), -- If suggesting a specific entity type
                                    category VARCHAR(100),

    -- Suggestion targeting
                                    user_roles user_role[],

    -- Suggestion statistics
                                    search_count INTEGER DEFAULT 0,
                                    click_count INTEGER DEFAULT 0,
                                    success_rate DECIMAL(5,2) DEFAULT 0.00,

    -- Suggestion settings
                                    is_active BOOLEAN DEFAULT TRUE,
                                    auto_generated BOOLEAN DEFAULT TRUE,

    -- Metadata
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    last_used_at TIMESTAMPTZ,

                                    UNIQUE(organization_id, suggestion_text)
);

-- =====================================================
-- SEARCH ANALYTICS
-- =====================================================

-- Search analytics table
CREATE TABLE search_analytics (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Analytics period
                                  date DATE NOT NULL,

    -- Search volume metrics
                                  total_searches INTEGER DEFAULT 0,
                                  unique_searchers INTEGER DEFAULT 0,

    -- Search performance metrics
                                  average_search_time_ms INTEGER DEFAULT 0,
                                  zero_result_searches INTEGER DEFAULT 0,
                                  successful_searches INTEGER DEFAULT 0,

    -- Popular searches
                                  top_queries JSONB DEFAULT '{}', -- {query: count}
                                  top_entity_types JSONB DEFAULT '{}', -- {entity_type: search_count}

    -- Search patterns
                                  peak_search_hour INTEGER, -- Hour with most searches (0-23)
                                  search_sources JSONB DEFAULT '{}', -- {source: count}

    -- User engagement
                                  average_results_per_search DECIMAL(5,2) DEFAULT 0,
                                  click_through_rate DECIMAL(5,2) DEFAULT 0,

    -- Metadata
                                  calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                  UNIQUE(organization_id, date)
);

-- =====================================================
-- ADVANCED SEARCH FUNCTIONS
-- =====================================================

-- Function to perform global search
CREATE OR REPLACE FUNCTION perform_global_search(
    org_uuid UUID,
    query_text_param TEXT,
    entity_types_param TEXT[] DEFAULT '{}',
    user_uuid UUID DEFAULT NULL,
    limit_param INTEGER DEFAULT 20,
    offset_param INTEGER DEFAULT 0
)
RETURNS TABLE (
    entity_type VARCHAR(50),
    entity_id UUID,
    title VARCHAR(500),
    subtitle VARCHAR(500),
    description TEXT,
    relevance_score REAL,
    metadata JSONB,
    url_path VARCHAR(1000)
) AS $$
DECLARE
search_query_id UUID;
    start_time TIMESTAMPTZ;
    end_time TIMESTAMPTZ;
    search_time_ms INTEGER;
    results_count INTEGER;
BEGIN
    start_time := NOW();

    -- Log the search query
INSERT INTO search_queries (
    organization_id,
    user_id,
    query_text,
    query_type,
    entity_types
) VALUES (
             org_uuid,
             user_uuid,
             query_text_param,
             'global',
             entity_types_param
         ) RETURNING id INTO search_query_id;

-- Perform the search
RETURN QUERY
SELECT
    gsi.entity_type,
    gsi.entity_id,
    gsi.title,
    gsi.subtitle,
    gsi.description,
    ts_rank(gsi.search_vector, plainto_tsquery('crm_search', query_text_param)) * gsi.boost_factor as relevance_score,
    gsi.metadata,
    gsi.url_path
FROM global_search_index gsi
WHERE gsi.organization_id = org_uuid
  AND gsi.is_active = TRUE
  AND gsi.search_vector @@ plainto_tsquery('crm_search', query_text_param)
  AND (array_length(entity_types_param, 1) IS NULL OR gsi.entity_type = ANY(entity_types_param))
ORDER BY relevance_score DESC
    LIMIT limit_param
OFFSET offset_param;

-- Get results count
GET DIAGNOSTICS results_count = ROW_COUNT;

end_time := NOW();
    search_time_ms := EXTRACT(EPOCH FROM (end_time - start_time)) * 1000;

    -- Update search query with results
UPDATE search_queries
SET
    results_count = results_count,
    search_time_ms = search_time_ms,
    was_successful = (results_count > 0)
WHERE id = search_query_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update global search index for an entity
CREATE OR REPLACE FUNCTION update_global_search_index(
    entity_type_param VARCHAR(50),
    entity_id_param UUID,
    org_uuid UUID
)
RETURNS VOID AS $$
DECLARE
entity_record RECORD;
    title_val VARCHAR(500);
    subtitle_val VARCHAR(500);
    description_val TEXT;
    metadata_val JSONB := '{}';
    url_path_val VARCHAR(1000);
    search_vector_val tsvector;
BEGIN
    -- Get entity data based on type
CASE entity_type_param
        WHEN 'contacts' THEN
SELECT * INTO entity_record FROM contacts WHERE id = entity_id_param;
IF FOUND THEN
                title_val := entity_record.full_name;
                subtitle_val := entity_record.email;
                description_val := entity_record.description;
                url_path_val := '/contacts/' || entity_id_param;
                metadata_val := jsonb_build_object(
                    'job_title', entity_record.job_title,
                    'status', entity_record.status,
                    'company_id', entity_record.company_id
                );
                search_vector_val := entity_record.search_vector;
END IF;

WHEN 'companies' THEN
SELECT * INTO entity_record FROM companies WHERE id = entity_id_param;
IF FOUND THEN
                title_val := entity_record.name;
                subtitle_val := entity_record.website;
                description_val := entity_record.description;
                url_path_val := '/companies/' || entity_id_param;
                metadata_val := jsonb_build_object(
                    'industry', entity_record.industry,
                    'size', entity_record.size,
                    'type', entity_record.company_type
                );
                search_vector_val := entity_record.search_vector;
END IF;

WHEN 'deals' THEN
SELECT * INTO entity_record FROM deals WHERE id = entity_id_param;
IF FOUND THEN
                title_val := entity_record.title;
                subtitle_val := 'Deal • ' || entity_record.value::TEXT;
                description_val := entity_record.description;
                url_path_val := '/deals/' || entity_id_param;
                metadata_val := jsonb_build_object(
                    'status', entity_record.status,
                    'stage_id', entity_record.stage_id,
                    'value', entity_record.value,
                    'contact_id', entity_record.contact_id,
                    'company_id', entity_record.company_id
                );
                search_vector_val := entity_record.search_vector;
END IF;

WHEN 'activities' THEN
SELECT * INTO entity_record FROM activities WHERE id = entity_id_param;
IF FOUND THEN
                title_val := entity_record.title;
                subtitle_val := entity_record.type::TEXT || ' • ' ||
                              COALESCE(entity_record.scheduled_at::TEXT, 'No date');
                description_val := entity_record.description;
                url_path_val := '/activities/' || entity_id_param;
                metadata_val := jsonb_build_object(
                    'type', entity_record.type,
                    'status', entity_record.status,
                    'contact_id', entity_record.contact_id,
                    'company_id', entity_record.company_id,
                    'deal_id', entity_record.deal_id
                );
                search_vector_val := entity_record.search_vector;
END IF;
END CASE;

    -- Update or insert into global search index
    IF entity_record IS NOT NULL THEN
        INSERT INTO global_search_index (
            organization_id,
            entity_type,
            entity_id,
            title,
            subtitle,
            description,
            search_vector,
            metadata,
            url_path,
            last_updated
        ) VALUES (
            org_uuid,
            entity_type_param,
            entity_id_param,
            title_val,
            subtitle_val,
            description_val,
            search_vector_val,
            metadata_val,
            url_path_val,
            NOW()
        )
        ON CONFLICT (organization_id, entity_type, entity_id)
        DO UPDATE SET
    title = EXCLUDED.title,
                          subtitle = EXCLUDED.subtitle,
                          description = EXCLUDED.description,
                          search_vector = EXCLUDED.search_vector,
                          metadata = EXCLUDED.metadata,
                          url_path = EXCLUDED.url_path,
                          last_updated = NOW();
END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to update search suggestions based on query patterns
CREATE OR REPLACE FUNCTION update_search_suggestions(
    org_uuid UUID
)
RETURNS INTEGER AS $$
DECLARE
suggestion_count INTEGER := 0;
    query_record RECORD;
BEGIN
    -- Generate suggestions from popular search queries (last 30 days)
FOR query_record IN
SELECT
    query_text,
    COUNT(*) as search_count,
    COUNT(*) FILTER (WHERE was_successful = TRUE) as success_count
FROM search_queries
WHERE organization_id = org_uuid
  AND searched_at >= NOW() - INTERVAL '30 days'
  AND LENGTH(query_text) >= 3
GROUP BY query_text
HAVING COUNT(*) >= 3 -- Minimum threshold
ORDER BY COUNT(*) DESC
    LIMIT 50
    LOOP
INSERT INTO search_suggestions (
    organization_id,
    suggestion_text,
    suggestion_type,
    search_count,
    success_rate,
    auto_generated
) VALUES (
    org_uuid,
    query_record.query_text,
    'query',
    query_record.search_count,
    CASE
    WHEN query_record.search_count > 0
    THEN (query_record.success_count::DECIMAL / query_record.search_count) * 100
    ELSE 0
    END,
    TRUE
    )
ON CONFLICT (organization_id, suggestion_text)
    DO UPDATE SET
    search_count = EXCLUDED.search_count,
           success_rate = EXCLUDED.success_rate,
           last_used_at = NOW();

suggestion_count := suggestion_count + 1;
END LOOP;

RETURN suggestion_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SEARCH INDEXES (GIN for full-text search)
-- =====================================================

-- Create GIN indexes for full-text search vectors
CREATE INDEX idx_contacts_search_vector ON contacts USING GIN(search_vector);
CREATE INDEX idx_companies_search_vector ON companies USING GIN(search_vector);
CREATE INDEX idx_deals_search_vector ON deals USING GIN(search_vector);
CREATE INDEX idx_activities_search_vector ON activities USING GIN(search_vector);
CREATE INDEX idx_products_search_vector ON products USING GIN(search_vector);
CREATE INDEX idx_knowledge_articles_search_vector ON knowledge_articles USING GIN(search_vector);

-- Global search index
CREATE INDEX idx_global_search_index_organization_id ON global_search_index(organization_id);
CREATE INDEX idx_global_search_index_entity_type ON global_search_index(entity_type);
CREATE INDEX idx_global_search_index_search_vector ON global_search_index USING GIN(search_vector);
CREATE INDEX idx_global_search_index_active ON global_search_index(is_active) WHERE is_active = TRUE;

-- Search queries indexes
CREATE INDEX idx_search_queries_organization_id ON search_queries(organization_id);
CREATE INDEX idx_search_queries_user_id ON search_queries(user_id);
CREATE INDEX idx_search_queries_query_text ON search_queries USING GIN(to_tsvector('english', query_text));
CREATE INDEX idx_search_queries_searched_at ON search_queries(searched_at);
CREATE INDEX idx_search_queries_successful ON search_queries(was_successful);

-- Search suggestions indexes
CREATE INDEX idx_search_suggestions_organization_id ON search_suggestions(organization_id);
CREATE INDEX idx_search_suggestions_text ON search_suggestions(suggestion_text);
CREATE INDEX idx_search_suggestions_type ON search_suggestions(suggestion_type);
CREATE INDEX idx_search_suggestions_active ON search_suggestions(is_active) WHERE is_active = TRUE;

-- Search analytics indexes
CREATE INDEX idx_search_analytics_organization_id ON search_analytics(organization_id);
CREATE INDEX idx_search_analytics_date ON search_analytics(date);

-- =====================================================
-- TRIGRAM INDEXES (for fuzzy matching)
-- =====================================================

-- Enable pg_trgm extension for fuzzy matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Trigram indexes for fuzzy search
CREATE INDEX idx_contacts_name_trigram ON contacts USING GIN(full_name gin_trgm_ops);
CREATE INDEX idx_contacts_email_trigram ON contacts USING GIN(email gin_trgm_ops);
CREATE INDEX idx_companies_name_trigram ON companies USING GIN(name gin_trgm_ops);
CREATE INDEX idx_deals_title_trigram ON deals USING GIN(title gin_trgm_ops);

-- =====================================================
-- SEARCH TRIGGERS
-- =====================================================

-- Trigger to update global search index when entities change
CREATE OR REPLACE FUNCTION trigger_update_global_search_index()
RETURNS TRIGGER AS $$
DECLARE
org_id UUID;
    entity_type_val VARCHAR(50);
BEGIN
    -- Determine entity type and organization ID
CASE TG_TABLE_NAME
        WHEN 'contacts' THEN
            entity_type_val := 'contacts';
            org_id := COALESCE(NEW.organization_id, OLD.organization_id);
WHEN 'companies' THEN
            entity_type_val := 'companies';
            org_id := COALESCE(NEW.organization_id, OLD.organization_id);
WHEN 'deals' THEN
            entity_type_val := 'deals';
            org_id := COALESCE(NEW.organization_id, OLD.organization_id);
WHEN 'activities' THEN
            entity_type_val := 'activities';
            org_id := COALESCE(NEW.organization_id, OLD.organization_id);
ELSE
            RETURN COALESCE(NEW, OLD);
END CASE;

    -- Handle different trigger operations
    IF TG_OP = 'DELETE' THEN
DELETE FROM global_search_index
WHERE organization_id = org_id
  AND entity_type = entity_type_val
  AND entity_id = OLD.id;
RETURN OLD;
ELSE
        PERFORM update_global_search_index(entity_type_val, NEW.id, org_id);
RETURN NEW;
END IF;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for all searchable entities
CREATE TRIGGER contacts_search_index_trigger
    AFTER INSERT OR UPDATE OR DELETE ON contacts
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_global_search_index();

CREATE TRIGGER companies_search_index_trigger
    AFTER INSERT OR UPDATE OR DELETE ON companies
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_global_search_index();

CREATE TRIGGER deals_search_index_trigger
    AFTER INSERT OR UPDATE OR DELETE ON deals
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_global_search_index();

CREATE TRIGGER activities_search_index_trigger
    AFTER INSERT OR UPDATE OR DELETE ON activities
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_global_search_index();

-- =====================================================
-- SEARCH ANALYTICS TRIGGERS
-- =====================================================

-- Function to update search analytics
CREATE OR REPLACE FUNCTION update_search_analytics_trigger()
RETURNS TRIGGER AS $$
DECLARE
analytics_date DATE;
BEGIN
    analytics_date := NEW.searched_at::DATE;

    -- Update daily search analytics
INSERT INTO search_analytics (
    organization_id,
    date,
    total_searches,
    unique_searchers,
    zero_result_searches,
    successful_searches
) VALUES (
             NEW.organization_id,
             analytics_date,
             1,
             CASE WHEN NEW.user_id IS NOT NULL THEN 1 ELSE 0 END,
             CASE WHEN NEW.results_count = 0 THEN 1 ELSE 0 END,
             CASE WHEN NEW.was_successful THEN 1 ELSE 0 END
         )
    ON CONFLICT (organization_id, date)
    DO UPDATE SET
    total_searches = search_analytics.total_searches + 1,
               unique_searchers = search_analytics.unique_searchers +
               CASE WHEN NEW.user_id IS NOT NULL AND NOT EXISTS (
               SELECT 1 FROM search_queries
               WHERE organization_id = NEW.organization_id
               AND user_id = NEW.user_id
               AND searched_at::DATE = analytics_date
               AND id < NEW.id
               ) THEN 1 ELSE 0 END,
        zero_result_searches = search_analytics.zero_result_searches +
            CASE WHEN NEW.results_count = 0 THEN 1 ELSE 0 END,
        successful_searches = search_analytics.successful_searches +
            CASE WHEN NEW.was_successful THEN 1 ELSE 0 END,
        calculated_at = NOW();

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for search analytics
CREATE TRIGGER search_analytics_trigger
    AFTER INSERT ON search_queries
    FOR EACH ROW
    EXECUTE FUNCTION update_search_analytics_trigger();

-- =====================================================
-- POPULATE INITIAL SEARCH INDEX
-- =====================================================

-- Function to populate global search index for existing data
CREATE OR REPLACE FUNCTION populate_global_search_index(
    org_uuid UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
total_indexed INTEGER := 0;
    entity_record RECORD;
BEGIN
    -- Index contacts
FOR entity_record IN
SELECT id, organization_id FROM contacts
WHERE (org_uuid IS NULL OR organization_id = org_uuid)
  AND deleted_at IS NULL
    LOOP
        PERFORM update_global_search_index('contacts', entity_record.id, entity_record.organization_id);
total_indexed := total_indexed + 1;
END LOOP;

    -- Index companies
FOR entity_record IN
SELECT id, organization_id FROM companies
WHERE (org_uuid IS NULL OR organization_id = org_uuid)
  AND deleted_at IS NULL
    LOOP
        PERFORM update_global_search_index('companies', entity_record.id, entity_record.organization_id);
total_indexed := total_indexed + 1;
END LOOP;

    -- Index deals
FOR entity_record IN
SELECT id, organization_id FROM deals
WHERE (org_uuid IS NULL OR organization_id = org_uuid)
  AND deleted_at IS NULL
    LOOP
        PERFORM update_global_search_index('deals', entity_record.id, entity_record.organization_id);
total_indexed := total_indexed + 1;
END LOOP;

    -- Index activities
FOR entity_record IN
SELECT id, organization_id FROM activities
WHERE (org_uuid IS NULL OR organization_id = org_uuid)
  AND deleted_at IS NULL
    LOOP
        PERFORM update_global_search_index('activities', entity_record.id, entity_record.organization_id);
total_indexed := total_indexed + 1;
END LOOP;

RETURN total_indexed;
END;
$$ LANGUAGE plpgsql;