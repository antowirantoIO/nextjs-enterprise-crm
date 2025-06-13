-- =====================================================
-- USER PROFILES MIGRATION
-- Enhanced user profile management and authentication setup
-- Created: 2024-01-01 00:00:02 UTC
-- Author: antowirantoIO
-- =====================================================

-- =====================================================
-- USER PROFILES TABLE ENHANCEMENT
-- =====================================================

-- Enhanced user profiles table (replacing the basic one from auth setup)
DROP TABLE IF EXISTS user_profiles CASCADE;

CREATE TABLE user_profiles (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Authentication reference (from Supabase Auth)
                               auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Organization relationship (will be added after organizations table exists)
                               organization_id UUID, -- FK will be added in organizations migration

    -- Basic profile information
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

    -- Contact information
                               phone VARCHAR(20),
                               timezone VARCHAR(50) DEFAULT 'UTC',
                               locale VARCHAR(10) DEFAULT 'en',

    -- Profile customization
                               avatar_url VARCHAR(500),
                               bio TEXT,

    -- Professional information
                               job_title VARCHAR(150),
                               department VARCHAR(100),

    -- User role and permissions
                               role user_role DEFAULT 'user',

    -- User preferences
                               preferences JSONB DEFAULT '{}',

    -- Account status
                               status user_status DEFAULT 'pending',

    -- Authentication settings
                               email_verified BOOLEAN DEFAULT FALSE,
                               phone_verified BOOLEAN DEFAULT FALSE,
                               two_factor_enabled BOOLEAN DEFAULT FALSE,

    -- Login tracking
                               last_login_at TIMESTAMPTZ,
                               last_login_ip INET,
                               login_count INTEGER DEFAULT 0,

    -- Password and security
                               password_changed_at TIMESTAMPTZ,
                               password_expires_at TIMESTAMPTZ,
                               failed_login_attempts INTEGER DEFAULT 0,
                               locked_until TIMESTAMPTZ,

    -- Terms and compliance
                               terms_accepted_at TIMESTAMPTZ,
                               privacy_policy_accepted_at TIMESTAMPTZ,
                               marketing_emails_consent BOOLEAN DEFAULT FALSE,

    -- Onboarding and experience
                               onboarding_completed BOOLEAN DEFAULT FALSE,
                               onboarding_step VARCHAR(50),
                               first_login_at TIMESTAMPTZ,

    -- API access
                               api_access_enabled BOOLEAN DEFAULT FALSE,
                               api_rate_limit INTEGER DEFAULT 1000, -- requests per hour

    -- Metadata
                               metadata JSONB DEFAULT '{}',

    -- Audit fields
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               updated_at TIMESTAMPTZ DEFAULT NOW(),
                               deleted_at TIMESTAMPTZ,

    -- Constraints
                               CONSTRAINT check_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT check_phone_format CHECK (phone IS NULL OR LENGTH(phone) >= 10),
    CONSTRAINT check_failed_attempts CHECK (failed_login_attempts >= 0),
    CONSTRAINT check_login_count CHECK (login_count >= 0)
);

-- =====================================================
-- USER SESSIONS TABLE
-- =====================================================

-- User sessions for tracking active sessions
CREATE TABLE user_sessions (
                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                               user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Session details
                               session_token VARCHAR(255) NOT NULL UNIQUE,
                               refresh_token VARCHAR(255),

    -- Session metadata
                               ip_address INET,
                               user_agent TEXT,
                               device_type VARCHAR(50), -- desktop, mobile, tablet
                               browser VARCHAR(100),
                               operating_system VARCHAR(100),

    -- Geographic information
                               country VARCHAR(100),
                               city VARCHAR(100),

    -- Session status
                               is_active BOOLEAN DEFAULT TRUE,

    -- Session lifecycle
                               created_at TIMESTAMPTZ DEFAULT NOW(),
                               last_activity_at TIMESTAMPTZ DEFAULT NOW(),
                               expires_at TIMESTAMPTZ,
                               ended_at TIMESTAMPTZ,

    -- Security flags
                               is_suspicious BOOLEAN DEFAULT FALSE,
                               risk_score INTEGER DEFAULT 0, -- 0-100

    -- Session metadata
                               metadata JSONB DEFAULT '{}'
);

-- =====================================================
-- USER INVITATIONS TABLE
-- =====================================================

-- User invitations for organization member invites
CREATE TABLE user_invitations (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Invitation details
                                  email VARCHAR(255) NOT NULL,
                                  role user_role DEFAULT 'user',

    -- Invitation metadata
                                  invitation_token VARCHAR(255) NOT NULL UNIQUE,
                                  invited_by UUID REFERENCES user_profiles(id),

    -- Invitation message
                                  custom_message TEXT,

    -- Invitation status
                                  status VARCHAR(20) DEFAULT 'pending', -- pending, accepted, rejected, expired, cancelled

    -- Invitation lifecycle
                                  invited_at TIMESTAMPTZ DEFAULT NOW(),
                                  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days'),
                                  accepted_at TIMESTAMPTZ,
                                  rejected_at TIMESTAMPTZ,

    -- Associated user (after acceptance)
                                  user_id UUID REFERENCES user_profiles(id),

    -- Metadata
                                  metadata JSONB DEFAULT '{}'
);

-- =====================================================
-- USER PREFERENCES MANAGEMENT
-- =====================================================

-- User notification preferences
CREATE TABLE user_notification_preferences (
                                               id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                               user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Notification channels
                                               email_enabled BOOLEAN DEFAULT TRUE,
                                               push_enabled BOOLEAN DEFAULT TRUE,
                                               sms_enabled BOOLEAN DEFAULT FALSE,
                                               in_app_enabled BOOLEAN DEFAULT TRUE,

    -- Notification types
                                               marketing_emails BOOLEAN DEFAULT FALSE,
                                               product_updates BOOLEAN DEFAULT TRUE,
                                               security_alerts BOOLEAN DEFAULT TRUE,

    -- Activity notifications
                                               mentions BOOLEAN DEFAULT TRUE,
                                               comments BOOLEAN DEFAULT TRUE,
                                               assignments BOOLEAN DEFAULT TRUE,
                                               due_dates BOOLEAN DEFAULT TRUE,

    -- Frequency settings
                                               digest_frequency VARCHAR(20) DEFAULT 'daily', -- immediate, daily, weekly, monthly, never
                                               quiet_hours_start TIME DEFAULT '22:00:00',
                                               quiet_hours_end TIME DEFAULT '08:00:00',
                                               weekend_notifications BOOLEAN DEFAULT FALSE,

    -- Custom preferences
                                               custom_preferences JSONB DEFAULT '{}',

    -- Metadata
                                               updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- USER ACTIVITY TRACKING
-- =====================================================

-- User activity log for behavioral analytics
CREATE TABLE user_activity_log (
                                   id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                   user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
                                   session_id UUID REFERENCES user_sessions(id) ON DELETE SET NULL,

    -- Activity details
                                   activity_type VARCHAR(50) NOT NULL, -- login, logout, page_view, action, api_call
                                   activity_name VARCHAR(100),

    -- Activity context
                                   page_url VARCHAR(1000),
                                   referrer_url VARCHAR(1000),

    -- Request details
                                   request_method VARCHAR(10),
                                   request_path VARCHAR(1000),

    -- Response details
                                   response_status INTEGER,
                                   response_time_ms INTEGER,

    -- Client information
                                   ip_address INET,
                                   user_agent TEXT,

    -- Activity metadata
                                   metadata JSONB DEFAULT '{}',

    -- Timestamp
                                   created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- PASSWORD HISTORY
-- =====================================================

-- Password history to prevent reuse
CREATE TABLE user_password_history (
                                       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                       user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Password details (hashed)
                                       password_hash VARCHAR(255) NOT NULL,
                                       password_salt VARCHAR(255),

    -- Password metadata
                                       created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Keep only last 12 passwords
                                       CONSTRAINT unique_user_password UNIQUE (user_id, password_hash)
);

-- =====================================================
-- SECURITY SETTINGS
-- =====================================================

-- User security settings
CREATE TABLE user_security_settings (
                                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                        user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Two-factor authentication
                                        two_factor_secret VARCHAR(255),
                                        two_factor_backup_codes TEXT[],
                                        two_factor_enabled_at TIMESTAMPTZ,

    -- Security preferences
                                        require_password_change BOOLEAN DEFAULT FALSE,
                                        password_expiry_days INTEGER DEFAULT 90,
                                        session_timeout_minutes INTEGER DEFAULT 480, -- 8 hours

    -- Login restrictions
                                        allowed_ip_ranges INET[],
                                        blocked_countries VARCHAR(2)[], -- ISO country codes

    -- Security notifications
                                        login_notifications BOOLEAN DEFAULT TRUE,
                                        device_change_notifications BOOLEAN DEFAULT TRUE,
                                        permission_change_notifications BOOLEAN DEFAULT TRUE,

    -- Account recovery
                                        recovery_email VARCHAR(255),
                                        recovery_phone VARCHAR(20),

    -- Security questions (hashed answers)
                                        security_questions JSONB,

    -- Metadata
                                        updated_at TIMESTAMPTZ DEFAULT NOW(),

                                        UNIQUE(user_id)
);

-- =====================================================
-- USER ROLES AND PERMISSIONS
-- =====================================================

-- Custom permissions for fine-grained access control
CREATE TABLE user_permissions (
                                  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                                  user_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- Permission details
                                  permission_type VARCHAR(50) NOT NULL, -- read, write, delete, admin
                                  resource_type VARCHAR(50) NOT NULL, -- contacts, companies, deals, reports, etc.
                                  resource_id UUID, -- Specific resource ID or NULL for all

    -- Permission scope
                                  scope VARCHAR(50) DEFAULT 'own', -- own, team, organization, all

    -- Permission metadata
                                  granted_by UUID REFERENCES user_profiles(id),
                                  granted_at TIMESTAMPTZ DEFAULT NOW(),
                                  expires_at TIMESTAMPTZ,

    -- Status
                                  is_active BOOLEAN DEFAULT TRUE,

                                  UNIQUE(user_id, permission_type, resource_type, resource_id)
);

-- =====================================================
-- FUNCTIONS FOR USER MANAGEMENT
-- =====================================================

-- Function to create user profile from auth user
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
DECLARE
user_email TEXT;
    name_parts TEXT[];
BEGIN
    -- Get email from auth.users
    user_email := NEW.email;

    -- Parse name if available
    IF NEW.raw_user_meta_data ? 'full_name' THEN
        name_parts := string_to_array(NEW.raw_user_meta_data->>'full_name', ' ');
END IF;

    -- Create user profile
INSERT INTO user_profiles (
    auth_user_id,
    email,
    first_name,
    last_name,
    email_verified,
    status,
    metadata
) VALUES (
             NEW.id,
             user_email,
             CASE WHEN array_length(name_parts, 1) >= 1 THEN name_parts[1] ELSE NULL END,
             CASE WHEN array_length(name_parts, 1) >= 2 THEN name_parts[2] ELSE NULL END,
             NEW.email_confirmed_at IS NOT NULL,
             CASE WHEN NEW.email_confirmed_at IS NOT NULL THEN 'active' ELSE 'pending' END,
             COALESCE(NEW.raw_user_meta_data, '{}')
         );

-- Create default notification preferences
INSERT INTO user_notification_preferences (user_id)
SELECT id FROM user_profiles WHERE auth_user_id = NEW.id;

-- Create default security settings
INSERT INTO user_security_settings (user_id)
SELECT id FROM user_profiles WHERE auth_user_id = NEW.id;

RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user profile when auth user changes
CREATE OR REPLACE FUNCTION update_user_profile()
RETURNS TRIGGER AS $$
BEGIN
UPDATE user_profiles
SET
    email = NEW.email,
    email_verified = (NEW.email_confirmed_at IS NOT NULL),
    updated_at = NOW()
WHERE auth_user_id = NEW.id;

RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle user login
CREATE OR REPLACE FUNCTION handle_user_login(
    user_uuid UUID,
    session_token_param VARCHAR(255),
    ip_address_param INET,
    user_agent_param TEXT
)
RETURNS UUID AS $$
DECLARE
session_id UUID;
    user_record RECORD;
BEGIN
    -- Get user details
SELECT * INTO user_record FROM user_profiles WHERE id = user_uuid;

IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
END IF;

    -- Check if user is locked
    IF user_record.locked_until IS NOT NULL AND user_record.locked_until > NOW() THEN
        RAISE EXCEPTION 'User account is locked';
END IF;

    -- Update user login tracking
UPDATE user_profiles
SET
    last_login_at = NOW(),
    last_login_ip = ip_address_param,
    login_count = login_count + 1,
    failed_login_attempts = 0,
    first_login_at = CASE WHEN first_login_at IS NULL THEN NOW() ELSE first_login_at END
WHERE id = user_uuid;

-- Create new session
INSERT INTO user_sessions (
    user_id,
    session_token,
    ip_address,
    user_agent,
    expires_at
) VALUES (
             user_uuid,
             session_token_param,
             ip_address_param,
             user_agent_param,
             NOW() + INTERVAL '24 hours'
         ) RETURNING id INTO session_id;

-- Log the login activity
INSERT INTO user_activity_log (
    user_id,
    session_id,
    activity_type,
    activity_name,
    ip_address,
    user_agent
) VALUES (
             user_uuid,
             session_id,
             'login',
             'user_login',
             ip_address_param,
             user_agent_param
         );

RETURN session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to handle failed login attempt
CREATE OR REPLACE FUNCTION handle_failed_login(
    user_email_param VARCHAR(255),
    ip_address_param INET,
    user_agent_param TEXT
)
RETURNS VOID AS $$
DECLARE
user_id UUID;
    failed_attempts INTEGER;
BEGIN
    -- Get user ID and current failed attempts
SELECT id, failed_login_attempts INTO user_id, failed_attempts
FROM user_profiles
WHERE email = user_email_param;

IF FOUND THEN
        -- Increment failed attempts
        failed_attempts := failed_attempts + 1;

UPDATE user_profiles
SET
    failed_login_attempts = failed_attempts,
    locked_until = CASE
                       WHEN failed_attempts >= 5 THEN NOW() + INTERVAL '30 minutes'
    ELSE locked_until
END
WHERE id = user_id;

        -- Log the failed attempt
INSERT INTO user_activity_log (
    user_id,
    activity_type,
    activity_name,
    ip_address,
    user_agent,
    metadata
) VALUES (
             user_id,
             'login',
             'failed_login',
             ip_address_param,
             user_agent_param,
             jsonb_build_object('attempt_number', failed_attempts)
         );
END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to end user session
CREATE OR REPLACE FUNCTION end_user_session(
    session_token_param VARCHAR(255)
)
RETURNS BOOLEAN AS $$
DECLARE
session_record RECORD;
BEGIN
    -- Get session details
SELECT * INTO session_record FROM user_sessions WHERE session_token = session_token_param;

IF NOT FOUND THEN
        RETURN FALSE;
END IF;

    -- End the session
UPDATE user_sessions
SET
    is_active = FALSE,
    ended_at = NOW()
WHERE session_token = session_token_param;

-- Log the logout
INSERT INTO user_activity_log (
    user_id,
    session_id,
    activity_type,
    activity_name
) VALUES (
             session_record.user_id,
             session_record.id,
             'logout',
             'user_logout'
         );

RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check user permissions
CREATE OR REPLACE FUNCTION check_user_permission(
    user_uuid UUID,
    permission_type_param VARCHAR(50),
    resource_type_param VARCHAR(50),
    resource_id_param UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
user_record RECORD;
    has_permission BOOLEAN := FALSE;
BEGIN
    -- Get user details
SELECT * INTO user_record FROM user_profiles WHERE id = user_uuid;

IF NOT FOUND THEN
        RETURN FALSE;
END IF;

    -- Check if user is super admin (has all permissions)
    IF user_record.role = 'super_admin' THEN
        RETURN TRUE;
END IF;

    -- Check specific permissions
SELECT TRUE INTO has_permission
FROM user_permissions
WHERE user_id = user_uuid
  AND permission_type = permission_type_param
  AND resource_type = resource_type_param
  AND (resource_id IS NULL OR resource_id = resource_id_param)
  AND is_active = TRUE
  AND (expires_at IS NULL OR expires_at > NOW())
    LIMIT 1;

-- If specific permission not found, check role-based permissions
IF NOT FOUND THEN
        CASE user_record.role
            WHEN 'admin' THEN
                has_permission := permission_type_param IN ('read', 'write', 'delete');
WHEN 'manager' THEN
                has_permission := permission_type_param IN ('read', 'write');
WHEN 'sales_rep' THEN
                has_permission := permission_type_param IN ('read', 'write')
                    AND resource_type_param IN ('contacts', 'companies', 'deals', 'activities');
WHEN 'user' THEN
                has_permission := permission_type_param = 'read';
ELSE
                has_permission := FALSE;
END CASE;
END IF;

RETURN COALESCE(has_permission, FALSE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger to create user profile when auth user is created
-- This will be created after the auth schema is set up
-- For now, we'll comment it out
-- CREATE TRIGGER create_user_profile_trigger
--     AFTER INSERT ON auth.users
--     FOR EACH ROW
--     EXECUTE FUNCTION create_user_profile();

-- Trigger to update user profile when auth user is updated
-- CREATE TRIGGER update_user_profile_trigger
--     AFTER UPDATE ON auth.users
--     FOR EACH ROW
--     EXECUTE FUNCTION update_user_profile();

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_notification_preferences_updated_at
    BEFORE UPDATE ON user_notification_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_security_settings_updated_at
    BEFORE UPDATE ON user_security_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- INDEXES
-- =====================================================

-- User profiles indexes
CREATE INDEX idx_user_profiles_auth_user_id ON user_profiles(auth_user_id);
CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_profiles_organization_id ON user_profiles(organization_id);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);
CREATE INDEX idx_user_profiles_status ON user_profiles(status);
CREATE INDEX idx_user_profiles_last_login ON user_profiles(last_login_at);

-- User sessions indexes
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_active ON user_sessions(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);

-- User invitations indexes
CREATE INDEX idx_user_invitations_email ON user_invitations(email);
CREATE INDEX idx_user_invitations_token ON user_invitations(invitation_token);
CREATE INDEX idx_user_invitations_status ON user_invitations(status);
CREATE INDEX idx_user_invitations_expires ON user_invitations(expires_at);

-- User activity indexes
CREATE INDEX idx_user_activity_log_user_id ON user_activity_log(user_id);
CREATE INDEX idx_user_activity_log_session_id ON user_activity_log(session_id);
CREATE INDEX idx_user_activity_log_created_at ON user_activity_log(created_at);
CREATE INDEX idx_user_activity_log_activity_type ON user_activity_log(activity_type);

-- User permissions indexes
CREATE INDEX idx_user_permissions_user_id ON user_permissions(user_id);
CREATE INDEX idx_user_permissions_resource ON user_permissions(resource_type, resource_id);
CREATE INDEX idx_user_permissions_active ON user_permissions(is_active) WHERE is_active = TRUE;

-- =====================================================
-- INITIAL DATA
-- =====================================================

-- Insert default notification preferences template
-- This will be used when creating new users

-- Insert default security settings template
-- This will be used when creating new users

-- =====================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON TABLE user_profiles IS 'Extended user profiles with comprehensive user management features';
COMMENT ON TABLE user_sessions IS 'Active user sessions for authentication and security tracking';
COMMENT ON TABLE user_invitations IS 'User invitation system for organization member management';
COMMENT ON TABLE user_notification_preferences IS 'User-specific notification preferences and settings';
COMMENT ON TABLE user_activity_log IS 'Comprehensive user activity tracking for analytics and security';
COMMENT ON TABLE user_password_history IS 'Password history to prevent password reuse';
COMMENT ON TABLE user_security_settings IS 'Advanced security settings and two-factor authentication';
COMMENT ON TABLE user_permissions IS 'Fine-grained permission system for access control';

COMMENT ON COLUMN user_profiles.role IS 'User role determining base permissions: super_admin, admin, manager, sales_rep, user';
COMMENT ON COLUMN user_profiles.status IS 'User account status: pending, active, inactive, suspended, deleted';
COMMENT ON COLUMN user_sessions.risk_score IS 'Security risk score for the session (0-100)';
COMMENT ON COLUMN user_permissions.scope IS 'Permission scope: own (own records), team (team records), organization (all org records)';