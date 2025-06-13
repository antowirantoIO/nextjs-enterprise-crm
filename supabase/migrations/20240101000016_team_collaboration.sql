-- =====================================================
-- TEAM COLLABORATION MIGRATION
-- Enhanced team collaboration, communication, and project management
-- Created: 2025-06-13 20:26:49 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- COLLABORATION SPACES
-- =====================================================

-- Collaboration spaces table (project-like workspaces)
CREATE TABLE collaboration_spaces (
                                      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                      organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                      workspace_id UUID REFERENCES workspaces(id),

    -- Space details
                                      name VARCHAR(255) NOT NULL,
                                      description TEXT,
                                      purpose VARCHAR(100), -- project, campaign, deal_room, customer_success, etc.

    -- Space configuration
                                      space_type VARCHAR(50) DEFAULT 'general', -- general, project, deal_room, customer_space
                                      privacy_level VARCHAR(20) DEFAULT 'team', -- public, team, private, invite_only

    -- Visual customization
                                      color VARCHAR(7), -- Hex color
                                      icon VARCHAR(50),
                                      cover_image_url VARCHAR(500),

    -- Space settings
                                      auto_archive_after_days INTEGER DEFAULT 90,
                                      allow_external_members BOOLEAN DEFAULT FALSE,
                                      enable_guest_access BOOLEAN DEFAULT FALSE,

    -- Related entities
                                      related_contact_id UUID REFERENCES contacts(id),
                                      related_company_id UUID REFERENCES companies(id),
                                      related_deal_id UUID REFERENCES deals(id),

    -- Space status
                                      status VARCHAR(20) DEFAULT 'active', -- active, archived, completed, on_hold
                                      is_template BOOLEAN DEFAULT FALSE,

    -- Dates
                                      start_date DATE,
                                      target_end_date DATE,
                                      actual_end_date DATE,
                                      archived_at TIMESTAMPTZ,

    -- Statistics
                                      member_count INTEGER DEFAULT 0,
                                      message_count INTEGER DEFAULT 0,
                                      file_count INTEGER DEFAULT 0,
                                      last_activity_at TIMESTAMPTZ,

    -- Metadata
                                      created_by UUID REFERENCES user_profiles(id),
                                      created_at TIMESTAMPTZ DEFAULT NOW(),
                                      updated_at TIMESTAMPTZ DEFAULT NOW(),
                                      deleted_at TIMESTAMPTZ
);

-- Space members table
CREATE TABLE space_members (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               space_id UUID NOT NULL REFERENCES collaboration_spaces(id) ON DELETE CASCADE,
                               user_id UUID REFERENCES user_profiles(id),

    -- External members (guests, clients, etc.)
                               external_email VARCHAR(255),
                               external_name VARCHAR(255),

    -- Member role in space
                               role VARCHAR(50) DEFAULT 'member', -- owner, admin, member, viewer, guest

    -- Permissions
                               can_invite_members BOOLEAN DEFAULT FALSE,
                               can_manage_space BOOLEAN DEFAULT FALSE,
                               can_delete_messages BOOLEAN DEFAULT FALSE,
                               can_upload_files BOOLEAN DEFAULT TRUE,

    -- Member status
                               status VARCHAR(20) DEFAULT 'active', -- active, inactive, pending, removed

    -- Invitation details
                               invited_by UUID REFERENCES user_profiles(id),
                               invited_at TIMESTAMPTZ,
                               joined_at TIMESTAMPTZ,

    -- Activity tracking
                               last_read_at TIMESTAMPTZ,
                               last_activity_at TIMESTAMPTZ,

    -- Notification preferences
                               notification_level VARCHAR(20) DEFAULT 'all', -- all, mentions, none

    -- Metadata
                               added_at TIMESTAMPTZ DEFAULT NOW(),

                               UNIQUE(space_id, user_id),
                               UNIQUE(space_id, external_email),
                               CHECK (
                                   (user_id IS NOT NULL AND external_email IS NULL) OR
                                   (user_id IS NULL AND external_email IS NOT NULL)
                                   )
);

-- =====================================================
-- TEAM COMMUNICATION
-- =====================================================

-- Team messages table (chat/discussion system)
CREATE TABLE team_messages (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               space_id UUID NOT NULL REFERENCES collaboration_spaces(id) ON DELETE CASCADE,
                               author_id UUID REFERENCES user_profiles(id),

    -- External author (for guests)
                               external_author_email VARCHAR(255),
                               external_author_name VARCHAR(255),

    -- Message content
                               content TEXT NOT NULL,
                               content_type VARCHAR(20) DEFAULT 'text', -- text, html, markdown

    -- Message type
                               message_type VARCHAR(50) DEFAULT 'message', -- message, announcement, system, file_share

    -- Message threading
                               parent_message_id UUID REFERENCES team_messages(id) ON DELETE CASCADE,
                               thread_reply_count INTEGER DEFAULT 0,

    -- Message metadata
                               mentions UUID[], -- User IDs mentioned in the message
                               attachments JSONB DEFAULT '[]', -- Array of attachment objects

    -- Message reactions
                               reactions JSONB DEFAULT '{}', -- {emoji: [user_ids]}

    -- Message status
                               is_edited BOOLEAN DEFAULT FALSE,
                               is_deleted BOOLEAN DEFAULT FALSE,
                               is_pinned BOOLEAN DEFAULT FALSE,

    -- Priority and urgency
                               priority VARCHAR(20) DEFAULT 'normal', -- low, normal, high, urgent

    -- Related entities
                               related_contact_id UUID REFERENCES contacts(id),
                               related_company_id UUID REFERENCES companies(id),
                               related_deal_id UUID REFERENCES deals(id),

    -- Message visibility
                               is_private BOOLEAN DEFAULT FALSE, -- Only visible to mentioned users

    -- Metadata
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),
                               deleted_at TIMESTAMPTZ,

                               CHECK (
                                   (author_id IS NOT NULL AND external_author_email IS NULL) OR
                                   (author_id IS NULL AND external_author_email IS NOT NULL)
                                   )
);

-- Message read receipts table
CREATE TABLE message_read_receipts (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       message_id UUID NOT NULL REFERENCES team_messages(id) ON DELETE CASCADE,
                                       user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Read tracking
                                       read_at TIMESTAMPTZ DEFAULT NOW(),

                                       UNIQUE(message_id, user_id)
);

-- =====================================================
-- PROJECT MANAGEMENT
-- =====================================================

-- Project boards table (Kanban-style boards)
CREATE TABLE project_boards (
                                id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                space_id UUID NOT NULL REFERENCES collaboration_spaces(id) ON DELETE CASCADE,

    -- Board details
                                name VARCHAR(255) NOT NULL,
                                description TEXT,

    -- Board configuration
                                board_type VARCHAR(50) DEFAULT 'kanban', -- kanban, scrum, timeline, calendar

    -- Board settings
                                auto_archive_cards BOOLEAN DEFAULT FALSE,
                                archive_after_days INTEGER DEFAULT 30,

    -- Board layout
                                layout_config JSONB DEFAULT '{}',

    -- Board permissions
                                view_permissions VARCHAR(20) DEFAULT 'space_members', -- space_members, team, organization
                                edit_permissions VARCHAR(20) DEFAULT 'space_members',

    -- Status
                                is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                created_by UUID REFERENCES user_profiles(id),
                                created_at TIMESTAMPTZ DEFAULT NOW(),
                                updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Board columns table (for Kanban boards)
CREATE TABLE board_columns (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               board_id UUID NOT NULL REFERENCES project_boards(id) ON DELETE CASCADE,

    -- Column details
                               name VARCHAR(255) NOT NULL,
                               description TEXT,

    -- Column settings
                               position INTEGER NOT NULL DEFAULT 0,
                               max_cards INTEGER, -- WIP limit

    -- Column styling
                               color VARCHAR(7), -- Hex color

    -- Column behavior
                               is_done_column BOOLEAN DEFAULT FALSE,
                               auto_archive_cards BOOLEAN DEFAULT FALSE,

    -- Metadata
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Board cards table (tasks/items on boards)
CREATE TABLE board_cards (
                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                             board_id UUID NOT NULL REFERENCES project_boards(id) ON DELETE CASCADE,
                             column_id UUID NOT NULL REFERENCES board_columns(id),

    -- Card details
                             title VARCHAR(255) NOT NULL,
                             description TEXT,

    -- Card metadata
                             card_type VARCHAR(50) DEFAULT 'task', -- task, bug, feature, story, epic
                             priority VARCHAR(20) DEFAULT 'medium', -- low, medium, high, urgent

    -- Card assignment
                             assigned_to UUID[] DEFAULT '{}', -- Array of user IDs

    -- Card scheduling
                             due_date TIMESTAMPTZ,
                             start_date TIMESTAMPTZ,
                             estimated_hours DECIMAL(5,2),
                             actual_hours DECIMAL(5,2),

    -- Card positioning
                             position DECIMAL(10,5) NOT NULL DEFAULT 0, -- For drag & drop ordering

    -- Card labels/tags
                             labels TEXT[] DEFAULT '{}',

    -- Card relationships
                             parent_card_id UUID REFERENCES board_cards(id),
                             related_contact_id UUID REFERENCES contacts(id),
                             related_company_id UUID REFERENCES companies(id),
                             related_deal_id UUID REFERENCES deals(id),

    -- Card attachments
                             attachments JSONB DEFAULT '[]',

    -- Card checklist
                             checklist JSONB DEFAULT '[]', -- Array of checklist items
                             checklist_completed INTEGER DEFAULT 0,
                             checklist_total INTEGER DEFAULT 0,

    -- Card status
                             is_archived BOOLEAN DEFAULT FALSE,
                             completed_at TIMESTAMPTZ,

    -- Metadata
                             created_by UUID REFERENCES user_profiles(id),
                             created_at TIMESTAMPTZ DEFAULT NOW(),
                             updated_at TIMESTAMPTZ DEFAULT NOW(),
                             deleted_at TIMESTAMPTZ
);

-- Card comments table
CREATE TABLE card_comments (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               card_id UUID NOT NULL REFERENCES board_cards(id) ON DELETE CASCADE,
                               author_id UUID NOT NULL REFERENCES user_profiles(id),

    -- Comment content
                               content TEXT NOT NULL,
                               content_type VARCHAR(20) DEFAULT 'text',

    -- Comment metadata
                               attachments JSONB DEFAULT '[]',
                               mentions UUID[] DEFAULT '{}',

    -- Comment status
                               is_edited BOOLEAN DEFAULT FALSE,

    -- Metadata
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),
                               deleted_at TIMESTAMPTZ
);

-- =====================================================
-- COLLABORATIVE DOCUMENTS
-- =====================================================

-- Collaborative documents table
CREATE TABLE collaborative_documents (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         space_id UUID NOT NULL REFERENCES collaboration_spaces(id) ON DELETE CASCADE,

    -- Document details
                                         title VARCHAR(255) NOT NULL,
                                         content TEXT,
                                         content_type VARCHAR(20) DEFAULT 'markdown', -- markdown, html, plain_text

    -- Document type
                                         document_type VARCHAR(50) DEFAULT 'note', -- note, meeting_notes, requirements, proposal

    -- Document status
                                         status VARCHAR(20) DEFAULT 'draft', -- draft, review, approved, published, archived

    -- Version control
                                         version INTEGER DEFAULT 1,

    -- Collaborative editing
                                         is_locked BOOLEAN DEFAULT FALSE,
                                         locked_by UUID REFERENCES user_profiles(id),
                                         locked_at TIMESTAMPTZ,

    -- Document permissions
                                         edit_permissions VARCHAR(20) DEFAULT 'space_members',
                                         view_permissions VARCHAR(20) DEFAULT 'space_members',

    -- Document templates
                                         template_id UUID,

    -- Metadata
                                         created_by UUID REFERENCES user_profiles(id),
                                         last_edited_by UUID REFERENCES user_profiles(id),
                                         created_at TIMESTAMPTZ DEFAULT NOW(),
                                         updated_at TIMESTAMPTZ DEFAULT NOW(),
                                         deleted_at TIMESTAMPTZ
);

-- Document revisions table
CREATE TABLE document_revisions (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    document_id UUID NOT NULL REFERENCES collaborative_documents(id) ON DELETE CASCADE,

    -- Revision details
                                    version INTEGER NOT NULL,
                                    title VARCHAR(255),
                                    content TEXT,

    -- Change summary
                                    change_summary TEXT,

    -- Revision metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),

                                    UNIQUE(document_id, version)
);

-- =====================================================
-- TEAM CALENDAR & EVENTS
-- =====================================================

-- Team events table
CREATE TABLE team_events (
                             id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                             space_id UUID REFERENCES collaboration_spaces(id),
                             organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Event details
                             title VARCHAR(255) NOT NULL,
                             description TEXT,

    -- Event type
                             event_type VARCHAR(50) DEFAULT 'meeting', -- meeting, deadline, milestone, reminder, social

    -- Event timing
                             start_time TIMESTAMPTZ NOT NULL,
                             end_time TIMESTAMPTZ,
                             is_all_day BOOLEAN DEFAULT FALSE,
                             timezone VARCHAR(50) DEFAULT 'UTC',

    -- Event location
                             location VARCHAR(500),
                             location_type VARCHAR(20) DEFAULT 'physical', -- physical, virtual, hybrid
                             meeting_url VARCHAR(1000), -- For virtual meetings

    -- Event recurrence
                             is_recurring BOOLEAN DEFAULT FALSE,
                             recurrence_rule TEXT, -- RRULE format
                             recurrence_end_date DATE,

    -- Event participants
                             organizer_id UUID REFERENCES user_profiles(id),
                             participants JSONB DEFAULT '[]', -- Array of participant objects

    -- Event status
                             status VARCHAR(20) DEFAULT 'scheduled', -- scheduled, in_progress, completed, cancelled

    -- Event visibility
                             visibility VARCHAR(20) DEFAULT 'team', -- public, team, private

    -- Related entities
                             related_contact_id UUID REFERENCES contacts(id),
                             related_company_id UUID REFERENCES companies(id),
                             related_deal_id UUID REFERENCES deals(id),

    -- Reminders
                             reminders JSONB DEFAULT '[]', -- Array of reminder configurations

    -- Metadata
                             created_by UUID REFERENCES user_profiles(id),
                             created_at TIMESTAMPTZ DEFAULT NOW(),
                             updated_at TIMESTAMPTZ DEFAULT NOW(),
                             deleted_at TIMESTAMPTZ
);

-- Event attendees table
CREATE TABLE event_attendees (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 event_id UUID NOT NULL REFERENCES team_events(id) ON DELETE CASCADE,
                                 user_id UUID REFERENCES user_profiles(id),

    -- External attendees
                                 external_email VARCHAR(255),
                                 external_name VARCHAR(255),

    -- Attendance details
                                 response_status VARCHAR(20) DEFAULT 'pending', -- pending, accepted, declined, tentative
                                 attendance_status VARCHAR(20), -- attended, no_show, late

    -- Response metadata
                                 response_comment TEXT,
                                 responded_at TIMESTAMPTZ,

    -- Invitation details
                                 invited_at TIMESTAMPTZ DEFAULT NOW(),
                                 invitation_sent BOOLEAN DEFAULT FALSE,

                                 UNIQUE(event_id, user_id),
                                 UNIQUE(event_id, external_email),
                                 CHECK (
                                     (user_id IS NOT NULL AND external_email IS NULL) OR
                                     (user_id IS NULL AND external_email IS NOT NULL)
                                     )
);

-- =====================================================
-- KNOWLEDGE SHARING
-- =====================================================

-- Team knowledge articles table
CREATE TABLE knowledge_articles (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                    space_id UUID REFERENCES collaboration_spaces(id),

    -- Article details
                                    title VARCHAR(255) NOT NULL,
                                    content TEXT NOT NULL,
                                    excerpt TEXT,

    -- Article categorization
                                    category VARCHAR(100),
                                    tags TEXT[] DEFAULT '{}',

    -- Article type
                                    article_type VARCHAR(50) DEFAULT 'general', -- general, how_to, faq, process, policy

    -- Article status
                                    status VARCHAR(20) DEFAULT 'draft', -- draft, review, published, archived
                                    is_featured BOOLEAN DEFAULT FALSE,

    -- Article visibility
                                    visibility VARCHAR(20) DEFAULT 'organization', -- public, organization, team, space

    -- Article metrics
                                    view_count INTEGER DEFAULT 0,
                                    helpful_votes INTEGER DEFAULT 0,
                                    not_helpful_votes INTEGER DEFAULT 0,

    -- SEO and search
                                    slug VARCHAR(255),
                                    meta_description TEXT,
                                    search_keywords TEXT[],

    -- Article relationships
                                    related_articles UUID[] DEFAULT '{}',

    -- Version control
                                    version INTEGER DEFAULT 1,

    -- Approval workflow
                                    reviewed_by UUID REFERENCES user_profiles(id),
                                    reviewed_at TIMESTAMPTZ,
                                    approved_by UUID REFERENCES user_profiles(id),
                                    approved_at TIMESTAMPTZ,

    -- Publishing
                                    published_at TIMESTAMPTZ,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    last_edited_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW(),
                                    deleted_at TIMESTAMPTZ,

                                    UNIQUE(organization_id, slug)
);

-- =====================================================
-- TEAM ANALYTICS & INSIGHTS
-- =====================================================

-- Team collaboration analytics table
CREATE TABLE team_collaboration_analytics (
                                              id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                              organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                              space_id UUID REFERENCES collaboration_spaces(id),

    -- Analytics period
                                              date DATE NOT NULL,

    -- Message statistics
                                              total_messages INTEGER DEFAULT 0,
                                              unique_message_authors INTEGER DEFAULT 0,

    -- Collaboration metrics
                                              active_spaces INTEGER DEFAULT 0,
                                              new_spaces_created INTEGER DEFAULT 0,

    -- Project metrics
                                              cards_created INTEGER DEFAULT 0,
                                              cards_completed INTEGER DEFAULT 0,

    -- Document metrics
                                              documents_created INTEGER DEFAULT 0,
                                              documents_edited INTEGER DEFAULT 0,

    -- Event metrics
                                              events_created INTEGER DEFAULT 0,
                                              events_attended INTEGER DEFAULT 0,

    -- Engagement metrics
                                              average_response_time_hours DECIMAL(5,2) DEFAULT 0,
                                              collaboration_score DECIMAL(3,2) DEFAULT 0, -- 0-100 score

    -- Top contributors
                                              top_contributors JSONB DEFAULT '{}', -- {user_id: activity_count}

    -- Metadata
                                              calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                              UNIQUE(organization_id, space_id, date)
);

-- =====================================================
-- FUNCTIONS FOR TEAM COLLABORATION
-- =====================================================

-- Function to update space member count
CREATE OR REPLACE FUNCTION update_space_member_count()
RETURNS TRIGGER AS $$
DECLARE
space_uuid UUID;
    member_count_val INTEGER;
BEGIN
    -- Get space ID
    IF TG_OP = 'DELETE' THEN
        space_uuid := OLD.space_id;
ELSE
        space_uuid := NEW.space_id;
END IF;

    -- Count active members
SELECT COUNT(*) INTO member_count_val
FROM space_members
WHERE space_id = space_uuid
  AND status = 'active';

-- Update space member count
UPDATE collaboration_spaces
SET
    member_count = member_count_val,
    last_activity_at = NOW()
WHERE id = space_uuid;

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating space member count
CREATE TRIGGER update_space_member_count_trigger
    AFTER INSERT OR UPDATE OR DELETE ON space_members
    FOR EACH ROW
    EXECUTE FUNCTION update_space_member_count();

-- Function to update message thread count
CREATE OR REPLACE FUNCTION update_message_thread_count()
RETURNS TRIGGER AS $$
DECLARE
parent_uuid UUID;
BEGIN
    -- Only process if this is a reply to another message
    IF NEW.parent_message_id IS NOT NULL THEN
        parent_uuid := NEW.parent_message_id;

        -- Update thread reply count
UPDATE team_messages
SET thread_reply_count = thread_reply_count + 1
WHERE id = parent_uuid;
END IF;

    -- Update space message count and last activity
UPDATE collaboration_spaces
SET
    message_count = message_count + 1,
    last_activity_at = NOW()
WHERE id = NEW.space_id;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating message counts
CREATE TRIGGER update_message_thread_count_trigger
    AFTER INSERT ON team_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_message_thread_count();

-- Function to update card checklist counts
CREATE OR REPLACE FUNCTION update_card_checklist_counts()
RETURNS TRIGGER AS $$
DECLARE
checklist_items JSONB;
    total_items INTEGER := 0;
    completed_items INTEGER := 0;
    item JSONB;
BEGIN
    -- Get checklist from new record
    checklist_items := NEW.checklist;

    -- Count total and completed items
    IF checklist_items IS NOT NULL AND jsonb_array_length(checklist_items) > 0 THEN
        total_items := jsonb_array_length(checklist_items);

FOR item IN SELECT * FROM jsonb_array_elements(checklist_items)
                              LOOP
    IF (item->>'completed')::BOOLEAN = TRUE THEN
                completed_items := completed_items + 1;
END IF;
END LOOP;
END IF;

    -- Update the counts
    NEW.checklist_total := total_items;
    NEW.checklist_completed := completed_items;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating checklist counts
CREATE TRIGGER update_card_checklist_counts_trigger
    BEFORE INSERT OR UPDATE ON board_cards
                         FOR EACH ROW
                         EXECUTE FUNCTION update_card_checklist_counts();

-- Function to create default board columns
CREATE OR REPLACE FUNCTION create_default_board_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Create default Kanban columns
    IF NEW.board_type = 'kanban' THEN
        INSERT INTO board_columns (board_id, name, position, color) VALUES
        (NEW.id, 'To Do', 1, '#6B7280'),
        (NEW.id, 'In Progress', 2, '#3B82F6'),
        (NEW.id, 'Review', 3, '#F59E0B'),
        (NEW.id, 'Done', 4, '#10B981');

        -- Mark the last column as done
UPDATE board_columns
SET is_done_column = TRUE
WHERE board_id = NEW.id AND name = 'Done';
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for creating default columns
CREATE TRIGGER create_default_board_columns_trigger
    AFTER INSERT ON project_boards
    FOR EACH ROW
    EXECUTE FUNCTION create_default_board_columns();

-- =====================================================
-- INDEXES
-- =====================================================

-- Collaboration spaces indexes
CREATE INDEX idx_collaboration_spaces_organization_id ON collaboration_spaces(organization_id);
CREATE INDEX idx_collaboration_spaces_workspace_id ON collaboration_spaces(workspace_id);
CREATE INDEX idx_collaboration_spaces_status ON collaboration_spaces(status);
CREATE INDEX idx_collaboration_spaces_space_type ON collaboration_spaces(space_type);

-- Space members indexes
CREATE INDEX idx_space_members_space_id ON space_members(space_id);
CREATE INDEX idx_space_members_user_id ON space_members(user_id);
CREATE INDEX idx_space_members_status ON space_members(status);

-- Team messages indexes
CREATE INDEX idx_team_messages_space_id ON team_messages(space_id);
CREATE INDEX idx_team_messages_author_id ON team_messages(author_id);
CREATE INDEX idx_team_messages_parent_message ON team_messages(parent_message_id);
CREATE INDEX idx_team_messages_created_at ON team_messages(created_at);
CREATE INDEX idx_team_messages_message_type ON team_messages(message_type);

-- Project boards indexes
CREATE INDEX idx_project_boards_space_id ON project_boards(space_id);

-- Board cards indexes
CREATE INDEX idx_board_cards_board_id ON board_cards(board_id);
CREATE INDEX idx_board_cards_column_id ON board_cards(column_id);
CREATE INDEX idx_board_cards_assigned_to ON board_cards USING GIN(assigned_to);
CREATE INDEX idx_board_cards_due_date ON board_cards(due_date);
CREATE INDEX idx_board_cards_position ON board_cards(column_id, position);

-- Collaborative documents indexes
CREATE INDEX idx_collaborative_documents_space_id ON collaborative_documents(space_id);
CREATE INDEX idx_collaborative_documents_status ON collaborative_documents(status);
CREATE INDEX idx_collaborative_documents_document_type ON collaborative_documents(document_type);

-- Team events indexes
CREATE INDEX idx_team_events_space_id ON team_events(space_id);
CREATE INDEX idx_team_events_organization_id ON team_events(organization_id);
CREATE INDEX idx_team_events_start_time ON team_events(start_time);
CREATE INDEX idx_team_events_organizer_id ON team_events(organizer_id);
CREATE INDEX idx_team_events_event_type ON team_events(event_type);

-- Knowledge articles indexes
CREATE INDEX idx_knowledge_articles_organization_id ON knowledge_articles(organization_id);
CREATE INDEX idx_knowledge_articles_space_id ON knowledge_articles(space_id);
CREATE INDEX idx_knowledge_articles_status ON knowledge_articles(status);
CREATE INDEX idx_knowledge_articles_category ON knowledge_articles(category);
CREATE INDEX idx_knowledge_articles_tags ON knowledge_articles USING GIN(tags);
CREATE INDEX idx_knowledge_articles_slug ON knowledge_articles(slug);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_collaboration_spaces_updated_at BEFORE UPDATE ON collaboration_spaces FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_team_messages_updated_at BEFORE UPDATE ON team_messages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_project_boards_updated_at BEFORE UPDATE ON project_boards FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_board_columns_updated_at BEFORE UPDATE ON board_columns FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_board_cards_updated_at BEFORE UPDATE ON board_cards FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_card_comments_updated_at BEFORE UPDATE ON card_comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_collaborative_documents_updated_at BEFORE UPDATE ON collaborative_documents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_team_events_updated_at BEFORE UPDATE ON team_events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_knowledge_articles_updated_at BEFORE UPDATE ON knowledge_articles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
