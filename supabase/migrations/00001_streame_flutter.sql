-- Streame Flutter — Supabase migration
-- Run this on the existing Kotlin Supabase project (klnjebhrpadyizgevaut)
-- This adds/updates tables for the Flutter app while preserving existing data

-- ============================================
-- 1. PROFILES (per-user, cloud-backed)
-- ============================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  avatar_color INTEGER DEFAULT 0xFFE50914,
  avatar_id INTEGER DEFAULT 0,
  is_kids_profile BOOLEAN DEFAULT false,
  pin TEXT,
  is_locked BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  last_used_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure one profile per user is the default
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own profiles"
  ON public.profiles FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 2. WATCHLIST (per-profile)
-- ============================================
CREATE TABLE IF NOT EXISTS public.watchlist (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  tmdb_id INTEGER NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('movie', 'tv')),
  title TEXT,
  poster_path TEXT,
  backdrop_path TEXT,
  imdb_id TEXT,
  added_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, profile_id, tmdb_id, media_type)
);

ALTER TABLE public.watchlist ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own watchlist"
  ON public.watchlist FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 3. WATCH HISTORY / CONTINUE WATCHING
-- ============================================
CREATE TABLE IF NOT EXISTS public.watch_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  profile_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  tmdb_id INTEGER NOT NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('movie', 'tv')),
  title TEXT,
  poster_path TEXT,
  backdrop_path TEXT,
  imdb_id TEXT,
  season INTEGER DEFAULT 0,
  episode INTEGER DEFAULT 0,
  progress DOUBLE PRECISION DEFAULT 0 CHECK (progress >= 0 AND progress <= 1),
  position_seconds INTEGER DEFAULT 0,
  duration_seconds INTEGER DEFAULT 0,
  is_dismissed BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, profile_id, tmdb_id, media_type, season, episode)
);

ALTER TABLE public.watch_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own watch history"
  ON public.watch_history FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Index for continue watching queries
CREATE INDEX IF NOT EXISTS idx_watch_history_cw
  ON public.watch_history (user_id, profile_id, is_dismissed, updated_at DESC)
  WHERE is_dismissed = false AND progress > 0.03 AND progress < 0.95;

-- ============================================
-- 4. ACCOUNT SYNC STATE (cloud sync between devices)
-- ============================================
CREATE TABLE IF NOT EXISTS public.account_sync_state (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  addons JSONB DEFAULT '[]',
  catalogs JSONB DEFAULT '[]',
  profiles JSONB DEFAULT '[]',
  settings JSONB DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.account_sync_state ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own sync state"
  ON public.account_sync_state FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 5. REALTIME — enable for watch_history and sync_state
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.watch_history;
ALTER PUBLICATION supabase_realtime ADD TABLE public.account_sync_state;

-- ============================================
-- 6. Enable email sign-up (for Flutter app users)
-- ============================================
-- This is configured in the Supabase Dashboard under Auth settings
-- Make sure "Enable email sign-ups" is ON
-- And "Confirm email" is OFF for easier first-time setup

-- ============================================
-- DONE — Flutter tables are ready
-- ============================================
