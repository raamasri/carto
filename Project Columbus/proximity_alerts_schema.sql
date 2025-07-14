-- ================================================================
-- PROXIMITY ALERTS DATABASE SCHEMA
-- Project Columbus - Social Discovery System
-- Generated: 2025-01-10
-- Version: 1.0
-- ================================================================

-- This schema creates the necessary database tables and policies
-- for the proximity alerts system in Project Columbus (Carto).
-- 
-- FEATURES:
-- - Real-time proximity detection between friends
-- - Privacy-preserving location sharing
-- - Social context with friend activity
-- - Availability status management
-- - Safe zones and privacy controls
-- - Notification system integration

-- ================================================================
-- PROXIMITY ALERTS TABLES
-- ================================================================

-- Location Updates table for real-time proximity detection
CREATE TABLE IF NOT EXISTS public.location_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    is_available BOOLEAN DEFAULT TRUE,
    availability_status TEXT DEFAULT 'available' CHECK (availability_status IN ('available', 'busy', 'do_not_disturb', 'invisible')),
    custom_status_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '1 hour')
);

-- Proximity Alert Settings table
CREATE TABLE IF NOT EXISTS public.proximity_alert_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT FALSE,
    location_privacy_tier TEXT DEFAULT 'disabled' CHECK (location_privacy_tier IN ('disabled', 'friends_only', 'select_friends', 'public')),
    proximity_radius DOUBLE PRECISION DEFAULT 500 CHECK (proximity_radius BETWEEN 100 AND 5000),
    notification_radius DOUBLE PRECISION DEFAULT 1000 CHECK (notification_radius BETWEEN 100 AND 10000),
    only_alert_when_available BOOLEAN DEFAULT TRUE,
    allow_background_sharing BOOLEAN DEFAULT FALSE,
    share_location_history BOOLEAN DEFAULT FALSE,
    share_visited_places BOOLEAN DEFAULT TRUE,
    share_activity_feed BOOLEAN DEFAULT TRUE,
    allow_location_recommendations BOOLEAN DEFAULT TRUE,
    quiet_hours_enabled BOOLEAN DEFAULT FALSE,
    quiet_hours_start TIME DEFAULT '22:00:00',
    quiet_hours_end TIME DEFAULT '08:00:00',
    max_notifications_per_hour INTEGER DEFAULT 3 CHECK (max_notifications_per_hour BETWEEN 1 AND 10),
    location_data_retention_days INTEGER DEFAULT 30 CHECK (location_data_retention_days BETWEEN 1 AND 365),
    auto_delete_location_history BOOLEAN DEFAULT TRUE,
    allow_group_proximity_alerts BOOLEAN DEFAULT TRUE,
    require_explicit_consent BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Friend Proximity Permissions table
CREATE TABLE IF NOT EXISTS public.friend_proximity_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT TRUE,
    can_see_exact_location BOOLEAN DEFAULT FALSE,
    can_see_availability BOOLEAN DEFAULT TRUE,
    can_send_proximity_alerts BOOLEAN DEFAULT TRUE,
    permission_level TEXT DEFAULT 'normal' CHECK (permission_level IN ('basic', 'normal', 'enhanced')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, friend_id)
);

-- Safe Zones table for privacy protection
CREATE TABLE IF NOT EXISTS public.safe_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius DOUBLE PRECISION NOT NULL CHECK (radius BETWEEN 50 AND 2000),
    is_enabled BOOLEAN DEFAULT TRUE,
    zone_type TEXT DEFAULT 'custom' CHECK (zone_type IN ('home', 'work', 'custom')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Proximity Alerts Log table for analytics and debugging
CREATE TABLE IF NOT EXISTS public.proximity_alerts_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL CHECK (alert_type IN ('friend_nearby', 'friend_at_location', 'friend_activity', 'friend_available', 'location_recommendation', 'group_activity')),
    distance DOUBLE PRECISION,
    location_name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    notification_sent BOOLEAN DEFAULT FALSE,
    was_throttled BOOLEAN DEFAULT FALSE,
    additional_context JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Location Social Context Cache table for performance
CREATE TABLE IF NOT EXISTS public.location_social_context (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location_name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius DOUBLE PRECISION NOT NULL,
    total_visits INTEGER DEFAULT 0,
    unique_visitors INTEGER DEFAULT 0,
    average_rating DOUBLE PRECISION DEFAULT 0,
    social_score DOUBLE PRECISION DEFAULT 0,
    friends_currently_here INTEGER DEFAULT 0,
    recent_activity_count INTEGER DEFAULT 0,
    last_visit_at TIMESTAMP WITH TIME ZONE,
    cached_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '1 hour'),
    UNIQUE(location_name, latitude, longitude, radius)
);

-- Notification Throttling table to prevent spam
CREATE TABLE IF NOT EXISTS public.notification_throttling (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    notification_type TEXT NOT NULL,
    throttle_key TEXT NOT NULL, -- e.g., "friend_nearby_user123"
    last_sent_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    send_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '24 hours'),
    UNIQUE(user_id, throttle_key)
);

-- ================================================================
-- INDEXES FOR PERFORMANCE
-- ================================================================

-- Location Updates indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_updates_user_id ON public.location_updates(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_updates_coordinates ON public.location_updates(latitude, longitude);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_updates_created_at ON public.location_updates(created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_updates_expires_at ON public.location_updates(expires_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_updates_availability ON public.location_updates(is_available, availability_status);

-- Proximity Alert Settings indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_proximity_settings_user_id ON public.proximity_alert_settings(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_proximity_settings_enabled ON public.proximity_alert_settings(is_enabled);

-- Friend Proximity Permissions indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_friend_proximity_user_id ON public.friend_proximity_permissions(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_friend_proximity_friend_id ON public.friend_proximity_permissions(friend_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_friend_proximity_enabled ON public.friend_proximity_permissions(is_enabled);

-- Safe Zones indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_safe_zones_user_id ON public.safe_zones(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_safe_zones_coordinates ON public.safe_zones(latitude, longitude);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_safe_zones_enabled ON public.safe_zones(is_enabled);

-- Proximity Alerts Log indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_proximity_log_user_id ON public.proximity_alerts_log(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_proximity_log_friend_id ON public.proximity_alerts_log(friend_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_proximity_log_type ON public.proximity_alerts_log(alert_type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_proximity_log_created_at ON public.proximity_alerts_log(created_at);

-- Location Social Context indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_context_coordinates ON public.location_social_context(latitude, longitude);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_context_expires_at ON public.location_social_context(expires_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_location_context_social_score ON public.location_social_context(social_score);

-- Notification Throttling indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notification_throttling_user_id ON public.notification_throttling(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notification_throttling_expires_at ON public.notification_throttling(expires_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notification_throttling_key ON public.notification_throttling(throttle_key);

-- ================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ================================================================

-- Enable RLS on all tables
ALTER TABLE public.location_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proximity_alert_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_proximity_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.safe_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proximity_alerts_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.location_social_context ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_throttling ENABLE ROW LEVEL SECURITY;

-- Location Updates policies
CREATE POLICY "Users can view their own location updates" ON public.location_updates
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own location updates" ON public.location_updates
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own location updates" ON public.location_updates
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own location updates" ON public.location_updates
    FOR DELETE USING (auth.uid() = user_id);

-- Friends can view location updates based on permissions
CREATE POLICY "Friends can view location updates with permission" ON public.location_updates
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.friend_proximity_permissions fpp
            WHERE fpp.user_id = location_updates.user_id
            AND fpp.friend_id = auth.uid()
            AND fpp.is_enabled = true
        )
    );

-- Proximity Alert Settings policies
CREATE POLICY "Users can manage their own proximity settings" ON public.proximity_alert_settings
    FOR ALL USING (auth.uid() = user_id);

-- Friend Proximity Permissions policies
CREATE POLICY "Users can manage their own friend permissions" ON public.friend_proximity_permissions
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view permissions granted to them" ON public.friend_proximity_permissions
    FOR SELECT USING (auth.uid() = friend_id);

-- Safe Zones policies
CREATE POLICY "Users can manage their own safe zones" ON public.safe_zones
    FOR ALL USING (auth.uid() = user_id);

-- Proximity Alerts Log policies
CREATE POLICY "Users can view their own proximity alerts log" ON public.proximity_alerts_log
    FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "System can insert proximity alerts log" ON public.proximity_alerts_log
    FOR INSERT WITH CHECK (true);

-- Location Social Context policies (public read, system write)
CREATE POLICY "Anyone can read location social context" ON public.location_social_context
    FOR SELECT USING (true);

CREATE POLICY "System can manage location social context" ON public.location_social_context
    FOR ALL USING (true);

-- Notification Throttling policies
CREATE POLICY "Users can view their own notification throttling" ON public.notification_throttling
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can manage notification throttling" ON public.notification_throttling
    FOR ALL USING (true);

-- ================================================================
-- FUNCTIONS AND TRIGGERS
-- ================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at columns
CREATE TRIGGER update_proximity_settings_updated_at
    BEFORE UPDATE ON public.proximity_alert_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_friend_permissions_updated_at
    BEFORE UPDATE ON public.friend_proximity_permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_safe_zones_updated_at
    BEFORE UPDATE ON public.safe_zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to clean up expired location updates
CREATE OR REPLACE FUNCTION cleanup_expired_location_updates()
RETURNS void AS $$
BEGIN
    DELETE FROM public.location_updates
    WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ language 'plpgsql';

-- Function to clean up expired social context cache
CREATE OR REPLACE FUNCTION cleanup_expired_social_context()
RETURNS void AS $$
BEGIN
    DELETE FROM public.location_social_context
    WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ language 'plpgsql';

-- Function to clean up expired notification throttling
CREATE OR REPLACE FUNCTION cleanup_expired_notification_throttling()
RETURNS void AS $$
BEGIN
    DELETE FROM public.notification_throttling
    WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ language 'plpgsql';

-- Function to get nearby friends for a user
CREATE OR REPLACE FUNCTION get_nearby_friends(
    p_user_id UUID,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius DOUBLE PRECISION DEFAULT 1000
)
RETURNS TABLE(
    friend_id UUID,
    friend_username TEXT,
    friend_display_name TEXT,
    friend_avatar_url TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance DOUBLE PRECISION,
    is_available BOOLEAN,
    availability_status TEXT,
    custom_status_message TEXT,
    last_updated TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.full_name,
        u.avatar_url,
        lu.latitude,
        lu.longitude,
        ST_Distance(
            ST_Point(p_longitude, p_latitude)::geography,
            ST_Point(lu.longitude, lu.latitude)::geography
        ) AS distance,
        lu.is_available,
        lu.availability_status,
        lu.custom_status_message,
        lu.created_at
    FROM public.users u
    JOIN public.location_updates lu ON u.id = lu.user_id
    JOIN public.follows f ON f.following_id = u.id
    JOIN public.friend_proximity_permissions fpp ON fpp.user_id = u.id
    WHERE f.follower_id = p_user_id
    AND fpp.friend_id = p_user_id
    AND fpp.is_enabled = true
    AND lu.expires_at > CURRENT_TIMESTAMP
    AND lu.availability_status != 'invisible'
    AND ST_Distance(
        ST_Point(p_longitude, p_latitude)::geography,
        ST_Point(lu.longitude, lu.latitude)::geography
    ) <= p_radius
    ORDER BY distance ASC;
END;
$$ language 'plpgsql';

-- Function to check if user is in safe zone
CREATE OR REPLACE FUNCTION is_in_safe_zone(
    p_user_id UUID,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION
)
RETURNS BOOLEAN AS $$
DECLARE
    safe_zone_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO safe_zone_count
    FROM public.safe_zones sz
    WHERE sz.user_id = p_user_id
    AND sz.is_enabled = true
    AND ST_Distance(
        ST_Point(p_longitude, p_latitude)::geography,
        ST_Point(sz.longitude, sz.latitude)::geography
    ) <= sz.radius;
    
    RETURN safe_zone_count > 0;
END;
$$ language 'plpgsql';

-- ================================================================
-- REALTIME SUBSCRIPTIONS
-- ================================================================

-- Enable realtime for proximity-related tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.location_updates;
ALTER PUBLICATION supabase_realtime ADD TABLE public.proximity_alerts_log;

-- ================================================================
-- INITIAL DATA
-- ================================================================

-- Insert default proximity settings for existing users
INSERT INTO public.proximity_alert_settings (user_id, is_enabled, location_privacy_tier)
SELECT id, false, 'disabled'
FROM public.users
WHERE id NOT IN (SELECT user_id FROM public.proximity_alert_settings)
ON CONFLICT (user_id) DO NOTHING;

-- ================================================================
-- SECURITY NOTES
-- ================================================================

-- 1. Location data is automatically expired after 1 hour
-- 2. Users can only see location updates from friends with explicit permissions
-- 3. Safe zones prevent proximity alerts in sensitive areas
-- 4. Notification throttling prevents spam
-- 5. All tables have RLS enabled for data protection
-- 6. Social context cache improves performance while maintaining privacy

-- ================================================================
-- MAINTENANCE QUERIES
-- ================================================================

-- Run these periodically to maintain database health:

-- Clean up expired data (run every hour)
-- SELECT cleanup_expired_location_updates();
-- SELECT cleanup_expired_social_context();
-- SELECT cleanup_expired_notification_throttling();

-- Check proximity alerts performance
-- SELECT COUNT(*) FROM public.proximity_alerts_log WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours';

-- Check active location updates
-- SELECT COUNT(*) FROM public.location_updates WHERE expires_at > CURRENT_TIMESTAMP;

-- Monitor notification throttling
-- SELECT throttle_key, COUNT(*) FROM public.notification_throttling GROUP BY throttle_key ORDER BY COUNT(*) DESC; 