-- =====================================================
-- ACTIVITIES CALENDAR MIGRATION
-- Extended activity features, calendar integration, and scheduling
-- Created: 2024-01-01 00:00:07 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- ACTIVITY TEMPLATES & AUTOMATION
-- =====================================================

-- Activity templates table
CREATE TABLE activity_templates (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Template details
                                    name VARCHAR(255) NOT NULL,
                                    description TEXT,
                                    type activity_type NOT NULL,

    -- Default values
                                    default_title VARCHAR(255),
                                    default_description TEXT,
                                    default_duration_minutes INTEGER DEFAULT 30,

    -- Template settings
                                    is_active BOOLEAN DEFAULT TRUE,
                                    is_system_template BOOLEAN DEFAULT FALSE,

    -- Usage tracking
                                    usage_count INTEGER DEFAULT 0,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW(),
                                    deleted_at TIMESTAMPTZ
);

-- =====================================================
-- CALENDAR INTEGRATION
-- =====================================================

-- Calendar providers table
CREATE TABLE calendar_providers (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Provider details
                                    provider VARCHAR(50) NOT NULL, -- google, outlook, exchange, caldav
                                    provider_account_id VARCHAR(255),
                                    provider_account_email VARCHAR(255),

    -- Authentication
                                    access_token TEXT,
                                    refresh_token TEXT,
                                    token_expires_at TIMESTAMPTZ,

    -- Settings
                                    is_primary BOOLEAN DEFAULT FALSE,
                                    is_active BOOLEAN DEFAULT TRUE,
                                    sync_enabled BOOLEAN DEFAULT TRUE,

    -- Sync settings
                                    calendar_ids JSONB, -- Array of calendar IDs to sync
                                    last_sync_at TIMESTAMPTZ,
                                    sync_direction VARCHAR(20) DEFAULT 'bidirectional', -- inbound, outbound, bidirectional

    -- Metadata
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW(),

                                    UNIQUE(user_id, provider, provider_account_email)
);

-- External calendar events table (synced from external calendars)
CREATE TABLE external_calendar_events (
                                          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                          calendar_provider_id UUID NOT NULL REFERENCES calendar_providers(id) ON DELETE CASCADE,

    -- External event details
                                          external_event_id VARCHAR(255) NOT NULL,
                                          external_calendar_id VARCHAR(255),

    -- Event details
                                          title VARCHAR(500),
                                          description TEXT,
                                          location VARCHAR(500),

    -- Timing
                                          start_time TIMESTAMPTZ NOT NULL,
                                          end_time TIMESTAMPTZ NOT NULL,
                                          is_all_day BOOLEAN DEFAULT FALSE,
                                          timezone VARCHAR(50),

    -- Recurrence
                                          is_recurring BOOLEAN DEFAULT FALSE,
                                          recurrence_rule TEXT, -- RRULE format
                                          recurrence_master_id VARCHAR(255),

    -- Status
                                          status VARCHAR(20) DEFAULT 'confirmed', -- confirmed, tentative, cancelled

    -- Attendees
                                          attendees JSONB,
                                          organizer JSONB,

    -- CRM linking
                                          linked_activity_id UUID REFERENCES activities(id),
                                          auto_linked BOOLEAN DEFAULT FALSE,

    -- Sync metadata
                                          last_modified TIMESTAMPTZ,
                                          synced_at TIMESTAMPTZ DEFAULT NOW(),

                                          UNIQUE(calendar_provider_id, external_event_id)
);

-- =====================================================
-- MEETING ROOMS & RESOURCES
-- =====================================================

-- Meeting rooms table
CREATE TABLE meeting_rooms (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Room details
                               name VARCHAR(255) NOT NULL,
                               description TEXT,
                               location VARCHAR(255),
                               floor VARCHAR(50),
                               building VARCHAR(100),

    -- Capacity and features
                               capacity INTEGER,
                               features TEXT[], -- projector, video_conference, whiteboard, etc.

    -- Booking settings
                               is_bookable BOOLEAN DEFAULT TRUE,
                               requires_approval BOOLEAN DEFAULT FALSE,
                               advance_booking_days INTEGER DEFAULT 30,
                               max_booking_duration_hours INTEGER DEFAULT 8,

    -- Contact info
                               contact_person VARCHAR(255),
                               contact_email VARCHAR(255),
                               contact_phone VARCHAR(20),

    -- Metadata
                               created_by UUID REFERENCES user_profiles(id),
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),
                               deleted_at TIMESTAMPTZ
);

-- Room bookings table
CREATE TABLE room_bookings (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               room_id UUID NOT NULL REFERENCES meeting_rooms(id) ON DELETE CASCADE,
                               activity_id UUID REFERENCES activities(id) ON DELETE CASCADE,

    -- Booking details
                               start_time TIMESTAMPTZ NOT NULL,
                               end_time TIMESTAMPTZ NOT NULL,
                               purpose TEXT,

    -- Booking status
                               status VARCHAR(20) DEFAULT 'confirmed', -- pending, confirmed, cancelled

    -- Special requirements
                               setup_requirements TEXT,
                               catering_requirements TEXT,

    -- Metadata
                               booked_by UUID REFERENCES user_profiles(id),
                               booked_at TIMESTAMPTZ DEFAULT NOW(),
                               cancelled_at TIMESTAMPTZ,
                               cancelled_by UUID REFERENCES user_profiles(id),
                               cancellation_reason TEXT
);

-- =====================================================
-- ACTIVITY PARTICIPANTS & ATTENDEES
-- =====================================================

-- Activity participants table (who's involved in activities)
CREATE TABLE activity_participants (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,

    -- Participant details
                                       participant_type VARCHAR(20) NOT NULL, -- internal_user, contact, external_email
                                       user_id UUID REFERENCES user_profiles(id),
                                       contact_id UUID REFERENCES contacts(id),
                                       external_email VARCHAR(255),
                                       external_name VARCHAR(255),

    -- Participation details
                                       role VARCHAR(50) DEFAULT 'attendee', -- organizer, required, optional, attendee
                                       response_status VARCHAR(20) DEFAULT 'pending', -- pending, accepted, declined, tentative
                                       response_comment TEXT,
                                       response_at TIMESTAMPTZ,

    -- Notification settings
                                       send_invitations BOOLEAN DEFAULT TRUE,
                                       send_reminders BOOLEAN DEFAULT TRUE,

    -- Metadata
                                       added_by UUID REFERENCES user_profiles(id),
                                       added_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
                                       CHECK (
                                           (participant_type = 'internal_user' AND user_id IS NOT NULL) OR
                                           (participant_type = 'contact' AND contact_id IS NOT NULL) OR
                                           (participant_type = 'external_email' AND external_email IS NOT NULL)
                                           )
);

-- =====================================================
-- ACTIVITY SERIES & RECURRING ACTIVITIES
-- =====================================================

-- Activity series table (for recurring activities)
CREATE TABLE activity_series (
                                 id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                 organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Series details
                                 name VARCHAR(255) NOT NULL,
                                 description TEXT,

    -- Recurrence pattern
                                 recurrence_type VARCHAR(20) NOT NULL, -- daily, weekly, monthly, yearly, custom
                                 recurrence_interval INTEGER DEFAULT 1, -- Every N days/weeks/months
                                 recurrence_days_of_week INTEGER[], -- For weekly: [1,2,3,4,5] = Mon-Fri
                                 recurrence_day_of_month INTEGER, -- For monthly
                                 recurrence_week_of_month INTEGER, -- For monthly (first, second, etc.)
                                 recurrence_month_of_year INTEGER, -- For yearly

    -- Series boundaries
                                 series_start_date DATE NOT NULL,
                                 series_end_date DATE,
                                 max_occurrences INTEGER,

    -- Template for instances
                                 template_type activity_type,
                                 template_title VARCHAR(255),
                                 template_description TEXT,
                                 template_duration_minutes INTEGER DEFAULT 30,
                                 template_location VARCHAR(500),

    -- Status
                                 is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                 created_by UUID REFERENCES user_profiles(id),
                                 created_at TIMESTAMPTZ DEFAULT NOW(),
                                 updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activity series instances table
CREATE TABLE activity_series_instances (
                                           id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                           series_id UUID NOT NULL REFERENCES activity_series(id) ON DELETE CASCADE,
                                           activity_id UUID REFERENCES activities(id) ON DELETE SET NULL,

    -- Instance details
                                           instance_date DATE NOT NULL,
                                           scheduled_start_time TIMESTAMPTZ,

    -- Instance status
                                           status VARCHAR(20) DEFAULT 'scheduled', -- scheduled, completed, cancelled, rescheduled

    -- Override flags
                                           is_modified BOOLEAN DEFAULT FALSE,
                                           modification_notes TEXT,

    -- Metadata
                                           created_at TIMESTAMPTZ DEFAULT NOW(),

                                           UNIQUE(series_id, instance_date)
);

-- =====================================================
-- ACTIVITY FOLLOW-UPS & SEQUENCES
-- =====================================================

-- Activity sequences table (automated follow-up sequences)
CREATE TABLE activity_sequences (
                                    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Sequence details
                                    name VARCHAR(255) NOT NULL,
                                    description TEXT,

    -- Trigger conditions
                                    trigger_type VARCHAR(50) NOT NULL, -- deal_stage_change, contact_created, activity_completed
                                    trigger_conditions JSONB,

    -- Sequence settings
                                    is_active BOOLEAN DEFAULT TRUE,

    -- Metadata
                                    created_by UUID REFERENCES user_profiles(id),
                                    created_at TIMESTAMPTZ DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activity sequence steps table
CREATE TABLE activity_sequence_steps (
                                         id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                         sequence_id UUID NOT NULL REFERENCES activity_sequences(id) ON DELETE CASCADE,

    -- Step details
                                         step_number INTEGER NOT NULL,
                                         name VARCHAR(255) NOT NULL,

    -- Activity to create
                                         activity_type activity_type NOT NULL,
                                         activity_title VARCHAR(255),
                                         activity_description TEXT,

    -- Timing
                                         delay_days INTEGER DEFAULT 0,
                                         delay_hours INTEGER DEFAULT 0,

    -- Assignment
                                         assign_to_original_owner BOOLEAN DEFAULT TRUE,
                                         assign_to_user_id UUID REFERENCES user_profiles(id),

    -- Conditions
                                         skip_conditions JSONB, -- When to skip this step

                                         created_at TIMESTAMPTZ DEFAULT NOW(),

                                         UNIQUE(sequence_id, step_number)
);

-- Activity sequence enrollments table
CREATE TABLE activity_sequence_enrollments (
                                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                               sequence_id UUID NOT NULL REFERENCES activity_sequences(id) ON DELETE CASCADE,

    -- Enrollment target
                                               contact_id UUID REFERENCES contacts(id),
                                               deal_id UUID REFERENCES deals(id),
                                               company_id UUID REFERENCES companies(id),

    -- Enrollment status
                                               status VARCHAR(20) DEFAULT 'active', -- active, paused, completed, cancelled
                                               current_step INTEGER DEFAULT 1,

    -- Timing
                                               enrolled_at TIMESTAMPTZ DEFAULT NOW(),
                                               next_step_due_at TIMESTAMPTZ,
                                               completed_at TIMESTAMPTZ,

    -- Metadata
                                               enrolled_by UUID REFERENCES user_profiles(id),

    -- Constraints
                                               CHECK (
                                                   (contact_id IS NOT NULL) OR
                                                   (deal_id IS NOT NULL) OR
                                                   (company_id IS NOT NULL)
                                                   )
);

-- =====================================================
-- ACTIVITY ANALYTICS & REPORTING
-- =====================================================

-- Activity metrics table (daily aggregated metrics)
CREATE TABLE activity_metrics (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
                                  user_id UUID REFERENCES user_profiles(id),

    -- Metrics date
                                  metric_date DATE NOT NULL,

    -- Activity counts by type
                                  calls_scheduled INTEGER DEFAULT 0,
                                  calls_completed INTEGER DEFAULT 0,
                                  emails_sent INTEGER DEFAULT 0,
                                  meetings_scheduled INTEGER DEFAULT 0,
                                  meetings_completed INTEGER DEFAULT 0,
                                  tasks_created INTEGER DEFAULT 0,
                                  tasks_completed INTEGER DEFAULT 0,

    -- Time tracking
                                  total_time_minutes INTEGER DEFAULT 0,
                                  billable_time_minutes INTEGER DEFAULT 0,

    -- Quality metrics
                                  activities_on_time INTEGER DEFAULT 0,
                                  activities_late INTEGER DEFAULT 0,

    -- Revenue attribution
                                  activities_revenue_attributed DECIMAL(15,2) DEFAULT 0.00,

    -- Metadata
                                  calculated_at TIMESTAMPTZ DEFAULT NOW(),

                                  UNIQUE(organization_id, user_id, metric_date)
);

-- =====================================================
-- FUNCTIONS FOR ACTIVITIES
-- =====================================================

-- Function to create activity series instances
CREATE OR REPLACE FUNCTION generate_activity_series_instances(
    series_uuid UUID,
    start_date DATE,
    end_date DATE
)
RETURNS INTEGER AS $$
DECLARE
series_record RECORD;
current_date DATE;
    instance_count INTEGER := 0;
    next_date DATE;
BEGIN
    -- Get series details
SELECT * INTO series_record FROM activity_series WHERE id = series_uuid;

IF NOT FOUND THEN
        RAISE EXCEPTION 'Activity series not found';
END IF;

current_date := GREATEST(start_date, series_record.series_start_date);

    WHILE current_date <= LEAST(end_date, COALESCE(series_record.series_end_date, end_date)) LOOP
        -- Calculate next occurrence based on recurrence type
        CASE series_record.recurrence_type
            WHEN 'daily' THEN
                next_date := current_date + (series_record.recurrence_interval || ' days')::INTERVAL;
WHEN 'weekly' THEN
                -- For weekly, check if current day of week is in recurrence_days_of_week
                IF series_record.recurrence_days_of_week @> ARRAY[EXTRACT(DOW FROM current_date)::INTEGER] THEN
                    INSERT INTO activity_series_instances (
                        series_id, instance_date, scheduled_start_time
                    ) VALUES (
                        series_uuid,
                        current_date,
                        current_date + '09:00:00'::TIME -- Default to 9 AM
                    ) ON CONFLICT (series_id, instance_date) DO NOTHING;

                    instance_count := instance_count + 1;
END IF;
                next_date := current_date + '1 day'::INTERVAL;
WHEN 'monthly' THEN
                IF EXTRACT(DAY FROM current_date) = series_record.recurrence_day_of_month THEN
                    INSERT INTO activity_series_instances (
                        series_id, instance_date, scheduled_start_time
                    ) VALUES (
                        series_uuid,
                        current_date,
                        current_date + '09:00:00'::TIME
                    ) ON CONFLICT (series_id, instance_date) DO NOTHING;

                    instance_count := instance_count + 1;
END IF;
                next_date := current_date + '1 day'::INTERVAL;
ELSE
                next_date := current_date + '1 day'::INTERVAL;
END CASE;

current_date := next_date;

        -- Safety check to prevent infinite loops
        IF instance_count > 1000 THEN
            EXIT;
END IF;
END LOOP;

RETURN instance_count;
END;
$$ LANGUAGE plpgsql;

-- Function to process activity sequence enrollments
CREATE OR REPLACE FUNCTION process_activity_sequence_enrollments()
RETURNS INTEGER AS $$
DECLARE
enrollment RECORD;
    sequence_step RECORD;
    processed_count INTEGER := 0;
    activity_id UUID;
BEGIN
    -- Process enrollments that are due for next step
FOR enrollment IN
SELECT * FROM activity_sequence_enrollments
WHERE status = 'active'
  AND next_step_due_at <= NOW()
    LOOP
-- Get the current step
SELECT * INTO sequence_step
FROM activity_sequence_steps
WHERE sequence_id = enrollment.sequence_id
  AND step_number = enrollment.current_step;

IF FOUND THEN
            -- Create the activity for this step
            INSERT INTO activities (
                organization_id,
                type,
                title,
                description,
                contact_id,
                deal_id,
                company_id,
                owner_id,
                scheduled_at,
                created_by
            ) VALUES (
                (SELECT organization_id FROM activity_sequences WHERE id = enrollment.sequence_id),
                sequence_step.activity_type,
                sequence_step.activity_title,
                sequence_step.activity_description,
                enrollment.contact_id,
                enrollment.deal_id,
                enrollment.company_id,
                COALESCE(sequence_step.assign_to_user_id, enrollment.enrolled_by),
                NOW() + INTERVAL '1 hour', -- Schedule for 1 hour from now
                enrollment.enrolled_by
            ) RETURNING id INTO activity_id;

            -- Move to next step or complete enrollment
            IF EXISTS (
                SELECT 1 FROM activity_sequence_steps
                WHERE sequence_id = enrollment.sequence_id
                AND step_number = enrollment.current_step + 1
            ) THEN
                -- Move to next step
UPDATE activity_sequence_enrollments
SET
    current_step = current_step + 1,
    next_step_due_at = NOW() +
    INTERVAL '1 day' * (
    SELECT delay_days FROM activity_sequence_steps
    WHERE sequence_id = enrollment.sequence_id
    AND step_number = enrollment.current_step + 1
    ) +
    INTERVAL '1 hour' * (
    SELECT delay_hours FROM activity_sequence_steps
    WHERE sequence_id = enrollment.sequence_id
    AND step_number = enrollment.current_step + 1
    )
WHERE id = enrollment.id;
ELSE
                -- Complete enrollment
UPDATE activity_sequence_enrollments
SET
    status = 'completed',
    completed_at = NOW()
WHERE id = enrollment.id;
END IF;

            processed_count := processed_count + 1;
END IF;
END LOOP;

RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- Function to update activity metrics
CREATE OR REPLACE FUNCTION update_activity_metrics(metric_date_param DATE)
RETURNS VOID AS $$
BEGIN
    -- Update metrics for all users and organization level
INSERT INTO activity_metrics (
    organization_id,
    user_id,
    metric_date,
    calls_scheduled,
    calls_completed,
    emails_sent,
    meetings_scheduled,
    meetings_completed,
    tasks_created,
    tasks_completed,
    total_time_minutes
)
SELECT
    a.organization_id,
    a.owner_id as user_id,
    metric_date_param,
    COUNT(*) FILTER (WHERE a.type = 'call' AND a.scheduled_at::DATE = metric_date_param),
    COUNT(*) FILTER (WHERE a.type = 'call' AND a.completed_at::DATE = metric_date_param),
    COUNT(*) FILTER (WHERE a.type = 'email' AND a.created_at::DATE = metric_date_param),
    COUNT(*) FILTER (WHERE a.type = 'meeting' AND a.scheduled_at::DATE = metric_date_param),
    COUNT(*) FILTER (WHERE a.type = 'meeting' AND a.completed_at::DATE = metric_date_param),
    COUNT(*) FILTER (WHERE a.type = 'task' AND a.created_at::DATE = metric_date_param),
    COUNT(*) FILTER (WHERE a.type = 'task' AND a.completed_at::DATE = metric_date_param),
    COALESCE(SUM(a.duration_minutes), 0)
FROM activities a
WHERE (a.created_at::DATE = metric_date_param OR
           a.scheduled_at::DATE = metric_date_param OR
           a.completed_at::DATE = metric_date_param)
  AND a.deleted_at IS NULL
GROUP BY a.organization_id, a.owner_id
    ON CONFLICT (organization_id, user_id, metric_date)
    DO UPDATE SET
    calls_scheduled = EXCLUDED.calls_scheduled,
               calls_completed = EXCLUDED.calls_completed,
               emails_sent = EXCLUDED.emails_sent,
               meetings_scheduled = EXCLUDED.meetings_scheduled,
               meetings_completed = EXCLUDED.meetings_completed,
               tasks_created = EXCLUDED.tasks_created,
               tasks_completed = EXCLUDED.tasks_completed,
               total_time_minutes = EXCLUDED.total_time_minutes,
               calculated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES
-- =====================================================

-- Activity templates indexes
CREATE INDEX idx_activity_templates_organization_id ON activity_templates(organization_id);
CREATE INDEX idx_activity_templates_type ON activity_templates(type);

-- Calendar providers indexes
CREATE INDEX idx_calendar_providers_user_id ON calendar_providers(user_id);
CREATE INDEX idx_calendar_providers_provider ON calendar_providers(provider);

-- External calendar events indexes
CREATE INDEX idx_external_calendar_events_provider_id ON external_calendar_events(calendar_provider_id);
CREATE INDEX idx_external_calendar_events_start_time ON external_calendar_events(start_time);
CREATE INDEX idx_external_calendar_events_linked_activity ON external_calendar_events(linked_activity_id);

-- Meeting rooms indexes
CREATE INDEX idx_meeting_rooms_organization_id ON meeting_rooms(organization_id);
CREATE INDEX idx_meeting_rooms_bookable ON meeting_rooms(is_bookable);

-- Room bookings indexes
CREATE INDEX idx_room_bookings_room_id ON room_bookings(room_id);
CREATE INDEX idx_room_bookings_activity_id ON room_bookings(activity_id);
CREATE INDEX idx_room_bookings_start_time ON room_bookings(start_time);

-- Activity participants indexes
CREATE INDEX idx_activity_participants_activity_id ON activity_participants(activity_id);
CREATE INDEX idx_activity_participants_user_id ON activity_participants(user_id);
CREATE INDEX idx_activity_participants_contact_id ON activity_participants(contact_id);

-- Activity series indexes
CREATE INDEX idx_activity_series_organization_id ON activity_series(organization_id);
CREATE INDEX idx_activity_series_start_date ON activity_series(series_start_date);

-- Activity sequence indexes
CREATE INDEX idx_activity_sequences_organization_id ON activity_sequences(organization_id);
CREATE INDEX idx_activity_sequence_enrollments_sequence_id ON activity_sequence_enrollments(sequence_id);
CREATE INDEX idx_activity_sequence_enrollments_due_at ON activity_sequence_enrollments(next_step_due_at);

-- Activity metrics indexes
CREATE INDEX idx_activity_metrics_organization_id ON activity_metrics(organization_id);
CREATE INDEX idx_activity_metrics_user_date ON activity_metrics(user_id, metric_date);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE TRIGGER update_activity_templates_updated_at BEFORE UPDATE ON activity_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_calendar_providers_updated_at BEFORE UPDATE ON calendar_providers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_meeting_rooms_updated_at BEFORE UPDATE ON meeting_rooms FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_activity_series_updated_at BEFORE UPDATE ON activity_series FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_activity_sequences_updated_at BEFORE UPDATE ON activity_sequences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();