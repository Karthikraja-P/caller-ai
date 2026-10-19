# Twilio AI call routing

Apply `migrations/003_ai_call_routing.sql` before enabling the AI call webhook. Assign each Twilio destination number to its account using the Supabase service role or SQL editor:

```sql
INSERT INTO public.ai_routing_numbers (phone_number, user_id)
VALUES ('+15551234567', '00000000-0000-4000-8000-000000000123')
ON CONFLICT (phone_number) DO UPDATE
SET user_id = EXCLUDED.user_id, is_active = true;
```

Replace both example values with the actual Twilio E.164 number and account UUID. An unassigned or disabled number is rejected. The webhook checks the mapped account's agent config, then records a per-call route. The stream presents a random route token, and the transcript uses the account UUID recorded for that call. These routing tables have no client access policies.

The existing `/ai/call/handle` endpoint is the Twilio Voice webhook. Configure the webhook only after the migration and number mapping are in place. No migration is applied automatically by this repository.
