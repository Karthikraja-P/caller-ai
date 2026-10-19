-- ============================================================
-- Disposable PostgreSQL SQL smoke test for Migration 005
-- ============================================================
-- This script tests that anon and authenticated roles are denied all
-- access to public.otp_sessions even if prior grants existed, while
-- service_role retains full access. Runs in a disposable transaction.

BEGIN;

-- 1. Setup mock Supabase roles if they do not exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role BYPASSRLS;
  END IF;
END $$;

-- 2. Simulate prior unsafe grants on otp_sessions
GRANT ALL ON TABLE public.otp_sessions TO anon, authenticated;

-- 3. Apply Migration 005
ALTER TABLE public.otp_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.otp_sessions FROM anon, authenticated, public;
GRANT ALL ON TABLE public.otp_sessions TO service_role;

-- 4. Verify service_role access (INSERT, SELECT, UPDATE, DELETE)
SET LOCAL ROLE service_role;

INSERT INTO public.otp_sessions (
  session_id, phone_number, hashed_otp, expires_at, verified
) VALUES (
  'smoke_sess_service_role', '+15551234567', 'hash', now() + interval '5 minutes', false
);

SELECT session_id FROM public.otp_sessions WHERE session_id = 'smoke_sess_service_role';

UPDATE public.otp_sessions
SET verified = true
WHERE session_id = 'smoke_sess_service_role';

DELETE FROM public.otp_sessions WHERE session_id = 'smoke_sess_service_role';

-- 5. Verify anon role is DENIED access (permission denied)
SET LOCAL ROLE anon;

DO $$
BEGIN
  BEGIN
    SELECT * FROM public.otp_sessions;
    RAISE EXCEPTION 'FAIL: anon was able to SELECT from otp_sessions';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: permission denied
  END;

  BEGIN
    INSERT INTO public.otp_sessions (session_id, phone_number, hashed_otp, expires_at)
    VALUES ('smoke_anon_fail', '+15550000000', 'hash', now());
    RAISE EXCEPTION 'FAIL: anon was able to INSERT into otp_sessions';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: permission denied
  END;

  BEGIN
    UPDATE public.otp_sessions SET verified = true WHERE session_id = 'smoke_anon_fail';
    RAISE EXCEPTION 'FAIL: anon was able to UPDATE otp_sessions';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: permission denied
  END;

  BEGIN
    DELETE FROM public.otp_sessions WHERE session_id = 'smoke_anon_fail';
    RAISE EXCEPTION 'FAIL: anon was able to DELETE from otp_sessions';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: permission denied
  END;
END $$;

-- 6. Verify authenticated role is DENIED access (permission denied)
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  BEGIN
    SELECT * FROM public.otp_sessions;
    RAISE EXCEPTION 'FAIL: authenticated was able to SELECT from otp_sessions';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: permission denied
  END;

  BEGIN
    INSERT INTO public.otp_sessions (session_id, phone_number, hashed_otp, expires_at)
    VALUES ('smoke_auth_fail', '+15550000000', 'hash', now());
    RAISE EXCEPTION 'FAIL: authenticated was able to INSERT into otp_sessions';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: permission denied
  END;

  BEGIN
    UPDATE public.otp_sessions SET verified = true WHERE session_id = 'smoke_auth_fail';
    RAISE EXCEPTION 'FAIL: authenticated was able to UPDATE otp_sessions';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: permission denied
  END;

  BEGIN
    DELETE FROM public.otp_sessions WHERE session_id = 'smoke_auth_fail';
    RAISE EXCEPTION 'FAIL: authenticated was able to DELETE from otp_sessions';
  EXCEPTION WHEN insufficient_privilege THEN
    -- Expected: permission denied
  END;
END $$;

-- Always rollback - completely disposable smoke test
ROLLBACK;
