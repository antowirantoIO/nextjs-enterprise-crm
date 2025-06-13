-- =====================================================
-- DOCUMENTS STORAGE MIGRATION
-- Extended document management, file versioning, and collaboration
-- Created: 2024-01-01 00:00:08 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- DOCUMENT FOLDERS & ORGANIZATION
-- =====================================================

-- Document folders table (hierarchical folder structure)
CREATE TABLE document_folders (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                  parent_folder_id UUID REFERENCES document_folders(id) ON DELETE CASCADE,

    -- Folder details
                                  name VARCHAR(255) NOT NULL,
                                  description TEXT,
                                  color VARCHAR(7), -- Hex color code
                                  icon VARCHAR(50),

    -- Access control
                                  access_level document_access_level DEFAULT 'organization',
                                  is_system_folder BOOLEAN DEFAULT FALSE,

    -- Folder path (materialized path for performance)
                                  path VARCHAR(2000),
                                  depth INTEGER DEFAULT 0,

    -- Settings
                                  auto_organize_rules JSONB, -- Rules for auto-organizing documents

    -- Metadata
                                  created_by UUID REFERENCES user_profiles(id),
                                  created_at TIMESTAMPTZ DEFAULT NOW(),
                                  updated_at TIMESTAMPTZ DEFAULT NOW(),
                                  deleted_at TIMESTAMPTZ,

    -- Constraints
                                  UNIQUE(organization_id, parent_folder_id, name),
                                  CHECK (depth >= 0 AND depth <= 10) -- Prevent too deep nesting
);

-- Document folder permissions table
CREATE TABLE document_folder_permissions (
                                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                             folder_id UUID NOT NULL REFERENCES document_folders(id) ON DELETE CASCADE,

    -- Permission target
                                             user_id UUID REFERENCES user_profiles(id),
                                             team_id UUID REFERENCES teams(id),
                                             role user_role,

    -- Permissions
                                             can_view BOOLEAN DEFAULT TRUE,
                                             can_edit BOOLEAN DEFAULT FALSE,
                                             can_delete BOOLEAN DEFAULT FALSE,
                                             can_share BOOLEAN DEFAULT FALSE,
                                             can_manage_permissions BOOLEAN DEFAULT FALSE,

    -- Inheritance
                                             inherit_permissions BOOLEAN DEFAULT TRUE,

    -- Metadata
                                             granted_by UUID REFERENCES user_profiles(id),
                                             granted_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
                                             CHECK (
                                                 (user_id IS NOT NULL AND team_id IS NULL AND role IS NULL) OR
                                                 (user_id IS NULL AND team_id IS NOT NULL AND role IS NULL) OR
                                                 (user_id IS NULL AND team_id IS NULL AND role IS NOT NULL)
                                                 )
);

-- =====================================================
-- DOCUMENT TEMPLATES & GENERATION
-- =====================================================

-- Document templates table
CREATE TABLE document_templates (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                    folder_id UUID REFERENCES document_folders(id),

    -- Template details
                                    name VARCHAR(255) NOT NULL,
                                    description TEXT,
                                    document_type document_type NOT NULL,

    -- Template content
                                    template_content TEXT, -- Template content with placeholders
                                    variables JSONB DEFAULT '{}', -- Available variables and their types

    -- Template file
                                    template_file_path VARCHAR(1000), -- Path to template file

    -- Settings
                                    is_active BOOLEAN DEFAULT TRUE,
                                    is_system_template BOOLEAN DEFAULT FALSE,

    -- Usage tracking
                                    usage_count INTEGER DEFAULT 0,
                                    last_used_at TIMESTAMPTZ,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW(),
                                    deleted_at TIMESTAMPTZ
);

-- Document generations table (tracking template usage)
CREATE TABLE document_generations (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      template_id UUID NOT NULL REFERENCES document_templates(id) ON DELETE CASCADE,
                                      document_id UUID REFERENCES documents(id) ON DELETE SET NULL,

    -- Generation details
                                      variable_values JSONB, -- Values used for variables

    -- Generation context
                                      contact_id UUID REFERENCES contacts(id),
                                      company_id UUID REFERENCES companies(id),
                                      deal_id UUID REFERENCES deals(id),

    -- Status
                                      status VARCHAR(20) DEFAULT 'pending', -- pending, processing, completed, failed
                                      error_message TEXT,

    -- Metadata
                                      generated_by UUID REFERENCES user_profiles(id),
                                      generated_at TIMESTAMPTZ DEFAULT NOW(),
                                      completed_at TIMESTAMPTZ
);

-- =====================================================
-- DOCUMENT COLLABORATION
-- =====================================================

-- Document collaborators table
CREATE TABLE document_collaborators (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                        document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
                                        user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Collaboration role
                                        role VARCHAR(50) DEFAULT 'viewer', -- owner, editor, commenter, viewer

    -- Permissions
                                        can_edit BOOLEAN DEFAULT FALSE,
                                        can_comment BOOLEAN DEFAULT TRUE,
                                        can_share BOOLEAN DEFAULT FALSE,
                                        can_download BOOLEAN DEFAULT TRUE,

    -- Invitation details
                                        invited_by UUID REFERENCES user_profiles(id),
                                        invited_at TIMESTAMPTZ DEFAULT NOW(),
                                        access_expires_at TIMESTAMPTZ,

    -- Activity tracking
                                        last_accessed_at TIMESTAMPTZ,
                                        last_edited_at TIMESTAMPTZ,

                                        UNIQUE(document_id, user_id)
);

-- Document comments table
CREATE TABLE document_comments (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
                                   author_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
                                   parent_comment_id UUID REFERENCES document_comments(id) ON DELETE CASCADE,

    -- Comment content
                                   content TEXT NOT NULL,

    -- Location in document (for PDF annotations, etc.)
                                   page_number INTEGER,
                                   position_x DECIMAL(10,4),
                                   position_y DECIMAL(10,4),
                                   highlighted_text TEXT,

    -- Comment type
                                   comment_type VARCHAR(50) DEFAULT 'general', -- general, annotation, suggestion, approval

    -- Status
                                   is_resolved BOOLEAN DEFAULT FALSE,
                                   resolved_at TIMESTAMPTZ,
                                   resolved_by UUID REFERENCES user_profiles(id),

    -- Metadata
                                   created_at TIMESTAMPTZ DEFAULT NOW(),
                                   updated_at TIMESTAMPTZ DEFAULT NOW(),
                                   deleted_at TIMESTAMPTZ
);

-- =====================================================
-- DOCUMENT WORKFLOW & APPROVALS
-- =====================================================

-- Document workflows table
CREATE TABLE document_workflows (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Workflow details
                                    name VARCHAR(255) NOT NULL,
                                    description TEXT,

    -- Trigger conditions
                                    trigger_conditions JSONB, -- When this workflow should start

    -- Workflow steps
                                    workflow_steps JSONB NOT NULL, -- Array of step configurations

    -- Settings
                                    is_active BOOLEAN DEFAULT TRUE,
                                    auto_start BOOLEAN DEFAULT FALSE,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Document workflow instances table
CREATE TABLE document_workflow_instances (
                                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                             workflow_id UUID NOT NULL REFERENCES document_workflows(id),
                                             document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,

    -- Instance status
                                             status VARCHAR(20) DEFAULT 'active', -- active, completed, cancelled, failed
                                             current_step INTEGER DEFAULT 1,
                                             total_steps INTEGER NOT NULL,

    -- Instance data
                                             workflow_data JSONB DEFAULT '{}',

    -- Timing
                                             started_at TIMESTAMPTZ DEFAULT NOW(),
                                             completed_at TIMESTAMPTZ,

    -- Metadata
                                             started_by UUID REFERENCES user_profiles(id)
);

-- Document workflow steps table
CREATE TABLE document_workflow_step_instances (
                                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                                  workflow_instance_id UUID NOT NULL REFERENCES document_workflow_instances(id) ON DELETE CASCADE,

    -- Step details
                                                  step_number INTEGER NOT NULL,
                                                  step_type VARCHAR(50) NOT NULL, -- review, approval, notification, assignment
                                                  step_name VARCHAR(255),

    -- Assignee
                                                  assigned_to UUID REFERENCES user_profiles(id),
                                                  assigned_role VARCHAR(50),

    -- Status
                                                  status VARCHAR(20) DEFAULT 'pending', -- pending, in_progress, completed, skipped, failed

    -- Response
                                                  response TEXT,
                                                  attachments JSONB,
                                                  completed_at TIMESTAMPTZ,

    -- Timing
                                                  due_date TIMESTAMPTZ,
                                                  reminded_at TIMESTAMPTZ,

    -- Metadata
                                                  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- DOCUMENT ANALYTICS & TRACKING
-- =====================================================

-- Document access logs table
CREATE TABLE document_access_logs (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
                                      user_id UUID REFERENCES user_profiles(id),

    -- Access details
                                      action VARCHAR(50) NOT NULL, -- view, download, edit, comment, share
                                      ip_address INET,
                                      user_agent TEXT,

    -- Session info
                                      session_id VARCHAR(255),

    -- Location tracking
                                      country VARCHAR(100),
                                      city VARCHAR(100),

    -- Metadata
                                      accessed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Document analytics table (aggregated metrics)
CREATE TABLE document_analytics (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,

    -- Time period
                                    date DATE NOT NULL,

    -- View metrics
                                    unique_viewers INTEGER DEFAULT 0,
                                    total_views INTEGER DEFAULT 0,
                                    total_downloads INTEGER DEFAULT 0,

    -- Engagement metrics
                                    average_view_duration_seconds INTEGER DEFAULT 0,
                                    total_comments INTEGER DEFAULT 0,
                                    total_shares INTEGER DEFAULT 0,

    -- Geographic data
                                    top_countries JSONB, -- {country: count}

    -- Metadata
                                    calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                    UNIQUE(document_id, date)
);

-- =====================================================
-- DOCUMENT SECURITY & COMPLIANCE
-- =====================================================

-- Document security settings table
CREATE TABLE document_security_settings (
                                            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                            document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,

    -- Access restrictions
                                            require_authentication BOOLEAN DEFAULT TRUE,
                                            allowed_domains TEXT[], -- Email domains that can access
                                            ip_whitelist INET[], -- IP addresses/ranges allowed

    -- Download restrictions
                                            prevent_download BOOLEAN DEFAULT FALSE,
                                            prevent_printing BOOLEAN DEFAULT FALSE,
                                            prevent_copy_paste BOOLEAN DEFAULT FALSE,

    -- Expiration
                                            expires_at TIMESTAMPTZ,
                                            max_views INTEGER, -- Maximum number of views allowed
                                            current_views INTEGER DEFAULT 0,

    -- Watermarking
                                            enable_watermark BOOLEAN DEFAULT FALSE,
                                            watermark_text VARCHAR(255),

    -- Encryption
                                            is_encrypted BOOLEAN DEFAULT FALSE,
                                            encryption_method VARCHAR(50),

    -- Compliance
                                            retention_period_days INTEGER,
                                            compliance_tags TEXT[],

    -- Metadata
                                            created_by UUID REFERENCES user_profiles(id),
                                            created_at TIMESTAMPTZ DEFAULT NOW(),
                                            updated_at TIMESTAMPTZ DEFAULT NOW(),

                                            UNIQUE(document_id)
);

-- Document compliance logs table
CREATE TABLE document_compliance_logs (
                                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                          document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,

    -- Compliance event
                                          event_type VARCHAR(50) NOT NULL, -- created, accessed, modified, deleted, exported, retention_expired
                                          event_description TEXT,

    -- Legal hold
                                          legal_hold_id VARCHAR(255),

    -- User context
                                          user_id UUID REFERENCES user_profiles(id),
                                          ip_address INET,

    -- Metadata
                                          event_timestamp TIMESTAMPTZ DEFAULT NOW(),
                                          metadata JSONB DEFAULT '{}'
);

-- =====================================================
-- FUNCTIONS FOR DOCUMENTS
-- =====================================================

-- Function to update folder path when parent changes
CREATE OR REPLACE FUNCTION update_folder_path()
RETURNS TRIGGER AS $$
DECLARE
parent_path VARCHAR(2000);
    parent_depth INTEGER;
BEGIN
    -- Get parent folder path and depth
    IF NEW.parent_folder_id IS NOT NULL THEN
SELECT path, depth INTO parent_path, parent_depth
FROM document_folders
WHERE id = NEW.parent_folder_id;

NEW.path := parent_path || '/' || NEW.name;
        NEW.depth := parent_depth + 1;
ELSE
        NEW.path := NEW.name;
        NEW.depth := 0;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating folder paths
CREATE TRIGGER update_folder_path_trigger
    BEFORE INSERT OR UPDATE ON document_folders
                         FOR EACH ROW
                         EXECUTE FUNCTION update_folder_path();

-- Function to update document analytics
CREATE OR REPLACE FUNCTION update_document_analytics()
RETURNS TRIGGER AS $$
DECLARE
log_date DATE;
BEGIN
    log_date := NEW.accessed_at::DATE;

    -- Update daily analytics
INSERT INTO document_analytics (
    document_id,
    date,
    unique_viewers,
    total_views,
    total_downloads
) VALUES (
             NEW.document_id,
             log_date,
             CASE WHEN NEW.action = 'view' THEN 1 ELSE 0 END,
             CASE WHEN NEW.action = 'view' THEN 1 ELSE 0 END,
             CASE WHEN NEW.action = 'download' THEN 1 ELSE 0 END
         )
    ON CONFLICT (document_id, date)
    DO UPDATE SET
    unique_viewers = document_analytics.unique_viewers +
               CASE WHEN EXCLUDED.unique_viewers > 0 AND NOT EXISTS (
               SELECT 1 FROM document_access_logs
               WHERE document_id = NEW.document_id
               AND user_id = NEW.user_id
               AND accessed_at::DATE = log_date
               AND action = 'view'
               AND id < NEW.id
               ) THEN 1 ELSE 0 END,
        total_views = document_analytics.total_views + EXCLUDED.total_views,
        total_downloads = document_analytics.total_downloads + EXCLUDED.total_downloads,
        calculated_at = NOW();

    -- Update document view/download counts
UPDATE documents
SET
    view_count = view_count + CASE WHEN NEW.action = 'view' THEN 1 ELSE 0 END,
    download_count = download_count + CASE WHEN NEW.action = 'download' THEN 1 ELSE 0 END,
    last_accessed_at = NEW.accessed_at
WHERE id = NEW.document_id;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating analytics
CREATE TRIGGER update_document_analytics_trigger
    AFTER INSERT ON document_access_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_document_analytics();

-- Function to check document security before access
CREATE OR REPLACE FUNCTION check_document_access(
    doc_id UUID,
    user_uuid UUID,
    user_ip INET,
    action_type VARCHAR(50)
)
RETURNS BOOLEAN AS $$
DECLARE
security_settings RECORD;
    user_email VARCHAR(255);
    user_domain VARCHAR(255);
BEGIN
    -- Get security settings
SELECT * INTO security_settings
FROM document_security_settings
WHERE document_id = doc_id;

-- If no security settings, allow access
IF NOT FOUND THEN
        RETURN TRUE;
END IF;

    -- Check expiration
    IF security_settings.expires_at IS NOT NULL AND security_settings.expires_at < NOW() THEN
        RETURN FALSE;
END IF;

    -- Check max views
    IF security_settings.max_views IS NOT NULL AND security_settings.current_views >= security_settings.max_views THEN
        RETURN FALSE;
END IF;

    -- Check IP whitelist
    IF security_settings.ip_whitelist IS NOT NULL AND array_length(security_settings.ip_whitelist, 1) > 0 THEN
        IF NOT (user_ip = ANY(security_settings.ip_whitelist)) THEN
            RETURN FALSE;
END IF;
END IF;

    -- Check domain restrictions
    IF security_settings.allowed_domains IS NOT NULL AND array_length(security_settings.allowed_domains, 1) > 0 THEN
SELECT email INTO user_email FROM user_profiles WHERE id = user_uuid;
user_domain := split_part(user_email, '@', 2);

        IF NOT (user_domain = ANY(security_settings.allowed_domains)) THEN
            RETURN FALSE;
END IF;
END IF;

    -- Check action-specific restrictions
    IF action_type = 'download' AND security_settings.prevent_download THEN
        RETURN FALSE;
END IF;

RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to auto-organize documents based on rules
CREATE OR REPLACE FUNCTION auto_organize_document()
RETURNS TRIGGER AS $$
DECLARE
folder_rule RECORD;
    target_folder_id UUID;
BEGIN
    -- Check all folders with auto-organize rules
FOR folder_rule IN
SELECT id, auto_organize_rules
FROM document_folders
WHERE organization_id = NEW.organization_id
  AND auto_organize_rules IS NOT NULL
  AND is_system_folder = FALSE
    LOOP
        -- Simple rule evaluation (can be extended)
        -- Check document type rule
        IF folder_rule.auto_organize_rules->>'document_type' = NEW.document_type::TEXT THEN
            target_folder_id := folder_rule.id;
EXIT;
END IF;

        -- Check file extension rule
        IF folder_rule.auto_organize_rules->>'file_extension' = NEW.file_extension THEN
            target_folder_id := folder_rule.id;
            EXIT;
END IF;

        -- Check name pattern rule
        IF folder_rule.auto_organize_rules->>'name_pattern' IS NOT NULL THEN
            IF NEW.name ~* (folder_rule.auto_organize_rules->>'name_pattern') THEN
                target_folder_id := folder_rule.id;
                EXIT;
END IF;
END IF;
END LOOP;

    -- Move document to target folder if found
    IF target_folder_id IS NOT NULL THEN
        -- Update document to move it to the target folder
        -- This would be handled in the application layer
        -- For now, we'll just log it
        INSERT INTO audit_logs (
            organization_id,
            user_id,
            action,
            resource_type,
            resource_id,
            new_values,
            metadata
        ) VALUES (
            NEW.organization_id,
            NEW.created_by,
            'auto_organize',
            'documents',
            NEW.id,
            jsonb_build_object('target_folder_id', target_folder_id),
            jsonb_build_object('reason', 'auto_organize_rule')
        );
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-organizing documents
CREATE TRIGGER auto_organize_document_trigger
    AFTER INSERT ON documents
    FOR EACH ROW
    EXECUTE FUNCTION auto_organize_document();

-- =====================================================
-- INDEXES
-- =====================================================

-- Document folders indexes
CREATE INDEX idx_document_folders_organization_id ON document_folders(organization_id);
CREATE INDEX idx_document_folders_parent ON document_folders(parent_folder_id);
CREATE INDEX idx_document_folders_path ON document_folders USING GIN(to_tsvector('english', path));

-- Document templates indexes
CREATE INDEX idx_document_templates_organization_id ON document_templates(organization_id);
CREATE INDEX idx_document_templates_type ON document_templates(document_type);
CREATE INDEX idx_document_templates_active ON document_templates(is_active);

-- Document collaborators indexes
CREATE INDEX idx_document_collaborators_document_id ON document_collaborators(document_id);
CREATE INDEX idx_document_collaborators_user_id ON document_collaborators(user_id);

-- Document comments indexes
CREATE INDEX idx_document_comments_document_id ON document_comments(document_id);
CREATE INDEX idx_document_comments_author_id ON document_comments(author_id);
CREATE INDEX idx_document_comments_parent ON document_comments(parent_comment_id);

-- Document access logs indexes
CREATE INDEX idx_document_access_logs_document_id ON document_access_logs(document_id);
CREATE INDEX idx_document_access_logs_user_id ON document_access_logs(user_id);
CREATE INDEX idx_document_access_logs_accessed_at ON document_access_logs(accessed_at);
CREATE INDEX idx_document_access_logs_action ON document_access_logs(action);

-- Document analytics indexes
CREATE INDEX idx_document_analytics_document_id ON document_analytics(document_id);
CREATE INDEX idx_document_analytics_date ON document_analytics(date);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_document_folders_updated_at BEFORE UPDATE ON document_folders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_document_templates_updated_at BEFORE UPDATE ON document_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_document_workflows_updated_at BEFORE UPDATE ON document_workflows FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_document_comments_updated_at BEFORE UPDATE ON document_comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_document_security_settings_updated_at BEFORE UPDATE ON document_security_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();