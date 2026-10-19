-- Provision one dedicated Twilio destination per account before enabling AI calls.
-- Insert mappings with the service role or SQL editor after the number is assigned.
CREATE TABLE IF NOT EXISTS public.ai_routing_numbers (
  phone_number TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ai_routing_number_e164 CHECK (phone_number ~ '^\+[1-9][0-9]{1,14}$')
);
CREATE INDEX IF NOT EXISTS idx_ai_routing_numbers_user ON public.ai_routing_numbers(user_id);
ALTER TABLE public.ai_routing_numbers ENABLE ROW LEVEL SECURITY;
-- No client policies: provisioning and webhook lookup use the service role.

CREATE TABLE IF NOT EXISTS public.ai_call_routes (
  call_sid TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  caller_number TEXT NOT NULL,
  destination_number TEXT NOT NULL,
  call_type TEXT NOT NULL CHECK (call_type IN ('spam', 'busy')),
  agent_name TEXT NOT NULL,
  route_token_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_call_routes_user_created
  ON public.ai_call_routes(user_id, created_at DESC);
ALTER TABLE public.ai_call_routes ENABLE ROW LEVEL SECURITY;
-- No client policies: only the service role may create/read call routes.
