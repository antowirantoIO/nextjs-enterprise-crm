-- =====================================================
-- AUTH SETUP MIGRATION
-- Configure Supabase Auth settings and custom functions
-- Created: 2024-01-01 00:00:01 UTC
-- Author: antowirantoIO
-- =====================================================

-- Enable necessary auth extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- AUTH CONFIGURATION FUNCTIONS
-- =====================================================

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION auth.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
default_org_id UUID;
BEGIN
    -- Check if this is the first user (super admin)
    IF NOT EXISTS (SELECT 1 FROM user_profiles LIMIT 1) THEN
        -- Create default organization for first user
        INSERT INTO organizations (
            name,
            slug,
            description,
            subscription_plan,
            subscription_status
        ) VALUES (
            'Default Organization',
            'default-org',
            'Default organization for the first user',
            'enterprise',
            'active'
        ) RETURNING id INTO default_org_id;

        -- Create super admin profile
INSERT INTO user_profiles (
    id,
    organization_id,
    email,
    first_name,
    last_name,
    role,
    status,
    email_verified_at
) VALUES (
             NEW.id,
             default_org_id,
             NEW.email,
             COALESCE(NEW.raw_user_meta_data->>'first_name', split_part(NEW.email, '@', 1)),
             COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
             'super_admin',
             'active',
             CASE WHEN NEW.email_confirmed_at IS NOT NULL THEN NEW.email_confirmed_at ELSE NULL END
         );

-- Create default notification preferences
INSERT INTO notification_preferences (user_id) VALUES (NEW.id);

-- Create default organization settings
INSERT INTO organization_settings (organization_id) VALUES (default_org_id);

ELSE
        -- For subsequent users, they need to be invited to an organization
        -- Create a pending profile without organization
        INSERT INTO user_profiles (
            id,
            email,
            first_name,
            last_name,
            role,
            status,
            email_verified_at
        ) VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'first_name', split_part(NEW.email, '@', 1)),
            COALESCE(NEW.raw_user_meta_data->>'last_name', ''),
            'viewer',
            'pending_verification',
            CASE WHEN NEW.email_confirmed_at IS NOT NULL THEN NEW.email_confirmed_at ELSE NULL END
        );

        -- Create default notification preferences
INSERT INTO notification_preferences (user_id) VALUES (NEW.id);
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION auth.handle_new_user();

-- =====================================================
-- AUTH HELPER FUNCTIONS
-- =====================================================

-- Function to get user's current organization
CREATE OR REPLACE FUNCTION auth.get_user_organization()
RETURNS UUID AS $$
BEGIN
RETURN (
    SELECT organization_id
    FROM user_profiles
    WHERE id = auth.uid()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has permission
CREATE OR REPLACE FUNCTION auth.has_permission(permission_name TEXT)
RETURNS BOOLEAN AS $$
DECLARE
user_permissions JSONB;
    user_role_text TEXT;
BEGIN
SELECT role, permissions INTO user_role_text, user_permissions
FROM user_profiles
WHERE id = auth.uid();

-- Super admin has all permissions
IF user_role_text = 'super_admin' THEN
        RETURN TRUE;
END IF;

    -- Check custom permissions
    IF user_permissions ? permission_name THEN
        RETURN (user_permissions ->> permission_name)::BOOLEAN;
END IF;

    -- Default role-based permissions
CASE user_role_text
        WHEN 'admin' THEN
            RETURN permission_name IN ('create_users', 'manage_settings', 'view_analytics', 'manage_integrations');
WHEN 'manager' THEN
            RETURN permission_name IN ('view_analytics', 'manage_team');
WHEN 'sales_rep' THEN
            RETURN permission_name IN ('manage_contacts', 'manage_deals');
WHEN 'support' THEN
            RETURN permission_name IN ('manage_contacts', 'view_deals');
ELSE
            RETURN FALSE;
END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user last login
CREATE OR REPLACE FUNCTION auth.update_last_login()
RETURNS TRIGGER AS $$
BEGIN
UPDATE user_profiles
SET last_login_at = NOW()
WHERE id = NEW.id;

RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for updating last login
DROP TRIGGER IF EXISTS on_auth_user_login ON auth.users;
CREATE TRIGGER on_auth_user_login
    AFTER UPDATE OF last_sign_in_at ON auth.users
    FOR EACH ROW
    WHEN (OLD.last_sign_in_at IS DISTINCT FROM NEW.last_sign_in_at)
    EXECUTE FUNCTION auth.update_last_login();

-- =====================================================
-- EMAIL VERIFICATION FUNCTIONS
-- =====================================================

-- Function to handle email confirmation
CREATE OR REPLACE FUNCTION auth.handle_email_confirmation()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user profile when email is confirmed
    IF OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL THEN
UPDATE user_profiles
SET
    email_verified_at = NEW.email_confirmed_at,
    status = CASE
                 WHEN status = 'pending_verification' THEN 'active'
                 ELSE status
        END
WHERE id = NEW.id;
END IF;

RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for email confirmation
DROP TRIGGER IF EXISTS on_auth_email_confirmed ON auth.users;
CREATE TRIGGER on_auth_email_confirmed
    AFTER UPDATE OF email_confirmed_at ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION auth.handle_email_confirmation();

-- =====================================================
-- ORGANIZATION INVITATION FUNCTIONS
-- =====================================================

-- Function to invite user to organization
CREATE OR REPLACE FUNCTION invite_user_to_organization(
    user_email TEXT,
    org_id UUID,
    user_role user_role DEFAULT 'viewer',
    invited_by_user_id UUID DEFAULT auth.uid()
)
RETURNS UUID AS $$
DECLARE
target_user_id UUID;
    invitation_id UUID;
BEGIN
    -- Check if inviter has permission
    IF NOT auth.is_admin() THEN
        RAISE EXCEPTION 'Only admins can invite users';
END IF;

    -- Check if user exists
SELECT id INTO target_user_id
FROM auth.users
WHERE email = user_email;

IF target_user_id IS NULL THEN
        RAISE EXCEPTION 'User with email % not found', user_email;
END IF;

    -- Update user profile with organization
UPDATE user_profiles
SET
    organization_id = org_id,
    role = user_role,
    status = 'active'
WHERE id = target_user_id;

-- Create notification
INSERT INTO notifications (
    organization_id,
    recipient_id,
    sender_id,
    type,
    title,
    message,
    related_type,
    related_id
) VALUES (
             org_id,
             target_user_id,
             invited_by_user_id,
             'info',
             'Welcome to the organization!',
             'You have been added to the organization.',
             'organizations',
             org_id
         );

RETURN target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- SESSION MANAGEMENT
-- =====================================================

-- Function to clean up expired sessions
CREATE OR REPLACE FUNCTION auth.cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
deleted_count INTEGER;
BEGIN
    -- This would integrate with your session management
    -- For now, we'll create a placeholder

    -- Delete old audit logs (older than retention period)
DELETE FROM audit_logs
WHERE timestamp < NOW() - INTERVAL '1 year';

GET DIAGNOSTICS deleted_count = ROW_COUNT;
RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;