-- ============================================================
-- Caller AI - Supabase Database Migration
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. PROFILES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_number TEXT NOT NULL UNIQUE,
  display_name TEXT,
  email TEXT,
  avatar_url TEXT,
  plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'micro', 'premium')),
  onboarding_complete BOOLEAN DEFAULT false,
  ai_calls_this_month INT DEFAULT 0,
  ai_calls_limit INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- ============================================================
-- 2. OTP SESSIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.otp_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id TEXT UNIQUE NOT NULL,
  phone_number TEXT NOT NULL,
  hashed_otp TEXT NOT NULL,
  device_uuid TEXT,
  device_type TEXT,
  country_code TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);
-- No RLS: managed exclusively by service key (admin)

-- ============================================================
-- 3. AI AGENT CONFIGS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_agent_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  agent_name TEXT NOT NULL DEFAULT 'Assistant',
  voice_id TEXT NOT NULL DEFAULT 'en-US-Neural2-A',
  personality TEXT DEFAULT 'professional' CHECK (personality IN ('professional', 'friendly', 'concise')),
  language TEXT DEFAULT 'en-US',
  spam_handling_enabled BOOLEAN DEFAULT true,
  busy_mode_enabled BOOLEAN DEFAULT false,
  busy_start_time TIME,
  busy_end_time TIME,
  busy_days TEXT[] DEFAULT '{}',
  whatsapp_diversion_enabled BOOLEAN DEFAULT false,
  greeting_template TEXT DEFAULT 'Hello, I am {{agent_name}}. How can I help?',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.ai_agent_configs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own agent config" ON public.ai_agent_configs FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 4. CALL LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.call_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_number TEXT NOT NULL,
  caller_name TEXT,
  call_type TEXT NOT NULL CHECK (call_type IN (
    'incoming', 'outgoing', 'missed', 'ai_handled_spam',
    'ai_handled_busy', 'whatsapp_diverted', 'blocked'
  )),
  call_duration INT DEFAULT 0,
  spam_score INT,
  spam_category TEXT,
  ai_agent_name TEXT,
  transcript_summary TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_call_logs_user_created ON public.call_logs(user_id, created_at DESC);
ALTER TABLE public.call_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own call logs" ON public.call_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own call logs" ON public.call_logs FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 5. AI CALL TRANSCRIPTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_call_transcripts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  call_sid TEXT NOT NULL,
  caller_number TEXT NOT NULL,
  caller_name TEXT,
  call_type TEXT NOT NULL CHECK (call_type IN ('spam', 'busy')),
  agent_name TEXT NOT NULL,
  full_transcript JSONB NOT NULL DEFAULT '[]',
  extracted_entities JSONB NOT NULL DEFAULT '[]',
  summary TEXT,
  audio_url TEXT,
  duration_seconds INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_transcripts_user_created ON public.ai_call_transcripts(user_id, created_at DESC);
ALTER TABLE public.ai_call_transcripts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own transcripts" ON public.ai_call_transcripts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Service can insert transcripts" ON public.ai_call_transcripts FOR INSERT WITH CHECK (true);

-- ============================================================
-- 6. SPAM REPORTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.spam_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_number TEXT NOT NULL,
  category TEXT NOT NULL,
  comment TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'disputed')),
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_spam_reports_number ON public.spam_reports(reported_number);
ALTER TABLE public.spam_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own spam reports" ON public.spam_reports FOR SELECT USING (auth.uid() = reporter_id);
CREATE POLICY "Users can insert spam reports" ON public.spam_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- ============================================================
-- 7. BLOCKED NUMBERS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.blocked_numbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_number TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, blocked_number)
);
ALTER TABLE public.blocked_numbers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own blocklist" ON public.blocked_numbers FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 8. WHATSAPP DIVERSIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.whatsapp_diversions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_number TEXT NOT NULL,
  contact_name TEXT,
  auto_reply_template TEXT DEFAULT 'Hi, I''m currently unavailable. Please message me on WhatsApp.',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, contact_number)
);
ALTER TABLE public.whatsapp_diversions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own diversions" ON public.whatsapp_diversions FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 9. DEVICE TOKENS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_uuid TEXT NOT NULL,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  last_active_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, device_uuid)
);
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own devices" ON public.device_tokens FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 10. COLLECTED CONTACTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.collected_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_name TEXT,
  contact_number TEXT NOT NULL,
  contact_email TEXT,
  source TEXT DEFAULT 'device',
  consent_given BOOLEAN DEFAULT true,
  collected_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.collected_contacts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own contacts" ON public.collected_contacts FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 11. MAID REGISTRY
-- ============================================================
CREATE TABLE IF NOT EXISTS public.maid_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  advertising_id TEXT NOT NULL,
  device_manufacturer TEXT,
  device_model TEXT,
  os_version TEXT,
  app_version TEXT,
  estimated_age_range TEXT,
  estimated_gender TEXT,
  registered_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.maid_registry ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own MAID" ON public.maid_registry FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 12. DATA CONSENT RECORDS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.data_consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL CHECK (consent_type IN ('contacts', 'maid', 'spam_patterns', 'analytics')),
  granted BOOLEAN NOT NULL,
  consent_version TEXT DEFAULT '1.0',
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.data_consent_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own consent records" ON public.data_consent_records FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 13. AD IMPRESSIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ad_impressions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ad_unit_id TEXT NOT NULL,
  ad_network TEXT,
  impression_type TEXT CHECK (impression_type IN ('banner', 'interstitial')),
  clicked BOOLEAN DEFAULT false,
  screen_name TEXT DEFAULT 'dashboard',
  created_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE public.ad_impressions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can insert own ad impressions" ON public.ad_impressions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view own ad impressions" ON public.ad_impressions FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- Triggers: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER ai_agent_configs_updated_at BEFORE UPDATE ON public.ai_agent_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- Enable Realtime on key tables
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.call_logs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_call_transcripts;

-- ============================================================
-- 14. Monthly Quota Reset Cron Job (pg_cron)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'reset_ai_calls_monthly',
  '0 0 1 * *', -- Run at midnight on the 1st of every month
  $$ UPDATE public.profiles SET ai_calls_this_month = 0; $$
);
