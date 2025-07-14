-- ================================================================
-- PROXIMITY ALERTS DATABASE SCHEMA v0.74.2
-- Project Columbus - Social Discovery System
-- Generated: 2025-01-10
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
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    is_available BOOLEAN DEFAULT true,
    availability_status TEXT DEFAULT 'available',
    custom_status_message TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ DEFAULT (now() + interval '1 hour')
);

-- Proximity Alert Settings table for user preferences
CREATE TABLE IF NOT EXISTS public.proximity_alert_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    location_privacy_tier TEXT DEFAULT 'friendsOnly',
    proximity_radius DOUBLE PRECISION DEFAULT 500.0,
    notification_radius DOUBLE PRECISION DEFAULT 1000.0,
    only_alert_when_available BOOLEAN DEFAULT true,
    allow_background_sharing BOOLEAN DEFAULT true,
    share_location_history BOOLEAN DEFAULT false,
    share_visited_places BOOLEAN DEFAULT true,
    share_activity_feed BOOLEAN DEFAULT true,
    allow_location_recommendations BOOLEAN DEFAULT true,
    data_retention_days INTEGER DEFAULT 30,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Friend Proximity Permissions table for granular friend controls
CREATE TABLE IF NOT EXISTS public.friend_proximity_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    can_see_exact_location BOOLEAN DEFAULT false,
    can_see_availability BOOLEAN DEFAULT true,
    can_send_proximity_alerts BOOLEAN DEFAULT true,
    custom_radius DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, friend_id)
);

-- Safe Zones table for privacy protection
CREATE TABLE IF NOT EXISTS public.safe_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    radius DOUBLE PRECISION NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Proximity Alerts Log table for debugging and analytics
CREATE TABLE IF NOT EXISTS public.proximity_alerts_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    friend_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    alert_type TEXT NOT NULL,
    trigger_location_lat DOUBLE PRECISION,
    trigger_location_lng DOUBLE PRECISION,
    friend_location_lat DOUBLE PRECISION,
    friend_location_lng DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    notification_sent BOOLEAN DEFAULT false,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Location Social Context table for caching social data
CREATE TABLE IF NOT EXISTS public.location_social_context (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    location_name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    friend_usernames TEXT[] DEFAULT '{}',
    recent_activity_count INTEGER DEFAULT 0,
    social_score DOUBLE PRECISION,
    recommendation_text TEXT,
    activity_type TEXT,
    last_activity_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ DEFAULT (now() + interval '24 hours')
);

-- Notification Throttling table to prevent spam
CREATE TABLE IF NOT EXISTS public.notification_throttling (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    throttle_key TEXT NOT NULL,
    throttle_type TEXT NOT NULL,
    last_notification_sent TIMESTAMPTZ,
    notification_count INTEGER DEFAULT 0,
    expires_at TIMESTAMPTZ,
    UNIQUE(user_id, throttle_key)
);

-- ================================================================
-- INDEXES
-- ================================================================

-- Location Updates indexes
CREATE INDEX IF NOT EXISTS idx_location_updates_user_id ON public.location_updates(user_id);
CREATE INDEX IF NOT EXISTS idx_location_updates_coordinates ON public.location_updates(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_location_updates_created_at ON public.location_updates(created_at);
CREATE INDEX IF NOT EXISTS idx_location_updates_expires_at ON public.location_updates(expires_at);
CREATE INDEX IF NOT EXISTS idx_location_updates_availability ON public.location_updates(is_available, availability_status);

-- Proximity Alert Settings indexes
CREATE INDEX IF NOT EXISTS idx_proximity_settings_user_id ON public.proximity_alert_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_proximity_settings_enabled ON public.proximity_alert_settings(is_enabled);

-- Friend Proximity Permissions indexes
CREATE INDEX IF NOT EXISTS idx_friend_permissions_user_id ON public.friend_proximity_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_friend_permissions_friend_id ON public.friend_proximity_permissions(friend_id);
CREATE INDEX IF NOT EXISTS idx_friend_permissions_enabled ON public.friend_proximity_permissions(is_enabled);

-- Safe Zones indexes
CREATE INDEX IF NOT EXISTS idx_safe_zones_user_id ON public.safe_zones(user_id);
CREATE INDEX IF NOT EXISTS idx_safe_zones_coordinates ON public.safe_zones(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_safe_zones_enabled ON public.safe_zones(is_enabled);

-- Proximity Alerts Log indexes
CREATE INDEX IF NOT EXISTS idx_alerts_log_user_id ON public.proximity_alerts_log(user_id);
CREATE INDEX IF NOT EXISTS idx_alerts_log_friend_id ON public.proximity_alerts_log(friend_id);
CREATE INDEX IF NOT EXISTS idx_alerts_log_created_at ON public.proximity_alerts_log(created_at);

-- Location Social Context indexes
CREATE INDEX IF NOT EXISTS idx_social_context_coordinates ON public.location_social_context(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_social_context_expires_at ON public.location_social_context(expires_at);

-- Notification Throttling indexes
CREATE INDEX IF NOT EXISTS idx_throttling_user_id ON public.notification_throttling(user_id);
CREATE INDEX IF NOT EXISTS idx_throttling_expires_at ON public.notification_throttling(expires_at);

-- ================================================================
-- FUNCTIONS
-- ================================================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup expired location updates
CREATE OR REPLACE FUNCTION cleanup_expired_location_updates()
RETURNS void AS $$
BEGIN
    DELETE FROM public.location_updates WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup expired social context
CREATE OR REPLACE FUNCTION cleanup_expired_social_context()
RETURNS void AS $$
BEGIN
    DELETE FROM public.location_social_context WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup expired notification throttling
CREATE OR REPLACE FUNCTION cleanup_expired_notification_throttling()
RETURNS void AS $$
BEGIN
    DELETE FROM public.notification_throttling WHERE expires_at < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Function to check if a location is in a safe zone
CREATE OR REPLACE FUNCTION is_in_safe_zone(
    p_user_id UUID,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION
) RETURNS BOOLEAN AS $$
DECLARE
    v_in_safe_zone BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.safe_zones
        WHERE user_id = p_user_id
        AND is_enabled = true
        AND earth_distance(
            ll_to_earth(latitude, longitude),
            ll_to_earth(p_latitude, p_longitude)
        ) <= radius
    ) INTO v_in_safe_zone;
    
    RETURN v_in_safe_zone;
END;
$$ LANGUAGE plpgsql;

-- Function to get nearby friends
CREATE OR REPLACE FUNCTION get_nearby_friends(
    p_user_id UUID,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius DOUBLE PRECISION
) RETURNS TABLE (
    friend_id UUID,
    username TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    distance DOUBLE PRECISION,
    is_available BOOLEAN,
    availability_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as friend_id,
        u.username,
        lu.latitude,
        lu.longitude,
        earth_distance(
            ll_to_earth(lu.latitude, lu.longitude),
            ll_to_earth(p_latitude, p_longitude)
        ) as distance,
        lu.is_available,
        lu.availability_status
    FROM public.location_updates lu
    JOIN auth.users u ON u.id = lu.user_id
    JOIN public.follows f ON f.following_id = lu.user_id
    LEFT JOIN public.friend_proximity_permissions fpp 
        ON fpp.user_id = lu.user_id 
        AND fpp.friend_id = p_user_id
    WHERE f.follower_id = p_user_id
    AND lu.expires_at > CURRENT_TIMESTAMP
    AND (fpp.is_enabled IS NULL OR fpp.is_enabled = true)
    AND earth_distance(
        ll_to_earth(lu.latitude, lu.longitude),
        ll_to_earth(p_latitude, p_longitude)
    ) <= p_radius
    AND NOT EXISTS (
        SELECT 1 FROM public.safe_zones sz
        WHERE sz.user_id = lu.user_id
        AND sz.is_enabled = true
        AND earth_distance(
            ll_to_earth(sz.latitude, sz.longitude),
            ll_to_earth(lu.latitude, lu.longitude)
        ) <= sz.radius
    );
END;
$$ LANGUAGE plpgsql;

-- ================================================================
-- TRIGGERS
-- ================================================================

-- Triggers for updating updated_at timestamps
CREATE TRIGGER update_proximity_settings_updated_at
    BEFORE UPDATE ON public.proximity_alert_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_friend_permissions_updated_at
    BEFORE UPDATE ON public.friend_proximity_permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_safe_zones_updated_at
    BEFORE UPDATE ON public.safe_zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- ENABLE ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS on all proximity alert tables
ALTER TABLE public.location_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proximity_alert_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_proximity_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.safe_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.proximity_alerts_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.location_social_context ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_throttling ENABLE ROW LEVEL SECURITY;

-- ================================================================
-- ROW LEVEL SECURITY POLICIES
-- ================================================================

-- Location Updates policies
CREATE POLICY "Users can view their own location updates"
    ON public.location_updates FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Friends can view location updates if permitted"
    ON public.location_updates FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM follows f
            WHERE f.follower_id = auth.uid()
            AND f.following_id = location_updates.user_id
        )
        AND NOT EXISTS (
            SELECT 1 FROM friend_proximity_permissions fpp
            WHERE fpp.user_id = fpp.user_id
            AND fpp.friend_id = auth.uid()
            AND fpp.is_enabled = false
        )
    );

CREATE POLICY "Users can insert their own location updates"
    ON public.location_updates FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own location updates"
    ON public.location_updates FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own location updates"
    ON public.location_updates FOR DELETE
    USING (auth.uid() = user_id);

-- Proximity Alert Settings policies
CREATE POLICY "Users can manage their own proximity settings"
    ON public.proximity_alert_settings FOR ALL
    USING (auth.uid() = user_id);

-- Friend Proximity Permissions policies
CREATE POLICY "Users can manage their friend permissions"
    ON public.friend_proximity_permissions FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Friends can view permissions that affect them"
    ON public.friend_proximity_permissions FOR SELECT
    USING (auth.uid() = friend_id);

-- Safe Zones policies
CREATE POLICY "Users can manage their own safe zones"
    ON public.safe_zones FOR ALL
    USING (auth.uid() = user_id);

-- Proximity Alerts Log policies
CREATE POLICY "Users can view their own proximity alerts log"
    ON public.proximity_alerts_log FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own proximity alerts log"
    ON public.proximity_alerts_log FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Location Social Context policies
CREATE POLICY "Anyone can view location social context"
    ON public.location_social_context FOR SELECT
    USING (true);

CREATE POLICY "Authenticated users can insert location social context"
    ON public.location_social_context FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update location social context"
    ON public.location_social_context FOR UPDATE
    USING (auth.uid() IS NOT NULL);

-- Notification Throttling policies
CREATE POLICY "Users can manage their own notification throttling"
    ON public.notification_throttling FOR ALL
    USING (auth.uid() = user_id);

-- ================================================================
-- COMMENTS
-- ================================================================

COMMENT ON TABLE public.location_updates IS 'Real-time location updates for proximity detection';
COMMENT ON TABLE public.proximity_alert_settings IS 'User preferences for proximity alerts';
COMMENT ON TABLE public.friend_proximity_permissions IS 'Friend-specific proximity controls';
COMMENT ON TABLE public.safe_zones IS 'Geographical privacy protection zones';
COMMENT ON TABLE public.proximity_alerts_log IS 'Log of proximity alerts for debugging and analytics';
COMMENT ON TABLE public.location_social_context IS 'Cached social context for locations';
COMMENT ON TABLE public.notification_throttling IS 'Prevents notification spam';

-- ================================================================
-- END OF SCHEMA
-- ================================================================ 