-- Timeline and Post Draft Schema
-- Project Columbus - Timeline Feature
-- Created: 2025-01-10

-- ================================================================
-- TIMELINE TABLES
-- ================================================================

-- Timeline Entries Table
CREATE TABLE IF NOT EXISTS public.timeline_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    location_name TEXT NOT NULL,
    city TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    arrival_time TIMESTAMP WITH TIME ZONE NOT NULL,
    departure_time TIMESTAMP WITH TIME ZONE,
    duration DOUBLE PRECISION, -- in seconds
    is_current_location BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Post Drafts Table
CREATE TABLE IF NOT EXISTS public.post_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    timeline_entry_id UUID NOT NULL REFERENCES public.timeline_entries(id) ON DELETE CASCADE,
    location_name TEXT NOT NULL,
    city TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    arrival_time TIMESTAMP WITH TIME ZONE NOT NULL,
    departure_time TIMESTAMP WITH TIME ZONE,
    duration DOUBLE PRECISION, -- in seconds
    title TEXT NOT NULL DEFAULT '',
    content TEXT DEFAULT '',
    rating DOUBLE PRECISION CHECK (rating >= 0 AND rating <= 5),
    reaction TEXT CHECK (reaction IN ('Loved It', 'Want to Go')),
    media_urls TEXT[] DEFAULT '{}',
    tags TEXT[] DEFAULT '{}',
    mentioned_friends UUID[] DEFAULT '{}',
    sharing_type TEXT NOT NULL DEFAULT 'just_me' CHECK (sharing_type IN ('just_me', 'close_friends', 'mutuals', 'public')),
    is_published BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ================================================================
-- INDEXES FOR PERFORMANCE
-- ================================================================

-- Timeline Entries indexes
CREATE INDEX IF NOT EXISTS idx_timeline_entries_user_id ON public.timeline_entries USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_timeline_entries_arrival_time ON public.timeline_entries USING btree (arrival_time);
CREATE INDEX IF NOT EXISTS idx_timeline_entries_location ON public.timeline_entries USING btree (latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_timeline_entries_is_current ON public.timeline_entries USING btree (is_current_location);

-- Post Drafts indexes
CREATE INDEX IF NOT EXISTS idx_post_drafts_user_id ON public.post_drafts USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_post_drafts_timeline_entry_id ON public.post_drafts USING btree (timeline_entry_id);
CREATE INDEX IF NOT EXISTS idx_post_drafts_is_published ON public.post_drafts USING btree (is_published);
CREATE INDEX IF NOT EXISTS idx_post_drafts_sharing_type ON public.post_drafts USING btree (sharing_type);
CREATE INDEX IF NOT EXISTS idx_post_drafts_created_at ON public.post_drafts USING btree (created_at);

-- ================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ================================================================

-- Enable RLS on timeline tables
ALTER TABLE public.timeline_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_drafts ENABLE ROW LEVEL SECURITY;

-- Timeline Entries policies
CREATE POLICY "Users can view own timeline entries" ON public.timeline_entries
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own timeline entries" ON public.timeline_entries
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own timeline entries" ON public.timeline_entries
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own timeline entries" ON public.timeline_entries
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- Post Drafts policies
CREATE POLICY "Users can view own post drafts" ON public.post_drafts
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own post drafts" ON public.post_drafts
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own post drafts" ON public.post_drafts
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own post drafts" ON public.post_drafts
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- ================================================================
-- FUNCTIONS AND TRIGGERS
-- ================================================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers to automatically update updated_at
CREATE TRIGGER update_timeline_entries_updated_at
    BEFORE UPDATE ON public.timeline_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_post_drafts_updated_at
    BEFORE UPDATE ON public.post_drafts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically calculate duration when departure_time is set
CREATE OR REPLACE FUNCTION calculate_timeline_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.departure_time IS NOT NULL AND NEW.arrival_time IS NOT NULL THEN
        NEW.duration = EXTRACT(EPOCH FROM (NEW.departure_time - NEW.arrival_time));
        NEW.is_current_location = FALSE;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to calculate duration for timeline entries
CREATE TRIGGER calculate_timeline_entries_duration
    BEFORE INSERT OR UPDATE ON public.timeline_entries
    FOR EACH ROW
    EXECUTE FUNCTION calculate_timeline_duration();

-- Trigger to calculate duration for post drafts
CREATE TRIGGER calculate_post_drafts_duration
    BEFORE INSERT OR UPDATE ON public.post_drafts
    FOR EACH ROW
    EXECUTE FUNCTION calculate_timeline_duration();

-- ================================================================
-- ADDITIONAL POLICIES FOR SHARING
-- ================================================================

-- Policy to allow friends to view published posts based on sharing settings
CREATE POLICY "Friends can view shared timeline entries" ON public.timeline_entries
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.post_drafts pd
            WHERE pd.timeline_entry_id = timeline_entries.id
            AND pd.is_published = TRUE
            AND (
                pd.sharing_type = 'public'
                OR (
                    pd.sharing_type = 'mutuals' 
                    AND EXISTS (
                        SELECT 1 FROM public.follows f1
                        JOIN public.follows f2 ON f1.following_id = f2.follower_id AND f1.follower_id = f2.following_id
                        WHERE f1.follower_id = auth.uid() AND f1.following_id = timeline_entries.user_id
                    )
                )
                OR (
                    pd.sharing_type = 'close_friends'
                    AND EXISTS (
                        SELECT 1 FROM public.friend_groups fg
                        JOIN public.friend_group_members fgm ON fg.id = fgm.group_id
                        WHERE fg.user_id = timeline_entries.user_id
                        AND fgm.member_user_id = auth.uid()
                        AND fg.sharing_tier = 'close_friends'
                    )
                )
            )
        )
    );

-- Policy to allow viewing published post drafts based on sharing settings
CREATE POLICY "Users can view published posts based on sharing" ON public.post_drafts
    FOR SELECT TO authenticated
    USING (
        auth.uid() = user_id -- Owner can always see
        OR (
            is_published = TRUE
            AND (
                sharing_type = 'public'
                OR (
                    sharing_type = 'mutuals' 
                    AND EXISTS (
                        SELECT 1 FROM public.follows f1
                        JOIN public.follows f2 ON f1.following_id = f2.follower_id AND f1.follower_id = f2.following_id
                        WHERE f1.follower_id = auth.uid() AND f1.following_id = post_drafts.user_id
                    )
                )
                OR (
                    sharing_type = 'close_friends'
                    AND EXISTS (
                        SELECT 1 FROM public.friend_groups fg
                        JOIN public.friend_group_members fgm ON fg.id = fgm.group_id
                        WHERE fg.user_id = post_drafts.user_id
                        AND fgm.member_user_id = auth.uid()
                        AND fg.sharing_tier = 'close_friends'
                    )
                )
            )
        )
    );

-- ================================================================
-- COMMENTS
-- ================================================================

COMMENT ON TABLE public.timeline_entries IS 'Stores user timeline entries tracking places visited and duration';
COMMENT ON TABLE public.post_drafts IS 'Stores automatic post drafts created from timeline entries';

COMMENT ON COLUMN public.timeline_entries.duration IS 'Duration of stay in seconds, calculated automatically';
COMMENT ON COLUMN public.timeline_entries.is_current_location IS 'Whether user is currently at this location';

COMMENT ON COLUMN public.post_drafts.sharing_type IS 'Controls who can see the published post: just_me, close_friends, mutuals, public';
COMMENT ON COLUMN public.post_drafts.mentioned_friends IS 'Array of user IDs mentioned in the post';
COMMENT ON COLUMN public.post_drafts.is_published IS 'Whether the draft has been published as a post';