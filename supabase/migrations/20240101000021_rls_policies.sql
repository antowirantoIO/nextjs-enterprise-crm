-- =====================================================
-- ROW LEVEL SECURITY POLICIES MIGRATION
-- Comprehensive RLS policies for data security and multi-tenancy
-- Created: 2025-06-13 20:36:35 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- ENABLE RLS ON ALL TABLES
-- =====================================================

-- Core entities
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;

-- CRM entities
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_pipelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- Documents and files
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_collaborators ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_comments ENABLE ROW LEVEL SECURITY;

-- Notifications and communication
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_rules ENABLE ROW LEVEL SECURITY;

-- Analytics and reporting
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboard_widgets ENABLE ROW LEVEL SECURITY;

-- Integrations and automation
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_executions ENABLE ROW LEVEL SECURITY;

-- Team collaboration
ALTER TABLE collaboration_spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE space_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE board_cards ENABLE ROW LEVEL SECURITY;

-- Knowledge base
ALTER TABLE knowledge_base_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_comments ENABLE ROW LEVEL SECURITY;

-- Billing and subscriptions
ALTER TABLE organization_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_metrics ENABLE ROW LEVEL SECURITY;

-- Feature flags
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE flag_evaluations ENABLE ROW LEVEL SECURITY;

-- Custom fields
ALTER TABLE custom_field_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_field_values ENABLE ROW LEVEL SECURITY;

-- Search and audit
ALTER TABLE global_search_index ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- HELPER FUNCTIONS FOR RLS
-- =====================================================

-- Function to get current user's organization ID
CREATE OR REPLACE FUNCTION auth.user_organization_id()
RETURNS UUID AS $$
BEGIN
RETURN (
    SELECT organization_id
    FROM user_profiles
    WHERE id = auth.uid()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION auth.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
RETURN (
    SELECT role IN ('super_admin', 'admin')
    FROM user_profiles
    WHERE id = auth.uid()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is super admin
CREATE OR REPLACE FUNCTION auth.is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
RETURN (
    SELECT role = 'super_admin'
    FROM user_profiles
    WHERE id = auth.uid()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has specific role
CREATE OR REPLACE FUNCTION auth.has_role(required_role user_role)
RETURNS BOOLEAN AS $$
BEGIN
RETURN (
    SELECT role = required_role
    FROM user_profiles
    WHERE id = auth.uid()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can access workspace
CREATE OR REPLACE FUNCTION auth.can_access_workspace(workspace_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
RETURN EXISTS (
    SELECT 1 FROM workspace_members wm
                      JOIN user_profiles up ON wm.user_id = up.id
    WHERE wm.workspace_id = workspace_uuid
      AND up.id = auth.uid()
      AND up.organization_id = auth.user_organization_id()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user can access collaboration space
CREATE OR REPLACE FUNCTION auth.can_access_space(space_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
RETURN EXISTS (
    SELECT 1 FROM space_members sm
    WHERE sm.space_id = space_uuid
      AND sm.user_id = auth.uid()
      AND sm.status = 'active'
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check document access
CREATE OR REPLACE FUNCTION auth.can_access_document(document_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
doc_record RECORD;
BEGIN
SELECT * INTO doc_record FROM documents WHERE id = document_uuid;

IF NOT FOUND THEN
        RETURN FALSE;
END IF;

    -- Check organization access
    IF doc_record.organization_id != auth.user_organization_id() THEN
        RETURN FALSE;
END IF;

    -- Check access level
CASE doc_record.access_level
        WHEN 'public' THEN
            RETURN TRUE;
WHEN 'organization' THEN
            RETURN TRUE;
WHEN 'team' THEN
            RETURN auth.is_admin() OR EXISTS (
                SELECT 1 FROM document_collaborators dc
                WHERE dc.document_id = document_uuid
                AND dc.user_id = auth.uid()
            );
WHEN 'private' THEN
            RETURN doc_record.created_by = auth.uid() OR EXISTS (
                SELECT 1 FROM document_collaborators dc
                WHERE dc.document_id = document_uuid
                AND dc.user_id = auth.uid()
            );
ELSE
            RETURN FALSE;
END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- ORGANIZATION AND USER POLICIES
-- =====================================================

-- Organizations: Users can only access their own organization
CREATE POLICY "Users can access their own organization" ON organizations
    FOR ALL USING (id = auth.user_organization_id());

-- User profiles: Users can see users in their organization
CREATE POLICY "Users can see profiles in their organization" ON user_profiles
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- User profiles: Users can update their own profile
CREATE POLICY "Users can update their own profile" ON user_profiles
    FOR UPDATE USING (id = auth.uid());

-- User profiles: Admins can manage all users in their organization
CREATE POLICY "Admins can manage users in their organization" ON user_profiles
    FOR ALL USING (
        organization_id = auth.user_organization_id()
        AND auth.is_admin()
    );

-- Workspaces: Users can access workspaces they belong to
CREATE POLICY "Users can access their workspaces" ON workspaces
    FOR SELECT USING (
                          organization_id = auth.user_organization_id()
                          AND (
                          auth.is_admin() OR
                          auth.can_access_workspace(id)
                          )
                          );

-- Teams: Users can see teams in their organization
CREATE POLICY "Users can see teams in their organization" ON teams
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Team members: Users can see team members in their organization
CREATE POLICY "Users can see team members in their organization" ON team_members
    FOR SELECT USING (
                   EXISTS (
                   SELECT 1 FROM teams t
                   WHERE t.id = team_id
                   AND t.organization_id = auth.user_organization_id()
                   )
                   );

-- =====================================================
-- CRM ENTITY POLICIES
-- =====================================================

-- Contacts: Users can access contacts in their organization
CREATE POLICY "Users can access contacts in their organization" ON contacts
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Contacts: Users can create contacts in their organization
CREATE POLICY "Users can create contacts in their organization" ON contacts
    FOR INSERT WITH CHECK (organization_id = auth.user_organization_id());

-- Contacts: Users can update contacts in their organization
CREATE POLICY "Users can update contacts in their organization" ON contacts
    FOR UPDATE USING (organization_id = auth.user_organization_id());

-- Contacts: Only admins can delete contacts
CREATE POLICY "Only admins can delete contacts" ON contacts
    FOR DELETE USING (
        organization_id = auth.user_organization_id()
        AND auth.is_admin()
    );

-- Companies: Similar policies to contacts
CREATE POLICY "Users can access companies in their organization" ON companies
    FOR SELECT USING (organization_id = auth.user_organization_id());

CREATE POLICY "Users can create companies in their organization" ON companies
    FOR INSERT WITH CHECK (organization_id = auth.user_organization_id());

CREATE POLICY "Users can update companies in their organization" ON companies
    FOR UPDATE USING (organization_id = auth.user_organization_id());

CREATE POLICY "Only admins can delete companies" ON companies
    FOR DELETE USING (
        organization_id = auth.user_organization_id()
        AND auth.is_admin()
    );

-- Deals: Users can access deals in their organization
CREATE POLICY "Users can access deals in their organization" ON deals
    FOR SELECT USING (organization_id = auth.user_organization_id());

CREATE POLICY "Users can create deals in their organization" ON deals
    FOR INSERT WITH CHECK (organization_id = auth.user_organization_id());

-- Deals: Users can update deals they own or if they're admin
CREATE POLICY "Users can update their deals or admins can update all" ON deals
    FOR UPDATE USING (
                          organization_id = auth.user_organization_id()
                          AND (owner_id = auth.uid() OR auth.is_admin())
                          );

CREATE POLICY "Only admins can delete deals" ON deals
    FOR DELETE USING (
        organization_id = auth.user_organization_id()
        AND auth.is_admin()
    );

-- Deal pipelines: Users can see pipelines in their organization
CREATE POLICY "Users can see pipelines in their organization" ON deal_pipelines
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Deal stages: Users can see stages in their organization
CREATE POLICY "Users can see stages in their organization" ON deal_stages
    FOR SELECT USING (
                   EXISTS (
                   SELECT 1 FROM deal_pipelines dp
                   WHERE dp.id = pipeline_id
                   AND dp.organization_id = auth.user_organization_id()
                   )
                   );

-- Activities: Users can access activities in their organization
CREATE POLICY "Users can access activities in their organization" ON activities
    FOR SELECT USING (organization_id = auth.user_organization_id());

CREATE POLICY "Users can create activities in their organization" ON activities
    FOR INSERT WITH CHECK (organization_id = auth.user_organization_id());

-- Activities: Users can update activities they own or if they're admin
CREATE POLICY "Users can update their activities or admins can update all" ON activities
    FOR UPDATE USING (
                          organization_id = auth.user_organization_id()
                          AND (owner_id = auth.uid() OR auth.is_admin())
                          );

-- =====================================================
-- DOCUMENT POLICIES
-- =====================================================

-- Documents: Custom access control based on document settings
CREATE POLICY "Users can access documents based on permissions" ON documents
    FOR SELECT USING (auth.can_access_document(id));

CREATE POLICY "Users can create documents in their organization" ON documents
    FOR INSERT WITH CHECK (organization_id = auth.user_organization_id());

-- Documents: Users can update documents they created or have edit access
CREATE POLICY "Users can update documents they have edit access to" ON documents
    FOR UPDATE USING (
                          organization_id = auth.user_organization_id()
                          AND (
                          created_by = auth.uid() OR
                          auth.is_admin() OR
                          EXISTS (
                          SELECT 1 FROM document_collaborators dc
                          WHERE dc.document_id = id
                          AND dc.user_id = auth.uid()
                          AND dc.can_edit = TRUE
                          )
                          )
                          );

-- Document folders: Users can see folders in their organization
CREATE POLICY "Users can see document folders in their organization" ON document_folders
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Document collaborators: Users can see collaborators for documents they can access
CREATE POLICY "Users can see document collaborators for accessible documents" ON document_collaborators
    FOR SELECT USING (auth.can_access_document(document_id));

-- =====================================================
-- NOTIFICATION POLICIES
-- =====================================================

-- Notifications: Users can only see their own notifications
CREATE POLICY "Users can see their own notifications" ON notifications
    FOR SELECT USING (recipient_id = auth.uid());

CREATE POLICY "Users can update their own notifications" ON notifications
    FOR UPDATE USING (recipient_id = auth.uid());

-- Notification preferences: Users can manage their own preferences
CREATE POLICY "Users can manage their own notification preferences" ON notification_preferences
    FOR ALL USING (user_id = auth.uid());

-- Notification templates: Users can see templates in their organization
CREATE POLICY "Users can see notification templates in their organization" ON notification_templates
    FOR SELECT USING (
                          organization_id = auth.user_organization_id() OR
                          organization_id IS NULL
                          );

-- =====================================================
-- ANALYTICS AND REPORTING POLICIES
-- =====================================================

-- Analytics events: Users can create events for their organization
CREATE POLICY "Users can create analytics events for their organization" ON analytics_events
    FOR INSERT WITH CHECK (organization_id = auth.user_organization_id());

-- Analytics events: Users can see events in their organization
CREATE POLICY "Users can see analytics events in their organization" ON analytics_events
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Custom reports: Users can see reports they created or have access to
CREATE POLICY "Users can access custom reports" ON custom_reports
    FOR SELECT USING (
                   organization_id = auth.user_organization_id()
                   AND (
                   created_by = auth.uid() OR
                   visibility = 'organization' OR
                   auth.is_admin() OR
                   auth.uid() = ANY(shared_with_users)
                   )
                   );

-- Dashboards: Similar to custom reports
CREATE POLICY "Users can access dashboards" ON dashboards
    FOR SELECT USING (
                   organization_id = auth.user_organization_id()
                   AND (
                   created_by = auth.uid() OR
                   visibility = 'organization' OR
                   auth.is_admin() OR
                   auth.uid() = ANY(shared_with_users)
                   )
                   );

-- =====================================================
-- INTEGRATION AND AUTOMATION POLICIES
-- =====================================================

-- Integrations: Users can see integrations in their organization
CREATE POLICY "Users can see integrations in their organization" ON integrations
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Integrations: Only admins can manage integrations
CREATE POLICY "Only admins can manage integrations" ON integrations
    FOR ALL USING (
        organization_id = auth.user_organization_id()
        AND auth.is_admin()
    );

-- Webhooks: Only admins can manage webhooks
CREATE POLICY "Only admins can manage webhooks" ON webhooks
    FOR ALL USING (
        organization_id = auth.user_organization_id()
        AND auth.is_admin()
    );

-- Workflows: Users can see workflows in their organization
CREATE POLICY "Users can see workflows in their organization" ON workflows
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Workflows: Users can create workflows, admins can manage all
CREATE POLICY "Users can create workflows, admins can manage all" ON workflows
    FOR ALL USING (
        organization_id = auth.user_organization_id()
        AND (created_by = auth.uid() OR auth.is_admin())
    );

-- =====================================================
-- COLLABORATION POLICIES
-- =====================================================

-- Collaboration spaces: Users can access spaces they're members of
CREATE POLICY "Users can access collaboration spaces they're members of" ON collaboration_spaces
    FOR SELECT USING (
                          organization_id = auth.user_organization_id()
                          AND (
                          auth.is_admin() OR
                          auth.can_access_space(id)
                          )
                          );

-- Space members: Users can see members of spaces they belong to
CREATE POLICY "Users can see space members for accessible spaces" ON space_members
    FOR SELECT USING (auth.can_access_space(space_id));

-- Team messages: Users can see messages in spaces they belong to
CREATE POLICY "Users can see messages in accessible spaces" ON team_messages
    FOR SELECT USING (auth.can_access_space(space_id));

CREATE POLICY "Users can create messages in accessible spaces" ON team_messages
    FOR INSERT WITH CHECK (auth.can_access_space(space_id));

-- Project boards: Users can see boards in spaces they belong to
CREATE POLICY "Users can see boards in accessible spaces" ON project_boards
    FOR SELECT USING (auth.can_access_space(space_id));

-- Board cards: Users can see cards in boards they can access
CREATE POLICY "Users can see cards in accessible boards" ON board_cards
    FOR SELECT USING (
                   EXISTS (
                   SELECT 1 FROM project_boards pb
                   WHERE pb.id = board_id
                   AND auth.can_access_space(pb.space_id)
                   )
                   );

-- =====================================================
-- KNOWLEDGE BASE POLICIES
-- =====================================================

-- Knowledge base categories: Users can see categories in their organization
CREATE POLICY "Users can see knowledge categories in their organization" ON knowledge_base_categories
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Knowledge articles: Users can see published articles or articles they created
CREATE POLICY "Users can access knowledge articles" ON knowledge_articles
    FOR SELECT USING (
                   organization_id = auth.user_organization_id()
                   AND (
                   status = 'published' OR
                   created_by = auth.uid() OR
                   auth.is_admin()
                   )
                   );

-- =====================================================
-- BILLING POLICIES
-- =====================================================

-- Organization subscriptions: Only admins can see billing info
CREATE POLICY "Only admins can see billing information" ON organization_subscriptions
    FOR SELECT USING (
                   organization_id = auth.user_organization_id()
                   AND auth.is_admin()
                   );

-- Invoices: Only admins can see invoices
CREATE POLICY "Only admins can see invoices" ON invoices
    FOR SELECT USING (
                   organization_id = auth.user_organization_id()
                   AND auth.is_admin()
                   );

-- Usage metrics: Only admins can see usage metrics
CREATE POLICY "Only admins can see usage metrics" ON usage_metrics
    FOR SELECT USING (
                   organization_id = auth.user_organization_id()
                   AND auth.is_admin()
                   );

-- =====================================================
-- FEATURE FLAG POLICIES
-- =====================================================

-- Feature flags: Users can see flags for their organization or global flags
CREATE POLICY "Users can see feature flags" ON feature_flags
    FOR SELECT USING (
                   organization_id = auth.user_organization_id() OR
                   organization_id IS NULL
                   );

-- Feature flags: Only admins can manage flags
CREATE POLICY "Only admins can manage feature flags" ON feature_flags
    FOR ALL USING (
        (organization_id = auth.user_organization_id() OR organization_id IS NULL)
        AND auth.is_admin()
    );

-- Flag evaluations: Users can see their own evaluations
CREATE POLICY "Users can see their own flag evaluations" ON flag_evaluations
    FOR SELECT USING (user_id = auth.uid());

-- =====================================================
-- CUSTOM FIELD POLICIES
-- =====================================================

-- Custom field definitions: Users can see field definitions in their organization
CREATE POLICY "Users can see custom field definitions in their organization" ON custom_field_definitions
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Custom field definitions: Only admins can manage field definitions
CREATE POLICY "Only admins can manage custom field definitions" ON custom_field_definitions
    FOR ALL USING (
        organization_id = auth.user_organization_id()
        AND auth.is_admin()
    );

-- Custom field values: Users can see values for entities they can access
CREATE POLICY "Users can see custom field values for accessible entities" ON custom_field_values
    FOR SELECT USING (
                          EXISTS (
                          SELECT 1 FROM custom_field_definitions cfd
                          WHERE cfd.id = field_definition_id
                          AND cfd.organization_id = auth.user_organization_id()
                          )
                          );

-- =====================================================
-- SEARCH AND AUDIT POLICIES
-- =====================================================

-- Global search index: Users can search in their organization
CREATE POLICY "Users can search in their organization" ON global_search_index
    FOR SELECT USING (organization_id = auth.user_organization_id());

-- Search queries: Users can see their own search queries
CREATE POLICY "Users can see their own search queries" ON search_queries
    FOR SELECT USING (
                   organization_id = auth.user_organization_id()
                   AND (user_id = auth.uid() OR auth.is_admin())
                   );

-- Audit logs: Users can see audit logs for their organization (admins only for sensitive data)
CREATE POLICY "Users can see audit logs in their organization" ON audit_logs
    FOR SELECT USING (
                   organization_id = auth.user_organization_id()
                   AND (
                   auth.is_admin() OR
                   user_id = auth.uid()
                   )
                   );

-- =====================================================
-- SPECIAL POLICIES FOR SYSTEM OPERATIONS
-- =====================================================

-- Allow service role to bypass RLS for system operations
CREATE POLICY "Service role can bypass RLS" ON organizations
    FOR ALL TO service_role USING (TRUE);

CREATE POLICY "Service role can bypass RLS" ON user_profiles
    FOR ALL TO service_role USING (TRUE);

CREATE POLICY "Service role can bypass RLS" ON contacts
    FOR ALL TO service_role USING (TRUE);

CREATE POLICY "Service role can bypass RLS" ON companies
    FOR ALL TO service_role USING (TRUE);

CREATE POLICY "Service role can bypass RLS" ON deals
    FOR ALL TO service_role USING (TRUE);

CREATE POLICY "Service role can bypass RLS" ON activities
    FOR ALL TO service_role USING (TRUE);

-- =====================================================
-- RLS POLICY GRANTS
-- =====================================================

-- Grant necessary permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant permissions to service role
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- =====================================================
-- RLS TESTING FUNCTIONS
-- =====================================================

-- Function to test RLS policies
CREATE OR REPLACE FUNCTION test_rls_policies()
RETURNS TABLE (
    table_name TEXT,
    policy_count INTEGER,
    rls_enabled BOOLEAN
) AS $$
BEGIN
RETURN QUERY
SELECT
    t.tablename::TEXT,
    COUNT(p.policyname)::INTEGER as policy_count,
    t.rowsecurity as rls_enabled
FROM pg_tables t
         LEFT JOIN pg_policies p ON t.tablename = p.tablename
WHERE t.schemaname = 'public'
  AND t.tablename NOT LIKE 'pg_%'
GROUP BY t.tablename, t.rowsecurity
ORDER BY t.tablename;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;