-- ============================================================
-- Migration 005: Lock down public.otp_sessions with RLS
-- ============================================================

-- 1. Enable Row Level Security on otp_sessions
ALTER TABLE public.otp_sessions ENABLE ROW LEVEL SECURITY;

-- 2. Revoke all privileges from anon, authenticated, and public
REVOKE ALL ON TABLE public.otp_sessions FROM anon, authenticated, public;

-- 3. Explicitly grant full privileges to service_role (backend admin)
GRANT ALL ON TABLE public.otp_sessions TO service_role;

-- NO policies are created for anon or authenticated.
-- Only the service_role (bypassing RLS) can access or modify otp_sessions.
