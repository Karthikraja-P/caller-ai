# Caller AI

> **v2.0.0** | AI-Powered Call Management & Voice Assistant Platform  
> Flutter + FastAPI + Supabase + Redis + OpenAI + Twilio

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  CALLER AI PLATFORM                     │
├──────────────────────────┬──────────────────────────────┤
│   Flutter Mobile App     │   FastAPI Backend            │
│   (Android + iOS)        │   (Python 3.12)              │
├──────────────────────────┼──────────────────────────────┤
│  Supabase Auth + DB      │  Redis Cache (7.2)           │
│  (PostgreSQL 16)         │  ElastiCache                 │
├──────────────────────────┼──────────────────────────────┤
│  Twilio Voice + Verify   │  OpenAI Whisper (STT)        │
│  Google Cloud TTS        │  spaCy NLP                   │
│  WhatsApp Business API   │  Google AdMob                │
│  Firebase FCM            │  RevenueCat                  │
└──────────────────────────┴──────────────────────────────┘
```

---

## Codebase Map

### Backend — `caller_ai_backend/`

```
app/
├── main.py                          # FastAPI bootstrap, CORS, lifespan
├── core/
│   ├── config.py                    # Pydantic Settings (23 env vars)
│   ├── database.py                  # Supabase client factory (anon + admin)
│   ├── security.py                  # JWT validation via Supabase JWKS
│   ├── rate_limiter.py              # Redis sliding window (OTP 5/hr, lookup 100/min)
│   ├── twilio_client.py             # Twilio: OTP send/verify, TwiML builder
│   └── whatsapp_client.py           # WhatsApp Business API v18.0
├── api/v1/endpoints/
│   ├── auth.py                      # POST /auth/register, /verify-otp, /refresh-token
│   ├── users.py                     # GET/PUT /users/profile, /devices, /subscription
│   ├── lookup.py                    # GET /lookup, POST /lookup/batch, GET /lookup/recent
│   ├── spam.py                      # POST /spam/report, GET /spam/check, /spam/stats
│   ├── ai_agent.py                  # Agent config CRUD, Twilio webhook, WebSocket stream
│   ├── whatsapp.py                  # Divert, send-message, history, status
│   ├── blocklist.py                 # POST/GET/DELETE /blocklist
│   └── health.py                    # GET /health, /health/ready
├── services/
│   ├── aggregator.py                # Waterfall: Redis → Telnyx → TrestleIQ → Apify
│   ├── ai_voice_service.py          # Whisper STT + Google TTS + intent/entity extraction
│   └── [more services TBD]
├── schemas/
│   ├── auth.py                      # RegisterRequest, VerifyOTPRequest, etc.
│   └── user.py                      # UpdateProfileRequest, UserProfileResponse
└── migrations/
    └── 001_initial_schema.sql       # All 13 Supabase tables + RLS + indexes
```

### Frontend — `caller_ai_frontend/`

```
lib/
├── main.dart                        # App entry, Supabase init, route map (20 routes)
├── core/
│   ├── env.dart                     # Public API keys (Supabase URL, AdMob, Mixpanel)
│   ├── theme/app_theme.dart         # Dark theme, AppColors, Inter font
│   └── network/dio_client.dart      # Dio client + JWT interceptor + silent refresh
├── presentation/
│   ├── blocs/
│   │   └── auth_bloc.dart           # AuthEvent/State + token management
│   └── screens/
│       ├── splash_screen.dart        # Logo + pulse animation + auth check
│       ├── otp_verification_screen.dart  # Country picker + 6-box OTP + countdown
│       ├── profile_creation_screen.dart  # Avatar + name/email + validation
│       ├── ai_agent_setup_screen.dart    # Voice carousel + personality cards
│       ├── permission_setup_screen.dart  # 5 permission cards with grant buttons
│       ├── onboarding_screen.dart        # 4-page PageView with gradient illustrations
│       ├── dashboard_screen.dart         # Stats + AI card + recent calls + bottom nav
│       ├── call_log_screen.dart          # Swipe actions + filter sheet
│       ├── number_search_screen.dart     # Waterfall result + action buttons
│       ├── ai_agent_screen.dart          # Config toggles + busy schedule
│       ├── ai_call_history_screen.dart   # Expandable transcript + entities
│       ├── spam_center_screen.dart       # Accuracy gauge + category chips + FAB
│       ├── whatsapp_screen.dart          # Connection status + diversions list
│       ├── settings_screen.dart          # Grouped tiles + logout
│       ├── profile_screen.dart           # Avatar + subscription + data privacy
│       ├── premium_screen.dart           # Gold hero + plan selector + feature table
│       ├── notification_screen.dart      # Typed notification cards
│       ├── call_overlay_screen.dart      # Spam banner + 5 action buttons
│       └── ai_voice_call_screen.dart     # Live transcript + pulsing AI avatar
android/app/src/main/kotlin/com/app/callerai/
│   ├── MainActivity.kt              # MethodChannel + EventChannel bridge
│   ├── CallReceiver.kt              # BroadcastReceiver (PHONE_STATE)
│   └── OverlayService.kt            # WindowManager TYPE_APPLICATION_OVERLAY
```

---

## Database Schema Index (13 tables)

| Table | Purpose |
|-------|---------|
| `profiles` | User accounts, display name, plan, AI usage limits |
| `otp_sessions` | Temporary OTP sessions (auto-cleaned after 5 min) |
| `ai_agent_configs` | Per-user AI agent name, voice, personality, schedule |
| `call_logs` | All call history with AI badges and spam scores |
| `ai_call_transcripts` | Full AI call transcripts with extracted entities |
| `spam_reports` | Community spam reports with categories |
| `blocked_numbers` | Per-user blocklist |
| `whatsapp_diversions` | WhatsApp diversion rules per contact |
| `device_tokens` | FCM tokens for push notifications |
| `collected_contacts` | User contacts (with consent) |
| `maid_registry` | Mobile Advertising IDs |
| `data_consent_records` | GDPR/DPDP consent audit trail |
| `ad_impressions` | AdMob impression tracking |

---

## Setup

### Backend

```bash
cd caller_ai_backend
cp .env.example .env        # Fill in all 23 API keys
pip install -r requirements.txt
python -m spacy download en_core_web_sm

# Apply database migrations
# → Copy migrations/001_initial_schema.sql into Supabase SQL Editor and run

# Start development server
uvicorn app.main:app --reload --port 8000

# Or with Docker
docker-compose up
```

**Swagger UI:** http://localhost:8000/docs

### Flutter

```bash
cd caller_ai_frontend
# Add your Supabase URL + Anon Key in lib/core/env.dart
# Add google-services.json (Android) + GoogleService-Info.plist (iOS)
flutter pub get
flutter run
```

---

## API Quick Reference

| Group | Endpoint | Method |
|-------|----------|--------|
| Auth | `/api/v1/auth/register` | POST |
| Auth | `/api/v1/auth/verify-otp` | POST |
| Auth | `/api/v1/auth/refresh-token` | POST |
| Users | `/api/v1/users/profile` | GET, PUT, DELETE |
| Users | `/api/v1/users/devices` | POST |
| Users | `/api/v1/users/subscription` | GET |
| Lookup | `/api/v1/lookup` | GET |
| Lookup | `/api/v1/lookup/batch` | POST |
| Spam | `/api/v1/spam/report` | POST |
| Spam | `/api/v1/spam/stats` | GET |
| AI | `/api/v1/ai/agent/config` | GET, POST |
| AI | `/api/v1/ai/call/handle` | POST (Twilio webhook) |
| AI | `/api/v1/ai/call/stream/{sid}` | WebSocket |
| AI | `/api/v1/ai/call/speak-text` | POST |
| WhatsApp | `/api/v1/whatsapp/divert` | POST, DELETE |
| Blocklist | `/api/v1/blocklist` | GET, POST, DELETE |
| Health | `/api/v1/health` | GET |

---

## Environment Variables (23 keys)

See [`.env.example`](caller_ai_backend/.env.example) for all keys with descriptions.

**Backend only** (secret): Supabase Service Key, Twilio Auth Token, OpenAI, Google TTS, WhatsApp Access Token, Telnyx, TrestleIQ, Apify, Firebase Server Key, Redis URL, RevenueCat

**Frontend** (public): Supabase URL + Anon Key, AdMob App ID + Ad Unit ID, Mixpanel Token
