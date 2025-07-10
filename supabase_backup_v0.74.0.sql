-- Supabase Database Backup v0.74.0
-- Generated: 2025-01-09
-- Project: Project Columbus
-- Features: Real-Time Friend Activity Feed & Smart Recommendations Engine

-- ================================================================
-- FRIEND ACTIVITY FEED TABLES (v0.74.0)
-- ================================================================

-- Friend Activities Table
CREATE TABLE IF NOT EXISTS public.friend_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    user_avatar_url TEXT,
    activity_type TEXT NOT NULL CHECK (activity_type IN (
        'visited_place', 'rated_place', 'added_to_list', 'commented_on_pin', 
        'reacted_to_pin', 'created_list', 'followed_user', 'shared_location'
    )),
    related_pin_id UUID REFERENCES public.pins(id) ON DELETE CASCADE,
    related_list_id UUID REFERENCES public.lists(id) ON DELETE CASCADE,
    related_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    related_user_username TEXT,
    location_name TEXT,
    location_latitude DOUBLE PRECISION,
    location_longitude DOUBLE PRECISION,
    description TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    is_visible BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Activity Feed Subscriptions
CREATE TABLE IF NOT EXISTS public.activity_feed_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscriber_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    publisher_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    subscription_type TEXT NOT NULL DEFAULT 'all' CHECK (subscription_type IN ('all', 'places', 'social')),
    activity_types TEXT[] DEFAULT ARRAY['visited_place', 'rated_place', 'added_to_list'],
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(subscriber_user_id, publisher_user_id)
);

-- ================================================================
-- SMART RECOMMENDATIONS TABLES (v0.74.0)
-- ================================================================

-- Place Recommendations
CREATE TABLE IF NOT EXISTS public.place_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    recommended_place JSONB NOT NULL,
    recommendation_type TEXT NOT NULL CHECK (recommendation_type IN (
        'personalized', 'trending', 'friend_based', 'similar_places', 'nearby'
    )),
    score DECIMAL(5,4) NOT NULL CHECK (score >= 0 AND score <= 1),
    reason TEXT NOT NULL,
    friend_visits INTEGER DEFAULT 0,
    friend_ratings JSONB DEFAULT '[]',
    category_match_score DECIMAL(5,4) DEFAULT 0,
    location_score DECIMAL(5,4) DEFAULT 0,
    time_relevance_score DECIMAL(5,4) DEFAULT 0,
    weather_score DECIMAL(5,4) DEFAULT 0,
    trending_score DECIMAL(5,4) DEFAULT 0,
    ml_confidence DECIMAL(5,4) DEFAULT 0.5,
    source_data JSONB DEFAULT '{}',
    is_viewed BOOLEAN DEFAULT FALSE,
    is_saved BOOLEAN DEFAULT FALSE,
    is_dismissed BOOLEAN DEFAULT FALSE,
    viewed_at TIMESTAMP WITH TIME ZONE,
    saved_at TIMESTAMP WITH TIME ZONE,
    dismissed_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- User Interactions for ML
CREATE TABLE IF NOT EXISTS public.user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    interaction_type TEXT NOT NULL CHECK (interaction_type IN (
        'pin_view', 'pin_save', 'pin_visit', 'pin_rate', 'list_view', 
        'list_save', 'recommendation_view', 'recommendation_save', 
        'recommendation_dismiss', 'search_query', 'category_filter'
    )),
    related_pin_id UUID REFERENCES public.pins(id) ON DELETE SET NULL,
    related_list_id UUID REFERENCES public.lists(id) ON DELETE SET NULL,
    related_recommendation_id UUID REFERENCES public.place_recommendations(id) ON DELETE SET NULL,
    interaction_data JSONB DEFAULT '{}',
    location_latitude DOUBLE PRECISION,
    location_longitude DOUBLE PRECISION,
    session_id TEXT,
    device_type TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ================================================================
-- PERFORMANCE INDEXES (v0.74.0)
-- ================================================================

-- Friend Activities Indexes
CREATE INDEX IF NOT EXISTS idx_friend_activities_user_id_created ON public.friend_activities(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_friend_activities_type_created ON public.friend_activities(activity_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_friend_activities_location ON public.friend_activities(location_latitude, location_longitude);
CREATE INDEX IF NOT EXISTS idx_friend_activities_visible ON public.friend_activities(is_visible, created_at DESC);

-- Place Recommendations Indexes
CREATE INDEX IF NOT EXISTS idx_place_recommendations_user_expires ON public.place_recommendations(user_id, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_place_recommendations_type_score ON public.place_recommendations(recommendation_type, score DESC);
CREATE INDEX IF NOT EXISTS idx_place_recommendations_not_dismissed ON public.place_recommendations(user_id, is_dismissed, expires_at DESC);

-- User Interactions Indexes
CREATE INDEX IF NOT EXISTS idx_user_interactions_user_type ON public.user_interactions(user_id, interaction_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_interactions_pin ON public.user_interactions(related_pin_id) WHERE related_pin_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_interactions_session ON public.user_interactions(session_id, created_at DESC);

-- Activity Feed Subscriptions Index
CREATE INDEX IF NOT EXISTS idx_activity_subscriptions_active ON public.activity_feed_subscriptions(subscriber_user_id, is_active);

-- ================================================================
-- ROW LEVEL SECURITY POLICIES (v0.74.0)
-- ================================================================

-- Enable RLS on new tables
ALTER TABLE public.friend_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_feed_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_interactions ENABLE ROW LEVEL SECURITY;

-- Friend Activities Policies
CREATE POLICY "Users can view activities from followed users" ON public.friend_activities
    FOR SELECT USING (
        is_visible = TRUE AND (
            user_id = auth.uid() OR
            EXISTS (
                SELECT 1 FROM public.follows 
                WHERE follower_id = auth.uid() AND following_id = user_id
            ) OR
            EXISTS (
                SELECT 1 FROM public.activity_feed_subscriptions 
                WHERE subscriber_user_id = auth.uid() AND publisher_user_id = user_id AND is_active = TRUE
            )
        )
    );

CREATE POLICY "Users can insert their own activities" ON public.friend_activities
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own activities" ON public.friend_activities
    FOR UPDATE USING (user_id = auth.uid());

-- Activity Feed Subscriptions Policies
CREATE POLICY "Users can view their own subscriptions" ON public.activity_feed_subscriptions
    FOR SELECT USING (subscriber_user_id = auth.uid());

CREATE POLICY "Users can manage their own subscriptions" ON public.activity_feed_subscriptions
    FOR ALL USING (subscriber_user_id = auth.uid());

-- Place Recommendations Policies
CREATE POLICY "Users can view their own recommendations" ON public.place_recommendations
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update their own recommendations" ON public.place_recommendations
    FOR UPDATE USING (user_id = auth.uid());

-- User Interactions Policies
CREATE POLICY "Users can insert their own interactions" ON public.user_interactions
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- ================================================================
-- ENCRYPTED LOCATION SHARING TABLES (v0.73.7)
-- ================================================================

-- (Previous tables from v0.73.7 included here for completeness)
-- Friend Groups, Friend Group Members, Shared Locations, User Public Keys
-- [Tables already exist from v0.73.7 migration]

-- ================================================================
-- CORE TABLES (Pre-existing)
-- ================================================================

-- Users, Pins, Lists, Follows, Messages, Notifications, etc.
-- [Core tables already exist from previous versions] 