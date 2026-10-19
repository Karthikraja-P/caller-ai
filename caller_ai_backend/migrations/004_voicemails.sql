-- ============================================================
-- Caller AI v1: Voicemail Schema
-- ============================================================

CREATE TABLE IF NOT EXISTS public.voicemails (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  call_sid TEXT NOT NULL,
  recording_sid TEXT NOT NULL UNIQUE,
  recording_url TEXT NOT NULL,
  caller_number TEXT NOT NULL,
  destination_number TEXT NOT NULL,
  duration_seconds INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'completed',
  transcription TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_voicemails_user_created ON public.voicemails(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voicemails_recording_sid ON public.voicemails(recording_sid);
CREATE INDEX IF NOT EXISTS idx_voicemails_call_sid ON public.voicemails(call_sid);

ALTER TABLE public.voicemails ENABLE ROW LEVEL SECURITY;

-- Per-owner client access policies:
CREATE POLICY "Users can view own voicemails" ON public.voicemails
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own voicemails" ON public.voicemails
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own voicemails" ON public.voicemails
  FOR DELETE USING (auth.uid() = user_id);

-- NO public insert policy: only the service role inserts completed recordings
-- from signed Twilio webhook callbacks.
