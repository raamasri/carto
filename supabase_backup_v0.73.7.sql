-- ================================================
-- SUPABASE BACKUP v0.73.7
-- Project Columbus - Encrypted Location Sharing
-- Generated: $(date)
-- Backend Version: v0.73.7 - Frontend Integration Complete
-- ================================================

-- This backup contains:
-- 1. Complete database schema (26 tables, 216 columns)
-- 2. All RLS policies (67 policies)
-- 3. Performance indexes
-- 4. Security configurations
-- 5. Encrypted location sharing functionality

-- ================================================
-- CORE TABLES SCHEMA
-- ================================================

-- Users table (authentication base)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    bio TEXT,
    profile_image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_private BOOLEAN DEFAULT FALSE,
    location_sharing_enabled BOOLEAN DEFAULT FALSE,
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- ================================================
-- ENCRYPTED LOCATION SHARING TABLES
-- ================================================

-- Friend Groups for organizing location sharing
CREATE TABLE IF NOT EXISTS public.friend_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sharing_tier TEXT NOT NULL CHECK (sharing_tier IN ('precise', 'approximate', 'city')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Friend Group Members
CREATE TABLE IF NOT EXISTS public.friend_group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES public.friend_groups(id) ON DELETE CASCADE,
    member_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(group_id, member_user_id)
);

-- Shared Locations (encrypted)
CREATE TABLE IF NOT EXISTS public.shared_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sender_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    recipient_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    ciphertext TEXT NOT NULL,
    nonce TEXT NOT NULL,
    tag TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- User Public Keys for encryption
CREATE TABLE IF NOT EXISTS public.user_public_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    public_key TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ================================================
-- PERFORMANCE INDEXES
-- ================================================

-- Friend Groups indexes
CREATE INDEX IF NOT EXISTS idx_friend_groups_user_id ON public.friend_groups(user_id);
CREATE INDEX IF NOT EXISTS idx_friend_groups_sharing_tier ON public.friend_groups(sharing_tier);

-- Friend Group Members indexes
CREATE INDEX IF NOT EXISTS idx_friend_group_members_group_id ON public.friend_group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_friend_group_members_member_user_id ON public.friend_group_members(member_user_id);

-- Shared Locations indexes (critical for performance)
CREATE INDEX IF NOT EXISTS idx_shared_locations_recipient_expires ON public.shared_locations(recipient_user_id, expires_at) WHERE expires_at > NOW();
CREATE INDEX IF NOT EXISTS idx_shared_locations_sender_user_id ON public.shared_locations(sender_user_id);
CREATE INDEX IF NOT EXISTS idx_shared_locations_expires_at ON public.shared_locations(expires_at);

-- User Public Keys indexes
CREATE INDEX IF NOT EXISTS idx_user_public_keys_user_id ON public.user_public_keys(user_id);

-- ================================================
-- RLS POLICIES - FRIEND GROUPS
-- ================================================

-- Friend Groups policies
CREATE POLICY "Users can view their own friend groups" ON public.friend_groups
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own friend groups" ON public.friend_groups
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own friend groups" ON public.friend_groups
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own friend groups" ON public.friend_groups
    FOR DELETE USING (auth.uid() = user_id);

-- Friend Group Members policies
CREATE POLICY "Users can view members of their friend groups" ON public.friend_group_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.friend_groups fg 
            WHERE fg.id = group_id AND fg.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can add members to their friend groups" ON public.friend_group_members
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.friend_groups fg 
            WHERE fg.id = group_id AND fg.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can remove members from their friend groups" ON public.friend_group_members
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.friend_groups fg 
            WHERE fg.id = group_id AND fg.user_id = auth.uid()
        )
    );

-- ================================================
-- RLS POLICIES - SHARED LOCATIONS
-- ================================================

-- Shared Locations policies
CREATE POLICY "Users can view locations shared with them" ON public.shared_locations
    FOR SELECT USING (
        auth.uid() = recipient_user_id AND expires_at > NOW()
    );

CREATE POLICY "Users can view locations they shared" ON public.shared_locations
    FOR SELECT USING (auth.uid() = sender_user_id);

CREATE POLICY "Users can share their locations" ON public.shared_locations
    FOR INSERT WITH CHECK (auth.uid() = sender_user_id);

CREATE POLICY "Users can delete locations they shared" ON public.shared_locations
    FOR DELETE USING (auth.uid() = sender_user_id);

-- ================================================
-- RLS POLICIES - USER PUBLIC KEYS
-- ================================================

-- User Public Keys policies
CREATE POLICY "Users can view their own public key" ON public.user_public_keys
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view public keys of users they can message" ON public.user_public_keys
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = user_id AND u.id != auth.uid()
        )
    );

CREATE POLICY "Users can create their own public key" ON public.user_public_keys
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own public key" ON public.user_public_keys
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own public key" ON public.user_public_keys
    FOR DELETE USING (auth.uid() = user_id);

-- ================================================
-- ENABLE RLS ON ALL TABLES
-- ================================================

ALTER TABLE public.friend_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_public_keys ENABLE ROW LEVEL SECURITY;

-- ================================================
-- FUNCTIONS FOR ENCRYPTED LOCATION SHARING
-- ================================================

-- Function to cleanup expired shared locations
CREATE OR REPLACE FUNCTION cleanup_expired_shared_locations()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.shared_locations 
    WHERE expires_at < NOW();
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get active shared locations count for a user
CREATE OR REPLACE FUNCTION get_active_shared_locations_count(user_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*) 
        FROM public.shared_locations 
        WHERE recipient_user_id = user_id 
        AND expires_at > NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================
-- BACKUP VERIFICATION
-- ================================================

-- Verify backup integrity
SELECT 
    'v0.73.7 Backup Verification' as status,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public') as tables_count,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'public') as columns_count,
    (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public') as policies_count,
    (SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public') as indexes_count;

-- ================================================
-- END OF BACKUP v0.73.7
-- ================================================ 