-- =====================================================
-- KNOWLEDGE BASE MIGRATION
-- Comprehensive knowledge management and documentation system
-- Created: 2025-06-13 20:29:09 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- KNOWLEDGE BASE STRUCTURE
-- =====================================================

-- Knowledge base categories table
CREATE TABLE knowledge_base_categories (
                                           id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                           organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                           parent_category_id UUID REFERENCES knowledge_base_categories(id) ON DELETE CASCADE,

    -- Category details
                                           name VARCHAR(255) NOT NULL,
                                           slug VARCHAR(255) NOT NULL,
                                           description TEXT,

    -- Category hierarchy
                                           path VARCHAR(2000), -- Materialized path for performance
                                           depth INTEGER DEFAULT 0,

    -- Category display
                                           icon VARCHAR(50),
                                           color VARCHAR(7), -- Hex color
                                           cover_image_url VARCHAR(500),

    -- Category settings
                                           is_public BOOLEAN DEFAULT TRUE,
                                           is_featured BOOLEAN DEFAULT FALSE,
                                           sort_order INTEGER DEFAULT 0,

    -- SEO settings
                                           meta_title VARCHAR(255),
                                           meta_description TEXT,

    -- Access control
                                           visibility VARCHAR(20) DEFAULT 'organization', -- public, organization, team, private
                                           allowed_roles user_role[],
                                           allowed_users UUID[],

    -- Category statistics
                                           article_count INTEGER DEFAULT 0,
                                           view_count INTEGER DEFAULT 0,

    -- Metadata
                                           created_by UUID REFERENCES user_profiles(id),
                                           created_at TIMESTAMPTZ DEFAULT NOW(),
                                           updated_at TIMESTAMPTZ DEFAULT NOW(),
                                           deleted_at TIMESTAMPTZ,

                                           UNIQUE(organization_id, parent_category_id, slug),
                                           CHECK (depth >= 0 AND depth <= 5) -- Prevent too deep nesting
);

-- Enhanced knowledge articles table (extending the basic one from collaboration)
DROP TABLE IF EXISTS knowledge_articles;
CREATE TABLE knowledge_articles (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                    category_id UUID REFERENCES knowledge_base_categories(id),

    -- Article identification
                                    title VARCHAR(255) NOT NULL,
                                    slug VARCHAR(255) NOT NULL,
                                    excerpt TEXT,

    -- Article content
                                    content TEXT NOT NULL,
                                    content_format VARCHAR(20) DEFAULT 'markdown', -- markdown, html, plain_text
                                    table_of_contents JSONB, -- Auto-generated TOC

    -- Article type and purpose
                                    article_type VARCHAR(50) DEFAULT 'general', -- general, how_to, faq, troubleshooting, api_docs, policy
                                    difficulty_level VARCHAR(20) DEFAULT 'beginner', -- beginner, intermediate, advanced, expert

    -- Article metadata
                                    tags TEXT[] DEFAULT '{}',
                                    keywords TEXT[] DEFAULT '{}', -- For search optimization
                                    external_links TEXT[] DEFAULT '{}',

    -- Article status workflow
                                    status VARCHAR(20) DEFAULT 'draft', -- draft, review, approved, published, archived, outdated
                                    workflow_stage VARCHAR(50), -- For custom approval workflows

    -- Publishing settings
                                    is_featured BOOLEAN DEFAULT FALSE,
                                    is_pinned BOOLEAN DEFAULT FALSE,
                                    featured_image_url VARCHAR(500),

    -- Article visibility and access
                                    visibility VARCHAR(20) DEFAULT 'organization', -- public, organization, team, private
                                    password_protected BOOLEAN DEFAULT FALSE,
                                    access_password_hash VARCHAR(255),
                                    allowed_roles user_role[],
                                    allowed_users UUID[],

    -- Content relationships
                                    related_articles UUID[] DEFAULT '{}',
                                    prerequisite_articles UUID[] DEFAULT '{}',

    -- Article metrics
                                    view_count INTEGER DEFAULT 0,
                                    unique_views INTEGER DEFAULT 0,
                                    helpful_votes INTEGER DEFAULT 0,
                                    not_helpful_votes INTEGER DEFAULT 0,
                                    comment_count INTEGER DEFAULT 0,

    -- Reading analytics
                                    average_read_time_seconds INTEGER DEFAULT 0,
                                    bounce_rate DECIMAL(5,2) DEFAULT 0,

    -- SEO optimization
                                    meta_title VARCHAR(255),
                                    meta_description TEXT,
                                    structured_data JSONB, -- Schema.org structured data

    -- Content versioning
                                    version INTEGER DEFAULT 1,
                                    version_notes TEXT,

    -- Collaborative editing
                                    is_collaborative BOOLEAN DEFAULT FALSE,
                                    edit_permissions VARCHAR(20) DEFAULT 'author_only', -- author_only, category_editors, anyone

    -- Content scheduling
                                    scheduled_publish_at TIMESTAMPTZ,
                                    published_at TIMESTAMPTZ,

    -- Content maintenance
                                    review_required BOOLEAN DEFAULT FALSE,
                                    review_due_date DATE,
                                    last_reviewed_at TIMESTAMPTZ,
                                    last_reviewed_by UUID REFERENCES user_profiles(id),

    -- External integration
                                    external_source_url VARCHAR(1000),
                                    sync_with_external BOOLEAN DEFAULT FALSE,
                                    last_synced_at TIMESTAMPTZ,

    -- Content approval workflow
                                    submitted_for_review_at TIMESTAMPTZ,
                                    submitted_by UUID REFERENCES user_profiles(id),
                                    reviewed_by UUID REFERENCES user_profiles(id),
                                    reviewed_at TIMESTAMPTZ,
                                    review_comments TEXT,
                                    approved_by UUID REFERENCES user_profiles(id),
                                    approved_at TIMESTAMPTZ,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    last_edited_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW(),
                                    deleted_at TIMESTAMPTZ,

    -- Search vector for full-text search
                                    search_vector tsvector GENERATED ALWAYS AS (
                                        to_tsvector('english',
                                                    coalesce(title, '') || ' ' ||
                                                    coalesce(excerpt, '') || ' ' ||
                                                    coalesce(content, '') || ' ' ||
                                                    coalesce(array_to_string(keywords, ' '), '')
                                        )
                                        ) STORED,

                                    UNIQUE(organization_id, slug)
);

-- =====================================================
-- ARTICLE VERSIONING & COLLABORATION
-- =====================================================

-- Article versions table (complete version history)
CREATE TABLE article_versions (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  article_id UUID NOT NULL REFERENCES knowledge_articles(id) ON DELETE CASCADE,

    -- Version details
                                  version_number INTEGER NOT NULL,
                                  version_name VARCHAR(100),

    -- Version content snapshot
                                  title VARCHAR(255) NOT NULL,
                                  content TEXT NOT NULL,
                                  excerpt TEXT,

    -- Version metadata
                                  change_summary TEXT,
                                  change_type VARCHAR(50) DEFAULT 'edit', -- edit, minor_edit, major_edit, restructure

    -- Version status
                                  is_published BOOLEAN DEFAULT FALSE,
                                  is_current BOOLEAN DEFAULT FALSE,

    -- Version creator
                                  created_by UUID REFERENCES user_profiles(id),
                                  created_at TIMESTAMPTZ DEFAULT NOW(),

                                  UNIQUE(article_id, version_number)
);

-- Article contributors table
CREATE TABLE article_contributors (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      article_id UUID NOT NULL REFERENCES knowledge_articles(id) ON DELETE CASCADE,
                                      user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Contribution details
                                      contribution_type VARCHAR(50) DEFAULT 'editor', -- author, editor, reviewer, translator
                                      contribution_count INTEGER DEFAULT 0,

    -- Permissions
                                      can_edit BOOLEAN DEFAULT FALSE,
                                      can_review BOOLEAN DEFAULT FALSE,
                                      can_publish BOOLEAN DEFAULT FALSE,

    -- Contribution tracking
                                      first_contribution_at TIMESTAMPTZ DEFAULT NOW(),
                                      last_contribution_at TIMESTAMPTZ DEFAULT NOW(),

                                      UNIQUE(article_id, user_id)
);

-- Article comments and discussions
CREATE TABLE article_comments (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  article_id UUID NOT NULL REFERENCES knowledge_articles(id) ON DELETE CASCADE,
                                  parent_comment_id UUID REFERENCES article_comments(id) ON DELETE CASCADE,
                                  author_id UUID NOT NULL REFERENCES user_profiles(id),

    -- Comment content
                                  content TEXT NOT NULL,
                                  content_format VARCHAR(20) DEFAULT 'markdown',

    -- Comment type
                                  comment_type VARCHAR(50) DEFAULT 'general', -- general, suggestion, question, correction, praise

    -- Comment status
                                  status VARCHAR(20) DEFAULT 'published', -- draft, published, hidden, resolved
                                  is_pinned BOOLEAN DEFAULT FALSE,

    -- Comment voting
                                  helpful_votes INTEGER DEFAULT 0,
                                  total_votes INTEGER DEFAULT 0,

    -- Comment moderation
                                  is_flagged BOOLEAN DEFAULT FALSE,
                                  flag_reason VARCHAR(100),
                                  moderated_by UUID REFERENCES user_profiles(id),
                                  moderated_at TIMESTAMPTZ,

    -- Metadata
                                  created_at TIMESTAMPTZ DEFAULT NOW(),
                                  updated_at TIMESTAMPTZ DEFAULT NOW(),
                                  deleted_at TIMESTAMPTZ
);

-- =====================================================
-- KNOWLEDGE BASE TEMPLATES & DOCUMENTATION TYPES
-- =====================================================

-- Article templates table
CREATE TABLE article_templates (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE, -- NULL for global templates

    -- Template details
                                   name VARCHAR(255) NOT NULL,
                                   description TEXT,
                                   template_type VARCHAR(50) NOT NULL, -- how_to, faq, policy, api_reference, troubleshooting

    -- Template content
                                   title_template VARCHAR(255),
                                   content_template TEXT NOT NULL,

    -- Template structure
                                   sections JSONB NOT NULL, -- Template sections and prompts
                                   required_fields JSONB DEFAULT '{}',
                                   optional_fields JSONB DEFAULT '{}',

    -- Template settings
                                   category_id UUID REFERENCES knowledge_base_categories(id),
                                   default_tags TEXT[] DEFAULT '{}',
                                   default_visibility VARCHAR(20) DEFAULT 'organization',

    -- Template usage
                                   usage_count INTEGER DEFAULT 0,
                                   is_featured BOOLEAN DEFAULT FALSE,

    -- Template status
                                   is_active BOOLEAN DEFAULT TRUE,
                                   is_system_template BOOLEAN DEFAULT FALSE,

    -- Metadata
                                   created_by UUID REFERENCES user_profiles(id),
                                   created_at TIMESTAMPTZ DEFAULT NOW(),
                                   updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- SEARCH & DISCOVERY
-- =====================================================

-- Knowledge base search queries table (for analytics)
CREATE TABLE kb_search_queries (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                   user_id UUID REFERENCES user_profiles(id),

    -- Search details
                                   query_text TEXT NOT NULL,
                                   search_type VARCHAR(50) DEFAULT 'full_text', -- full_text, category, tag, title_only

    -- Search filters
                                   filters JSONB DEFAULT '{}',

    -- Search results
                                   results_count INTEGER DEFAULT 0,
                                   clicked_result_id UUID REFERENCES knowledge_articles(id),
                                   clicked_position INTEGER, -- Position of clicked result

    -- Search context
                                   search_location VARCHAR(50), -- header, category_page, article_page, help_widget
                                   user_agent TEXT,

    -- Search outcome
                                   was_helpful BOOLEAN,
                                   found_answer BOOLEAN,

    -- Metadata
                                   searched_at TIMESTAMPTZ DEFAULT NOW()
);

-- Popular searches and suggestions
CREATE TABLE kb_search_suggestions (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Suggestion details
                                       suggestion_text VARCHAR(255) NOT NULL,
                                       search_count INTEGER DEFAULT 0,

    -- Suggestion targeting
                                       category_id UUID REFERENCES knowledge_base_categories(id),
                                       suggested_articles UUID[] DEFAULT '{}',

    -- Suggestion settings
                                       is_active BOOLEAN DEFAULT TRUE,
                                       auto_generated BOOLEAN DEFAULT TRUE,

    -- Metadata
                                       created_at TIMESTAMPTZ DEFAULT NOW(),
                                       last_searched_at TIMESTAMPTZ,

                                       UNIQUE(organization_id, suggestion_text)
);

-- =====================================================
-- ANALYTICS & INSIGHTS
-- =====================================================

-- Knowledge base analytics table
CREATE TABLE kb_analytics (
                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                              organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Analytics period
                              date DATE NOT NULL,

    -- Content metrics
                              total_articles INTEGER DEFAULT 0,
                              published_articles INTEGER DEFAULT 0,
                              draft_articles INTEGER DEFAULT 0,

    -- Usage metrics
                              total_views INTEGER DEFAULT 0,
                              unique_visitors INTEGER DEFAULT 0,
                              total_searches INTEGER DEFAULT 0,
                              successful_searches INTEGER DEFAULT 0, -- Searches that led to article clicks

    -- Top performing content
                              top_articles JSONB DEFAULT '{}', -- {article_id: view_count}
                              top_categories JSONB DEFAULT '{}', -- {category_id: view_count}
                              top_search_terms JSONB DEFAULT '{}', -- {search_term: count}

    -- Content health metrics
                              outdated_articles INTEGER DEFAULT 0,
                              articles_needing_review INTEGER DEFAULT 0,
                              helpful_vote_ratio DECIMAL(5,2) DEFAULT 0,

    -- User engagement
                              average_time_on_page_seconds INTEGER DEFAULT 0,
                              bounce_rate DECIMAL(5,2) DEFAULT 0,
                              comment_activity INTEGER DEFAULT 0,

    -- Metadata
                              calculated_at TIMESTAMPTZ DEFAULT NOW(),

                              UNIQUE(organization_id, date)
);

-- Article view tracking
CREATE TABLE article_views (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               article_id UUID NOT NULL REFERENCES knowledge_articles(id) ON DELETE CASCADE,
                               user_id UUID REFERENCES user_profiles(id),

    -- View details
                               session_id VARCHAR(255),
                               ip_address INET,
                               user_agent TEXT,

    -- View context
                               referrer_url VARCHAR(1000),
                               search_query TEXT,

    -- Reading behavior
                               time_spent_seconds INTEGER DEFAULT 0,
                               scroll_percentage INTEGER DEFAULT 0, -- How much of article was read

    -- Engagement
                               voted_helpful BOOLEAN,
                               left_comment BOOLEAN DEFAULT FALSE,

    -- Geographic data
                               country VARCHAR(100),
                               city VARCHAR(100),

    -- Metadata
                               viewed_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- HELP WIDGETS & INTEGRATION
-- =====================================================

-- Help widgets table (embeddable help components)
CREATE TABLE help_widgets (
                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                              organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Widget details
                              name VARCHAR(255) NOT NULL,
                              description TEXT,
                              widget_type VARCHAR(50) NOT NULL, -- search_box, faq_popup, article_suggestions, contact_form

    -- Widget configuration
                              config JSONB NOT NULL DEFAULT '{}',
                              styling JSONB DEFAULT '{}',

    -- Widget content
                              featured_articles UUID[] DEFAULT '{}',
                              featured_categories UUID[] DEFAULT '{}',
                              custom_content TEXT,

    -- Widget targeting
                              target_pages TEXT[] DEFAULT '{}', -- URL patterns where widget should appear
                              target_user_segments JSONB DEFAULT '{}',

    -- Widget behavior
                              trigger_event VARCHAR(50) DEFAULT 'page_load', -- page_load, scroll, exit_intent, time_delay
                              trigger_delay_seconds INTEGER DEFAULT 0,

    -- Widget display
                              position VARCHAR(50) DEFAULT 'bottom_right', -- bottom_right, bottom_left, center, custom
                              is_collapsible BOOLEAN DEFAULT TRUE,
                              auto_hide_after_seconds INTEGER,

    -- Widget status
                              is_active BOOLEAN DEFAULT TRUE,

    -- Usage analytics
                              impression_count INTEGER DEFAULT 0,
                              interaction_count INTEGER DEFAULT 0,
                              conversion_count INTEGER DEFAULT 0, -- Successful help sessions

    -- Metadata
                              created_by UUID REFERENCES user_profiles(id),
                              created_at TIMESTAMPTZ DEFAULT NOW(),
                              updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Widget interactions tracking
CREATE TABLE widget_interactions (
                                     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                     widget_id UUID NOT NULL REFERENCES help_widgets(id) ON DELETE CASCADE,
                                     user_id UUID REFERENCES user_profiles(id),

    -- Interaction details
                                     interaction_type VARCHAR(50) NOT NULL, -- view, click, search, submit, close
                                     interaction_data JSONB DEFAULT '{}',

    -- Session information
                                     session_id VARCHAR(255),
                                     page_url VARCHAR(1000),

    -- Outcome tracking
                                     was_helpful BOOLEAN,
                                     led_to_article_view BOOLEAN DEFAULT FALSE,
                                     led_to_contact BOOLEAN DEFAULT FALSE,

    -- Metadata
                                     occurred_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- FUNCTIONS FOR KNOWLEDGE BASE
-- =====================================================

-- Function to update category path
CREATE OR REPLACE FUNCTION update_kb_category_path()
RETURNS TRIGGER AS $$
DECLARE
parent_path VARCHAR(2000);
    parent_depth INTEGER;
BEGIN
    -- Calculate path and depth
    IF NEW.parent_category_id IS NOT NULL THEN
SELECT path, depth INTO parent_path, parent_depth
FROM knowledge_base_categories
WHERE id = NEW.parent_category_id;

NEW.path := COALESCE(parent_path, '') || '/' || NEW.slug;
        NEW.depth := COALESCE(parent_depth, 0) + 1;
ELSE
        NEW.path := NEW.slug;
        NEW.depth := 0;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating category paths
CREATE TRIGGER update_kb_category_path_trigger
    BEFORE INSERT OR UPDATE ON knowledge_base_categories
                         FOR EACH ROW
                         EXECUTE FUNCTION update_kb_category_path();

-- Function to update article metrics
CREATE OR REPLACE FUNCTION update_article_metrics()
RETURNS TRIGGER AS $$
DECLARE
article_uuid UUID;
    unique_viewer BOOLEAN;
BEGIN
    article_uuid := NEW.article_id;

    -- Check if this is a unique view (same user hasn't viewed in last 24 hours)
    unique_viewer := NOT EXISTS (
        SELECT 1 FROM article_views
        WHERE article_id = article_uuid
        AND user_id = NEW.user_id
        AND viewed_at > NOW() - INTERVAL '24 hours'
        AND id != NEW.id
    );

    -- Update article view counts
UPDATE knowledge_articles
SET
    view_count = view_count + 1,
    unique_views = unique_views + CASE WHEN unique_viewer THEN 1 ELSE 0 END
WHERE id = article_uuid;

-- Update category view count
UPDATE knowledge_base_categories
SET view_count = view_count + 1
WHERE id = (SELECT category_id FROM knowledge_articles WHERE id = article_uuid);

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating article metrics
CREATE TRIGGER update_article_metrics_trigger
    AFTER INSERT ON article_views
    FOR EACH ROW
    EXECUTE FUNCTION update_article_metrics();

-- Function to update category article count
CREATE OR REPLACE FUNCTION update_category_article_count()
RETURNS TRIGGER AS $$
DECLARE
category_uuid UUID;
    old_category_uuid UUID;
BEGIN
    -- Handle INSERT
    IF TG_OP = 'INSERT' THEN
        category_uuid := NEW.category_id;
        IF category_uuid IS NOT NULL THEN
UPDATE knowledge_base_categories
SET article_count = article_count + 1
WHERE id = category_uuid;
END IF;
RETURN NEW;
END IF;

    -- Handle UPDATE
    IF TG_OP = 'UPDATE' THEN
        old_category_uuid := OLD.category_id;
        category_uuid := NEW.category_id;

        -- Decrease count from old category
        IF old_category_uuid IS NOT NULL AND old_category_uuid != category_uuid THEN
UPDATE knowledge_base_categories
SET article_count = article_count - 1
WHERE id = old_category_uuid;
END IF;

        -- Increase count for new category
        IF category_uuid IS NOT NULL AND old_category_uuid != category_uuid THEN
UPDATE knowledge_base_categories
SET article_count = article_count + 1
WHERE id = category_uuid;
END IF;

RETURN NEW;
END IF;

    -- Handle DELETE
    IF TG_OP = 'DELETE' THEN
        category_uuid := OLD.category_id;
        IF category_uuid IS NOT NULL THEN
UPDATE knowledge_base_categories
SET article_count = article_count - 1
WHERE id = category_uuid;
END IF;
RETURN OLD;
END IF;

RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating category article counts
CREATE TRIGGER update_category_article_count_trigger
    AFTER INSERT OR UPDATE OR DELETE ON knowledge_articles
    FOR EACH ROW
    EXECUTE FUNCTION update_category_article_count();

-- Function to search knowledge base
CREATE OR REPLACE FUNCTION search_knowledge_base(
    org_uuid UUID,
    search_query TEXT,
    user_uuid UUID DEFAULT NULL,
    category_filter UUID DEFAULT NULL,
    limit_results INTEGER DEFAULT 20
)
RETURNS TABLE (
    article_id UUID,
    title VARCHAR(255),
    excerpt TEXT,
    category_name VARCHAR(255),
    relevance_score REAL,
    view_count INTEGER
) AS $$
BEGIN
    -- Log the search query
INSERT INTO kb_search_queries (
    organization_id,
    user_id,
    query_text,
    search_type
) VALUES (
             org_uuid,
             user_uuid,
             search_query,
             'full_text'
         );

-- Perform the search
RETURN QUERY
SELECT
    ka.id as article_id,
    ka.title,
    ka.excerpt,
    kbc.name as category_name,
    ts_rank(ka.search_vector, plainto_tsquery('english', search_query)) as relevance_score,
    ka.view_count
FROM knowledge_articles ka
         LEFT JOIN knowledge_base_categories kbc ON ka.category_id = kbc.id
WHERE ka.organization_id = org_uuid
  AND ka.status = 'published'
  AND ka.search_vector @@ plainto_tsquery('english', search_query)
  AND (category_filter IS NULL OR ka.category_id = category_filter)
ORDER BY relevance_score DESC, ka.view_count DESC
    LIMIT limit_results;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Knowledge base categories indexes
CREATE INDEX idx_kb_categories_organization_id ON knowledge_base_categories(organization_id);
CREATE INDEX idx_kb_categories_parent ON knowledge_base_categories(parent_category_id);
CREATE INDEX idx_kb_categories_slug ON knowledge_base_categories(slug);
CREATE INDEX idx_kb_categories_path ON knowledge_base_categories USING GIST(path gist_trgm_ops);

-- Knowledge articles indexes
CREATE INDEX idx_kb_articles_organization_id ON knowledge_articles(organization_id);
CREATE INDEX idx_kb_articles_category_id ON knowledge_articles(category_id);
CREATE INDEX idx_kb_articles_status ON knowledge_articles(status);
CREATE INDEX idx_kb_articles_slug ON knowledge_articles(slug);
CREATE INDEX idx_kb_articles_visibility ON knowledge_articles(visibility);
CREATE INDEX idx_kb_articles_featured ON knowledge_articles(is_featured);
CREATE INDEX idx_kb_articles_published_at ON knowledge_articles(published_at);
CREATE INDEX idx_kb_articles_search_vector ON knowledge_articles USING GIN(search_vector);
CREATE INDEX idx_kb_articles_tags ON knowledge_articles USING GIN(tags);
CREATE INDEX idx_kb_articles_keywords ON knowledge_articles USING GIN(keywords);

-- Article versions indexes
CREATE INDEX idx_article_versions_article_id ON article_versions(article_id);
CREATE INDEX idx_article_versions_version ON article_versions(version_number);
CREATE INDEX idx_article_versions_current ON article_versions(is_current) WHERE is_current = TRUE;

-- Article views indexes
CREATE INDEX idx_article_views_article_id ON article_views(article_id);
CREATE INDEX idx_article_views_user_id ON article_views(user_id);
CREATE INDEX idx_article_views_viewed_at ON article_views(viewed_at);
CREATE INDEX idx_article_views_session_id ON article_views(session_id);

-- Search queries indexes
CREATE INDEX idx_kb_search_queries_organization_id ON kb_search_queries(organization_id);
CREATE INDEX idx_kb_search_queries_query_text ON kb_search_queries(query_text);
CREATE INDEX idx_kb_search_queries_searched_at ON kb_search_queries(searched_at);

-- Help widgets indexes
CREATE INDEX idx_help_widgets_organization_id ON help_widgets(organization_id);
CREATE INDEX idx_help_widgets_active ON help_widgets(is_active);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_kb_categories_updated_at BEFORE UPDATE ON knowledge_base_categories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_knowledge_articles_updated_at BEFORE UPDATE ON knowledge_articles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_article_comments_updated_at BEFORE UPDATE ON article_comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_article_templates_updated_at BEFORE UPDATE ON article_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_help_widgets_updated_at BEFORE UPDATE ON help_widgets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();