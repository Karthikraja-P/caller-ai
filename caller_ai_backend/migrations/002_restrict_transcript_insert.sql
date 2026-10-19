-- Remove the broad INSERT policy from existing Supabase databases.
-- The backend uses the service-role client, which bypasses RLS.
DROP POLICY IF EXISTS "Service can insert transcripts" ON public.ai_call_transcripts;
