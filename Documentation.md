# Caller AI - Complete Production Documentation

> **Version:** 2.0 Production Release | August 2026  
> **Classification:** Internal Engineering / Investor Review  
> **Tech Stack:** Flutter + FastAPI + Supabase + Redis + OpenAI + Twilio  
> **Database:** Supabase (PostgreSQL) for User Accounts & Details  

---

## Table of Contents

1. [Project Name & Summary](#1-project-name--summary)
2. [Complete User Journey - Step by Step](#2-complete-user-journey---step-by-step)
   - 2.1 App Installation & First Launch
   - 2.2 Splash Screen Flow
   - 2.3 New User - OTP Registration Flow
   - 2.4 Existing User - Direct OTP Login Flow
   - 2.5 Profile Creation & Setup
   - 2.6 System Permission Granting Flow
   - 2.7 AI Agent Name & Voice Setup
   - 2.8 Entering the App Dashboard
   - 2.9 Complete Screen Navigation Map
3. [API Keys Usage Details](#3-api-keys-usage-details)
   - 3.1 Complete API Key Inventory
   - 3.2 API Key to Operation Mapping
   - 3.3 API Key Usage Flow Per Screen
   - 3.4 Key Rotation & Security Strategy
4. [Tech Stack Specification](#4-tech-stack-specification)
5. [Project Structure](#5-project-structure)
6. [REST APIs - Complete Specification](#6-rest-apis---complete-specification)
7. [Mobile App Screens - Deep Dive](#7-mobile-app-screens---deep-dive)
   - 7.1 Screen 1: Splash Screen
   - 7.2 Screen 2: OTP Verification Screen (New User)
   - 7.3 Screen 3: OTP Verification Screen (Existing User)
   - 7.4 Screen 4: Profile Creation Screen
   - 7.5 Screen 5: AI Agent Setup Screen
   - 7.6 Screen 6: Permission Setup Screen
   - 7.7 Screen 7: Onboarding Screen
   - 7.8 Screen 8: Main Dashboard
   - 7.9 Screen 9: Call Log Screen
   - 7.10 Screen 10: Number Search Screen
   - 7.11 Screen 11: AI Agent Configuration Screen
   - 7.12 Screen 12: AI Call History & Transcript Screen
   - 7.13 Screen 13: Spam Center Screen
   - 7.14 Screen 14: WhatsApp Bridge Screen
   - 7.15 Screen 15: Settings Screen
   - 7.16 Screen 16: Profile & Account Screen
   - 7.17 Screen 17: Premium Subscription Screen
   - 7.18 Screen 18: Notification Screen
   - 7.19 Screen 19: Call Overlay (Incoming Call UI)
   - 7.20 Screen 20: AI Voice Call Live Screen
8. [Database Schema (Supabase)](#8-database-schema-supabase)
9. [Backend Services](#9-backend-services)
10. [AI Voice Processing Pipeline](#10-ai-voice-processing-pipeline)
11. [Data Collection & Privacy Framework](#11-data-collection--privacy-framework)
12. [Revenue Model](#12-revenue-model)
13. [Deployment Pipeline](#13-deployment-pipeline)
14. [Monitoring & Observability](#14-monitoring--observability)
15. [Error Handling Strategy](#15-error-handling-strategy)

---

## 1. Project Name & Summary

### 1.1 Project Name
**Caller AI** - An AI-Powered Call Management & Voice Assistant Platform

### 1.2 Product Summary

Caller AI is a comprehensive, production-grade mobile application that fundamentally transforms how users interact with phone calls by deploying artificial intelligence at every layer of the call management stack. The application serves as a full replacement for the native phone dialer, providing real-time caller identification, intelligent spam detection and blocking, AI-powered voice agents that attend calls on the user's behalf, and seamless WhatsApp message diversion for contacts who prefer text-based communication.

The platform is built on a modern technology stack comprising Flutter for cross-platform mobile development, FastAPI (Python) for the backend API layer, Supabase (PostgreSQL) for user account management and persistent data storage, Redis for high-performance caching, OpenAI Whisper and Google Cloud TTS for speech processing, and Twilio for voice call infrastructure. This combination ensures low-latency caller identification (under 1.5 seconds), real-time AI voice conversations with spam callers, and a responsive, native-feeling mobile experience across both Android and iOS platforms.

The core innovation of Caller AI lies in three areas that no existing caller ID application currently offers. First, the **AI Voice Agent for Spam Calls** engages spam callers in natural conversation to extract useful information (loan amounts, interest rates, trading tips, promotional offers) and delivers these details as structured text messages to the user. Second, the **AI Voice Agent for Busy Mode** attends calls from known contacts when the user is unavailable, politely explains the situation, takes messages, and transcribes the conversation for later review. Third, the **WhatsApp Bridge** automatically diverts incoming calls to WhatsApp messaging when the user enables it for specific contacts or time periods, leveraging the WhatsApp Business API for seamless integration.

The application follows a freemium revenue model where the base tier is free with advertising (limited to the main dashboard screen only via Google AdMob), and the premium tier removes ads while unlocking unlimited AI agent call handling, advanced busy mode scheduling, and priority spam protection. All data collection is transparent and consent-based, with Supabase handling user authentication, profile management, and secure storage of all user-related data including contacts, MAID information, and consent records.

### 1.3 Key Operations Summary

| # | Operation | Description | API Keys Used |
|---|-----------|-------------|---------------|
| 1 | Receive Calls & Messages | Replace native phone app with spam/fraud protection | Twilio, Telnyx, TrestleIQ |
| 2 | AI Voice Assistant | Attend phone, put on speaker, call anyone with voice commands | OpenAI Whisper, Google Cloud TTS, Twilio |
| 3 | AI Voice Agent (Spam) | Attend spam calls, extract loan/trading/shopping details, convert to text | OpenAI Whisper, Google Cloud TTS, Twilio |
| 4 | AI Voice Agent (Busy) | Attend saved/normal contact calls when user is busy | OpenAI Whisper, Google Cloud TTS, Twilio |
| 5 | Caller ID AI Agent | User-chosen AI agent name for call answering | Google Cloud TTS, Twilio |
| 6 | WhatsApp Diversion | Contact number to WhatsApp message diversion | WhatsApp Business API |
| 7 | Ad Revenue | Ads only on main dashboard screen | Google AdMob |
| 8 | Contact Data Collection | Collect users' saved contacts data | Supabase |
| 9 | MAID Data Collection | Collect MAID ID info for names and age | Supabase |
| 10 | Spam Pattern Data | Collect spam calling pattern data | Supabase, Redis |
| 11 | Premium Features | AI agent, no ads, busy voice chat | RevenueCat / Stripe |

---

## 2. Complete User Journey - Step by Step

### 2.1 App Installation & First Launch

**Trigger:** User taps "Caller AI" app icon on their home screen after installing from Google Play Store or Apple App Store.

**Step-by-step flow:**

1. **App Launch Initiated** - The operating system launches the Flutter application by invoking `main.dart`. The `runApp()` function initializes the root `MultiBlocProvider` that contains all BLoC state management providers: `AuthBloc`, `LookupBloc`, `SpamBloc`, `CallLogBloc`, `AIAgentBloc`, `WhatsAppBloc`, `SettingsBloc`, and `AdBloc`.

2. **Native Bridge Initialization** - On Android, the `MainActivity.kt` registers the `CallReceiver` (BroadcastReceiver for `PHONE_STATE` intent), initializes the `AudioStreamService` for audio capture/playback, and sets up the `MethodChannel` communication bridge between native Kotlin code and the Flutter Dart layer. On iOS, the `CallDirectoryHandler.swift` registers the `CXCallDirectoryProvider` extension for caller ID injection into the native phone UI, and `AudioHandler.swift` sets up PushKit for VoIP push notifications.

3. **Local Storage Check** - The app checks `Hive` local storage for: (a) cached JWT access token and refresh token, (b) AI agent configuration, (c) user preferences and settings, (d) cached spam signatures database. If no cached tokens exist, the app routes to the **New User Registration Flow**. If cached tokens exist but are expired (checked via JWT `exp` claim), the app attempts a silent token refresh via `POST /api/v1/auth/refresh-token` and if successful, routes directly to the **Dashboard**. If the refresh fails, the app routes to the **Existing User OTP Login Flow**.

4. **Splash Screen Display** - While the above initialization runs (typically 2-4 seconds), the user sees the **Splash Screen** (detailed in Screen 1 below) with the Caller AI logo, pulsing animation, and tagline. The splash screen serves as the visual loading indicator.

### 2.2 Splash Screen Flow

**API Calls During Splash:**
- `POST /api/v1/auth/refresh-token` (if cached tokens exist) - Uses **Supabase JWT** for authentication
- `GET /api/v1/users/profile` (if token refresh succeeds) - Uses **Supabase Auth API Key**
- `GET /api/v1/ai/agent/config` (if authenticated) - Uses **Supabase Auth API Key**
- `POST /api/v1/users/devices` (FCM token registration) - Uses **Supabase Auth API Key** + **Firebase Cloud Messaging API Key**

**Backend Processing:**
- Supabase Auth service validates the JWT refresh token against the `auth.users` table
- If valid, Supabase issues new access token (JWT, 30-minute expiry) and refresh token (90-day expiry)
- The user profile is fetched from `supabase.public.profiles` table
- The AI agent configuration is fetched from `supabase.public.ai_agent_configs` table
- FCM device token is upserted into `supabase.public.device_tokens` table for push notifications

**Navigation Decision Tree:**
```
Splash Screen
  ├── No cached tokens found
  │     └── Navigate to OTP Verification Screen (New User)
  ├── Cached tokens exist, refresh SUCCESS
  │     └── Navigate to Dashboard Screen
  └── Cached tokens exist, refresh FAILED
        └── Navigate to OTP Verification Screen (Existing User - Pre-filled number)
```

### 2.3 New User - OTP Registration Flow

**Trigger:** App detects no cached authentication tokens during splash screen initialization.

**Step-by-step flow:**

1. **OTP Screen Opens** - The app presents the OTP Verification Screen (Screen 2). The screen shows: a phone number input field with a country code selector dropdown (defaulting to the device's SIM country via `telephony_manager` on Android or `CTTelephonyNetworkInfo` on iOS), a "Send OTP" button, and a brief privacy notice text below.

2. **User Enters Phone Number** - The user types their mobile number. The country code selector shows flags and codes (e.g., India +91, USA +1, UK +44). The phone number field uses `libphonenumber` for real-time formatting validation (e.g., as the user types `9876543210`, it displays `+91 98765 43210`). If the number format is invalid, a red error message appears: "Please enter a valid phone number."

3. **User Taps "Send OTP"** - The app calls `POST /api/v1/auth/register`.

   **API Details:**
   - **Endpoint:** `POST /api/v1/auth/register`
   - **API Key Used:** Supabase Auth API Key (passed as `apikey` header)
   - **Backend Processing:**
     a. FastAPI receives the request and validates the phone number format using `phonenumbers` Python library
     b. Checks Supabase `auth.users` table for existing phone number - if found, returns `409 CONFLICT` ("Account already exists. Please verify OTP to login.")
     c. If new user, generates a 6-digit OTP using `secrets.token_hex(3)` (cryptographically secure random)
     d. Stores the OTP hash (SHA-256) in Supabase `public.otp_sessions` table with `phone_number`, `hashed_otp`, `expires_at` (5 minutes from creation), `device_uuid`, `device_type`, `country_code`
     e. Sends the OTP via Twilio Verify API (using **Twilio Account SID + Auth Token + Verify Service SID**) as an SMS to the user's phone number
     f. Returns `201 Created` with `session_id`, `expires_in: 300`

   **Sample Request:**
   ```json
   {
     "phone_number": "+919876543210",
     "device_uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
     "device_type": "android",
     "country_code": "IN",
     "app_version": "2.0.0"
   }
   ```

   **Sample Response (Success):**
   ```json
   {
     "status": "success",
     "message": "OTP sent to +91 98765 43210",
     "session_id": "sess_abc123xyz",
     "expires_in": 300
   }
   ```

   **Sample Response (Existing User):**
   ```json
   {
     "status": "error",
     "code": "USER_EXISTS",
     "message": "Account already exists. Verifying OTP will log you in."
   }
   ```

4. **OTP Input Fields Appear** - After successful OTP send, 6 individual digit input boxes appear (like WhatsApp/Telegram OTP UI). A countdown timer shows "Resend OTP in 00:59" and counts down. Each input box auto-focuses to the next when a digit is typed.

5. **User Enters 6-Digit OTP** - As the user types each digit, the app validates locally (digits only, 6 characters). When all 6 digits are entered, the "Verify" button activates (turns from gray to accent blue).

6. **User Taps "Verify"** - The app calls `POST /api/v1/auth/verify-otp`.

   **API Details:**
   - **Endpoint:** `POST /api/v1/auth/verify-otp`
   - **API Key Used:** Supabase Auth API Key
   - **Backend Processing:**
     a. FastAPI looks up `session_id` in `supabase.public.otp_sessions`
     b. Checks if `expires_at` has passed - if expired, returns `410 GONE` ("OTP expired. Please request a new one.")
     c. Hashes the user-provided OTP with SHA-256 and compares against stored `hashed_otp`
     d. If match: creates a new user in Supabase Auth via `supabase.auth.admin.create_user()` with phone as the primary identifier
     e. Creates a profile row in `supabase.public.profiles` with default values (display_name: null, email: null, avatar_url: null, plan: 'free', created_at: now)
     f. Generates JWT access token (30 min) and refresh token (90 days) via Supabase Auth
     g. Deletes the used OTP session
     h. Returns tokens + user data

   **Sample Request:**
   ```json
   {
     "session_id": "sess_abc123xyz",
     "otp_code": "482916"
   }
   ```

   **Sample Response (Success):**
   ```json
   {
     "access_token": "eyJhbGciOiJIUzI1NiIs...",
     "refresh_token": "v1.stoken_abc123...",
     "expires_in": 1800,
     "user": {
       "id": "uuid-user-001",
       "phone_number": "+919876543210",
       "created_at": "2026-08-18T10:30:00Z"
     }
   }
   ```

7. **Tokens Stored Locally** - The app stores `access_token` and `refresh_token` in Hive encrypted box (`FlutterSecureStorage` on iOS, `encrypted_shared_preferences` on Android). The `AuthBloc` state changes from `AuthUnauthenticated` to `AuthAuthenticated` with the user data.

8. **Navigate to Profile Creation** - Since this is a new user (no profile data exists), the app navigates to the **Profile Creation Screen** (Screen 4).

### 2.4 Existing User - Direct OTP Login Flow

**Trigger:** App finds expired cached tokens during splash, OR user had previously registered but uninstalled/reinstalled the app.

**Step-by-step flow:**

1. **OTP Screen Opens (Pre-filled)** - The OTP Verification Screen opens, but the phone number field is **pre-filled** with the last used phone number (retrieved from Hive local storage before token cleanup). The field shows the number with a green checkmark indicating "Previously registered number."

2. **User Taps "Send OTP"** - Same API call as new user (`POST /api/v1/auth/register`), but the backend detects an existing user in `supabase.auth.users` and returns `409 USER_EXISTS` with a helpful message. The app intercepts this 409 response and shows: "We found your account! Please verify OTP to log in."

3. **OTP Sent** - The backend still sends a new OTP via Twilio Verify API and creates a new `otp_sessions` entry. The same 6-digit OTP input UI appears.

4. **User Enters OTP & Verifies** - Same `POST /api/v1/auth/verify-otp` call. Since the user already exists in Supabase Auth, the backend skips user creation and goes directly to token generation. The response includes existing profile data.

5. **Profile Check & Redirect** - The app checks if the user has a complete profile (display_name is not null). If profile is complete, the app navigates directly to the **Dashboard Screen** (Screen 8). If profile is incomplete (display_name is null), the app navigates to the **Profile Creation Screen** (Screen 4).

### 2.5 Profile Creation & Setup

**Trigger:** New user completes OTP verification, OR existing user has incomplete profile.

**Step-by-step flow:**

1. **Profile Screen Opens** - Shows a welcome message: "Welcome to Caller AI! Let's set up your profile." Fields displayed:
   - **Display Name** (text input, required, min 2 chars, max 30 chars) - e.g., "Rahul Sharma"
   - **Email** (email input, optional) - e.g., "rahul@example.com"
   - **Profile Photo** (circular avatar with camera icon, optional) - Uses `image_picker` package
   - **Skip for Now** link at the bottom

2. **User Fills Profile** - Real-time validation shows green checkmarks when fields are valid.

3. **User Taps "Continue"** - The app calls `PUT /api/v1/users/profile`.

   **API Details:**
   - **Endpoint:** `PUT /api/v1/users/profile`
   - **API Key Used:** Supabase Auth API Key (Bearer JWT in Authorization header)
   - **Backend Processing:**
     a. JWT is validated via Supabase Auth (extracts `user_id` from token claims)
     b. Updates `supabase.public.profiles` table: sets `display_name`, `email`, `avatar_url` (if photo uploaded, stored in Supabase Storage bucket `avatars`)
     c. Returns updated profile

   **Sample Request:**
   ```json
   {
     "display_name": "Rahul Sharma",
     "email": "rahul@example.com",
     "avatar_url": null
   }
   ```

4. **Navigate to AI Agent Setup** - After profile save succeeds, the app navigates to the **AI Agent Setup Screen** (Screen 5) where the user names their AI assistant and selects its voice.

### 2.6 System Permission Granting Flow

**Trigger:** After AI Agent setup is complete (or skipped), before entering the main app.

**Step-by-step flow:**

1. **Permission Screen Opens** - Shows a list of required permissions with icons, descriptions, and toggle switches:

   | Permission | Purpose | API/Service Impact |
   |-----------|---------|-------------------|
   | Phone State | Detect incoming calls, read call log | Required for core caller ID functionality |
   | Microphone | AI voice agent audio capture | Required for AI agent to speak and listen |
   | Overlay (Android) / CallKit (iOS) | Show caller ID overlay during calls | Required for native call screen integration |
   | Contacts | Read saved contacts for WhatsApp diversion | Required for contact diversion feature |
   | Notifications | Push notifications for spam alerts, AI transcripts | Required for real-time alerts |

2. **User Grants Each Permission** - Each permission is requested individually via the native permission dialog. If the user denies a critical permission (Phone State, Microphone), a dialog explains why it's needed with a "Grant Permission" button that opens the app's system settings page. Non-critical permissions (Contacts, Notifications) can be granted later from Settings.

3. **Permission Status Saved** - The app saves granted/denied permission states to Hive for reference. On subsequent launches, only denied permissions are re-prompted.

4. **Navigate to Onboarding** - After critical permissions are granted, navigate to the **Onboarding Screen** (Screen 7) for a brief feature walkthrough, or skip directly to **Dashboard** if the user chooses.

### 2.7 AI Agent Name & Voice Setup

**Trigger:** After profile creation, before permission setup.

**Step-by-step flow:**

1. **AI Agent Setup Screen Opens** - Shows: "Name Your AI Assistant" heading, a text input field (placeholder: "e.g., Alexa, Max, Sara"), a voice preview carousel below, and personality selector cards.

2. **User Types AI Agent Name** - e.g., "Max". The name is validated (2-20 characters, alphanumeric + spaces only).

3. **User Selects Voice** - The carousel shows 4-6 voice options (e.g., "Rachel - Female, Warm", "James - Male, Professional", "Aria - Female, Friendly", "David - Male, Calm"). Each option has a Play button that calls `POST /api/v1/ai/call/speak-text` with a sample sentence ("Hi, I'm {agent_name}. How can I help you today?") to preview the voice. This API uses **Google Cloud TTS API Key** to generate the audio, which plays through the device speaker.

4. **User Selects Personality** - Three cards: "Professional" (formal tone, business-appropriate), "Friendly" (casual, warm, conversational), "Concise" (brief, to-the-point responses). One is pre-selected.

5. **User Taps "Save & Continue"** - The app calls `POST /api/v1/ai/agent/config`.

   **API Details:**
   - **Endpoint:** `POST /api/v1/ai/agent/config`
   - **API Key Used:** Supabase Auth API Key (JWT), Google Cloud TTS API Key (voice preview)
   - **Backend Processing:**
     a. Validates JWT, extracts `user_id`
     b. Inserts/updates row in `supabase.public.ai_agent_configs` table with `agent_name`, `voice_id`, `personality`, `language`, `busy_mode_enabled: false`, `spam_handling_enabled: true` (default on), `greeting_template`
     c. Returns the saved config

   **Sample Request:**
   ```json
   {
     "agent_name": "Max",
     "voice_id": "en-US-Neural2-A",
     "personality": "friendly",
     "language": "en-US",
     "spam_handling_enabled": true,
     "busy_mode_enabled": false,
     "greeting_template": "Hello, I'm Max. Rahul is currently unavailable. How can I help?"
   }
   ```

6. **Navigate to Permission Setup** - Continues to the permission granting flow.

### 2.8 Entering the App Dashboard

**Trigger:** All setup flows complete (or skipped). This is the main entry point for returning users.

**Step-by-step flow:**

1. **Dashboard Screen Opens** - The main dashboard loads with:
   - **Top Bar:** App logo (left), user avatar with notification bell (right)
   - **Search Bar:** Global phone number lookup input with country code selector
   - **AdMob Banner:** A banner ad at the top (only for free-tier users, hidden for premium)
   - **Stats Row:** Three metric cards: "Total Lookups: 247", "AI Calls Handled: 12", "Spam Blocked: 89"
   - **Tab Navigation:** 5 tabs at bottom: Home, Call Log, AI Agent, Spam, Settings
   - **Recent Calls List:** Last 10 calls with caller ID annotations

2. **API Calls on Dashboard Load:**
   - `GET /api/v1/users/profile` - Fetch user profile (Supabase Auth API Key)
   - `GET /api/v1/ai/agent/config` - Fetch AI agent config (Supabase Auth API Key)
   - `GET /api/v1/spam/stats` - Fetch spam statistics (Supabase Auth API Key)
   - `GET /api/v1/lookup/recent` - Fetch recent lookups (Supabase Auth API Key)
   - `POST /api/v1/users/devices` - Register/update FCM token (Supabase Auth API Key + Firebase API Key)
   - AdMob SDK initializes and requests a banner ad using **Google AdMob App ID + Ad Unit ID**

3. **Background Sync:**
   - App syncs local Isar database with Supabase: downloads updated spam signatures, refreshes cached caller ID data, and pulls any new AI call transcripts that occurred while the app was closed.
   - On-device TensorFlow Lite model updates spam signatures from the latest sync.

### 2.9 Complete Screen Navigation Map

```
Splash Screen
  │
  ├─[New User]──> OTP Verification (New) ──> Profile Creation ──> AI Agent Setup ──> Permission Setup ──> Onboarding ──> Dashboard
  │                                                                                                         │
  │                                                                                                         ├─> Call Log
  │                                                                                                         ├─> Number Search
  │                                                                                                         ├─> AI Agent Config
  │                                                                                                         ├─> AI Call History
  │                                                                                                         ├─> Spam Center
  │                                                                                                         ├─> WhatsApp Bridge
  │                                                                                                         ├─> Settings
  │                                                                                                         ├─> Profile & Account
  │                                                                                                         ├─> Premium
  │                                                                                                         └─> Notifications
  │
  └─[Existing User]──> OTP Verification (Pre-filled) ──> [Profile Complete?]──Yes──> Dashboard
                                                                    │                                      │
                                                                    └──No──> Profile Creation ──────────────┘

Incoming Call (Any Screen):
  └─> Call Overlay UI ──> [Spam Detected?]──Yes──> AI Voice Agent (Live) ──> Transcript Saved ──> Notification
                                  │
                                  └──No──> [Busy Mode?]──Yes──> AI Voice Agent (Busy) ──> Transcript Saved ──> Notification
                                                    │
                                                    └──No──> [WhatsApp Divert?]──Yes──> WhatsApp Message Sent ──> Notification
                                                                      │
                                                                      └──No──> Normal Ring Through
```

---

## 3. API Keys Usage Details

### 3.1 Complete API Key Inventory

| # | API Service | Key Name | Purpose | Usage Context | Monthly Cost Estimate |
|---|------------|----------|---------|---------------|---------------------|
| 1 | **Supabase** | `SUPABASE_URL` | Project URL for all Supabase operations | Auth, DB, Storage | Free tier: 500MB DB, 1GB storage |
| 2 | **Supabase** | `SUPABASE_ANON_KEY` | Anonymous/public API key | Client-side auth, public data access | Included |
| 3 | **Supabase** | `SUPABASE_SERVICE_KEY` | Server-side admin key (bypasses RLS) | Backend admin operations, user creation | Included |
| 4 | **Twilio** | `TWILIO_ACCOUNT_SID` | Account identifier | All Twilio API calls | $1.15/month per phone number |
| 5 | **Twilio** | `TWILIO_AUTH_TOKEN` | Authentication credential | Paired with Account SID | Included |
| 6 | **Twilio** | `TWILIO_VERIFY_SID` | Verify Service SID for OTP | Sending OTP SMS via Twilio Verify | $0.05 per OTP, $0.005 per verification |
| 7 | **Twilio** | `TWILIO_PHONE_NUMBER` | Twilio-owned phone number | Receiving forwarded calls | $1.15/month |
| 8 | **OpenAI** | `OPENAI_API_KEY` | API key for Whisper & GPT | Speech-to-text transcription, response generation | $0.006/min Whisper |
| 9 | **Google Cloud** | `GOOGLE_TTS_API_KEY` | Text-to-Speech API key | AI voice synthesis | $4.00/1M characters |
| 10 | **Google Cloud** | `GOOGLE_CREDENTIALS_JSON` | Service account credentials | Server-side TTS authentication | Included |
| 11 | **WhatsApp Business** | `WHATSAPP_BUSINESS_ACCOUNT_ID` | Business account ID | WhatsApp API authentication | $0.005-0.08 per conversation |
| 12 | **WhatsApp Business** | `WHATSAPP_ACCESS_TOKEN` | Permanent access token | Sending WhatsApp messages | Included |
| 13 | **WhatsApp Business** | `WHATSAPP_PHONE_NUMBER_ID` | Business phone number ID | Sender identification | Included |
| 14 | **Telnyx** | `TELNYX_API_KEY` | CNAM lookup API key | Caller name lookup (Tier 3 waterfall) | $0.003/lookup |
| 15 | **TrestleIQ** | `TRESTLEIQ_API_KEY` | Phone validation + CNAM | Caller name lookup (Tier 3 waterfall) | $0.005/lookup |
| 16 | **Apify** | `APIFY_API_TOKEN` | Web scraping actor token | OSINT caller search (Tier 4 waterfall) | $0.003/scrape |
| 17 | **Google AdMob** | `ADMOB_APP_ID` | AdMob application identifier | Ad SDK initialization (main screen only) | Free |
| 18 | **Google AdMob** | `ADMOB_AD_UNIT_ID` | Banner ad unit identifier | Loading banner ads | Revenue: $0.50-2.00 eCPM |
| 19 | **Firebase** | `FIREBASE_SERVER_KEY` | Server key for FCM | Sending push notifications | Free (up to 1M/month) |
| 20 | **Redis** | `REDIS_URL` | Redis connection URL | Caching layer | $15/month (2-node cluster) |
| 21 | **RevenueCat** | `REVENUECAT_API_KEY` | Subscription management API | Premium tier management | Free tier + 1% transaction fee |
| 22 | **Mixpanel** | `MIXPANEL_TOKEN` | Analytics project token | Event tracking, funnel analysis | Free up to 100K events/month |
| 23 | **Meilisearch** | `MEILISEARCH_API_KEY` | Search engine API key | Full-text transcript search | Free tier: 50MB |

### 3.2 API Key to Operation Mapping

**Authentication & User Management:**
| Operation | Supabase URL | Supabase Anon Key | Supabase Service Key | Twilio Verify SID |
|-----------|:-----------:|:----------------:|:-------------------:|:------------------:|
| Send OTP | Yes | Yes | No | Yes |
| Verify OTP | Yes | Yes | Yes (create user) | No |
| Refresh Token | Yes | Yes | No | No |
| Get Profile | Yes | Yes | No | No |
| Update Profile | Yes | Yes | No | No |
| Register FCM Token | Yes | Yes | No | No |

**Caller Identification (Waterfall):**
| Operation | Redis URL | Telnyx API Key | TrestleIQ API Key | Apify Token |
|-----------|:--------:|:-------------:|:----------------:|:----------:|
| Cache Lookup | Yes | No | No | No |
| CNAM Lookup (Tier 3) | No | Yes | Yes | No |
| OSINT Search (Tier 4) | No | No | No | Yes |

**AI Voice Processing:**
| Operation | OpenAI API Key | Google TTS Key | Twilio SID + Token |
|-----------|:-------------:|:-------------:|:-----------------:|
| Speech-to-Text (Whisper) | Yes | No | No |
| Text-to-Speech (Google) | No | Yes | No |
| Voice Call Setup (TwiML) | No | No | Yes |
| Media Stream WebSocket | No | No | Yes |
| AI Response Generation | Yes (optional GPT) | No | No |

**WhatsApp Bridge:**
| Operation | WhatsApp Account ID | WhatsApp Access Token | WhatsApp Phone ID |
|-----------|:------------------:|:---------------------:|:------------------:|
| Send Diversion Message | Yes | Yes | Yes |
| Check Connection Status | Yes | Yes | No |
| Get Message History | Yes | Yes | No |

### 3.3 API Key Usage Flow Per Screen

**Screen: OTP Verification**
```
User taps "Send OTP"
  -> Flutter app reads SUPABASE_ANON_KEY from .env
  -> POST /api/v1/auth/register
     -> Backend reads: SUPABASE_URL, SUPABASE_SERVICE_KEY, TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SID
     -> Backend validates phone via Supabase
     -> Backend sends OTP via Twilio Verify API (using TWILIO_VERIFY_SID)
  <- Returns session_id

User enters OTP and taps "Verify"
  -> POST /api/v1/auth/verify-otp
     -> Backend reads: SUPABASE_URL, SUPABASE_SERVICE_KEY
     -> Backend verifies OTP hash in Supabase otp_sessions table
     -> Backend creates user in Supabase Auth (using SUPABASE_SERVICE_KEY)
     -> Backend creates profile in Supabase profiles table
     -> Backend generates JWT via Supabase Auth
  <- Returns access_token, refresh_token
```

**Screen: Dashboard**
```
Dashboard loads
  -> GET /api/v1/users/profile (Bearer JWT) - uses SUPABASE_URL, SUPABASE_ANON_KEY
  -> GET /api/v1/ai/agent/config (Bearer JWT) - uses SUPABASE_URL, SUPABASE_ANON_KEY
  -> GET /api/v1/spam/stats (Bearer JWT) - uses SUPABASE_URL, SUPABASE_ANON_KEY
  -> POST /api/v1/users/devices (Bearer JWT) - uses SUPABASE_URL, SUPABASE_ANON_KEY, FIREBASE_SERVER_KEY
  -> AdMob SDK loads banner - uses ADMOB_APP_ID, ADMOB_AD_UNIT_ID
  -> Mixpanel tracks "dashboard_viewed" event - uses MIXPANEL_TOKEN

User searches a number
  -> GET /api/v1/lookup?phone_number=+91...
     -> Backend checks Redis (REDIS_URL) - cache hit: return immediately
     -> Cache miss: Telnyx CNAM (TELNYX_API_KEY) -> TrestleIQ CNAM (TRESTLEIQ_API_KEY) -> Apify OSINT (APIFY_API_TOKEN)
     -> Cache result in Redis
  <- Returns caller identity

Incoming spam call detected
  -> POST /api/v1/ai/call/handle (Twilio webhook, signature validated with TWILIO_AUTH_TOKEN)
     -> Twilio connects call to WebSocket
     -> WebSocket streams audio to backend
     -> Backend transcribes via OpenAI Whisper (OPENAI_API_KEY)
     -> Backend classifies intent via NLP
     -> Backend generates response text
     -> Backend synthesizes speech via Google TTS (GOOGLE_TTS_API_KEY)
     -> Speech streamed back via Twilio WebSocket
     -> Transcript saved to Supabase (SUPABASE_URL, SUPABASE_SERVICE_KEY)
     -> Push notification sent via FCM (FIREBASE_SERVER_KEY)
  <- User sees AI Call notification with transcript summary
```

### 3.4 Key Rotation & Security Strategy

| Key Type | Rotation Frequency | Storage Location | Rotation Method |
|----------|-------------------|------------------|-----------------|
| Supabase Keys | Never rotate (project-level) | Backend `.env`, Supabase Dashboard | Project migration if compromised |
| Twilio Auth Token | Every 90 days | Backend `.env` | Twilio Console > API Keys > Rotate |
| OpenAI API Key | Every 60 days | Backend `.env` + Vault | OpenAI Platform > API Keys > Regenerate |
| Google TTS Key | Every 90 days | Backend `.env` + Vault | Google Cloud Console > Service Accounts |
| WhatsApp Token | Every 180 days | Backend `.env` | Meta Business Suite > System Users |
| Telnyx/TrestleIQ/Apify | Every 60 days | Backend `.env` | Provider Dashboard > API Keys |
| AdMob Keys | Never rotate (app-level) | Flutter `lib/env.dart` | App update required |
| Firebase Server Key | Every 180 days | Backend `.env` | Firebase Console > Project Settings |
| Redis URL | Never rotate (infra-level) | Backend `.env` | Infrastructure change only |

All API keys are stored in environment variables (`.env` file on backend, `env.dart` on Flutter frontend). The backend uses `python-dotenv` to load environment variables. The frontend only stores non-secret keys (Supabase Anon Key, AdMob App ID, Mixpanel Token) - all secret keys are accessed exclusively through the backend API, never exposed to the client.

---

## 4. Tech Stack Specification

### 4.1 Complete Technology Stack Matrix

| Layer | Technology | Version | Purpose | Key Configuration |
|-------|-----------|---------|---------|-------------------|
| **Mobile Frontend** | Flutter (Dart) | 3.24+ | Cross-platform mobile app | Bloc pattern, Clean Architecture, Hive + Isar |
| **Native Bridge (Android)** | Kotlin | 1.9+ | Call interception, overlay, audio | BroadcastReceiver, WindowManager, MethodChannel, AudioRecord |
| **Native Bridge (iOS)** | Swift | 5.9+ | CallKit directory, audio capture | CXCallDirectoryProvider, AVAudioSession, PushKit |
| **Backend API** | FastAPI (Python) | 0.115+ | REST API server, async processing | Uvicorn + Gunicorn, Pydantic v2, auto-scaling |
| **Auth & User DB** | Supabase | Latest | User accounts, profiles, OTP | JWT auth, RLS policies, real-time subscriptions |
| **Primary Database** | PostgreSQL (via Supabase) | 16+ | Persistent data storage | Supabase managed, RLS, pgcrypto |
| **Cache** | Redis | 7.2+ | Sub-10ms lookup cache | 2-node cluster, 4GB each, TTL eviction, LRU |
| **AI Speech-to-Text** | OpenAI Whisper API | v1 | Real-time audio transcription | Language detection, timestamps, segment buffering |
| **AI Text-to-Speech** | Google Cloud TTS | v1 | Natural voice synthesis | Multiple voices, SSML support, streaming |
| **AI NLP** | spaCy + Custom Classifier | 3.7+ | Intent recognition, entity extraction | Fine-tuned on telecom spam dataset |
| **Voice Infrastructure** | Twilio Programmable Voice | Latest | Call routing, media streaming | TwiML, WebSocket Media Streams, Verify |
| **WhatsApp** | WhatsApp Business API | v18.0 | Call diversion, messaging | Template messages, session management |
| **Search** | Meilisearch | 1.6+ | Full-text transcript search | Typo tolerance, relevance ranking |
| **Object Storage** | Supabase Storage | Latest | Audio files, avatars, exports | S3-compatible, CDN delivery |
| **Analytics** | Mixpanel | Latest | Event tracking, funnels | Custom events, user properties, cohort analysis |
| **Ad Revenue** | Google AdMob | Latest | Banner + interstitial ads | Main screen only, mediation via AppLovin MAX |
| **Subscriptions** | RevenueCat | Latest | Premium tier management | iOS/Android in-app purchase handling |
| **Push Notifications** | Firebase Cloud Messaging | Latest | Real-time push alerts | FCM tokens, topic subscriptions |
| **Monitoring** | Prometheus + Grafana | Latest | Metrics, dashboards, alerting | Custom exporters, SLO tracking |
| **CI/CD** | GitHub Actions | Latest | Build, test, deploy pipeline | Docker builds, automated testing, staged rollout |

---

## 5. Project Structure

### 5.1 Backend Project Structure (FastAPI + Supabase)

```
caller_ai_backend/
|-- app/
|   |-- __init__.py
|   |-- main.py                        # FastAPI app bootstrap, CORS, lifespan
|   |-- api/
|   |   |-- v1/
|   |   |   |-- endpoints/
|   |   |   |   |-- auth.py           # Registration, OTP, token management (Supabase Auth)
|   |   |   |   |-- lookup.py         # Waterfall routing, single + batch
|   |   |   |   |-- spam.py           # Spam report, query, stats, search
|   |   |   |   |-- ai_agent.py       # AI voice agent config + call handling
|   |   |   |   |-- ai_transcript.py  # Transcript retrieval + search
|   |   |   |   |-- whatsapp.py       # WhatsApp diversion + messaging
|   |   |   |   |-- users.py          # Profile, blocklist, device tokens
|   |   |   |   |-- numbers.py        # Number search, carrier info
|   |   |   |   |-- admin.py          # Admin analytics, user management
|   |   |   |   |-- settings.py       # User preferences, notification prefs
|   |   |   |   |-- health.py         # Health check, readiness probe
|   |   |   |-- api.py                # Unified v1 router declaration
|   |-- core/
|   |   |-- config.py                 # Pydantic BaseSettings (env vars)
|   |   |-- security.py               # JWT RS256 via Supabase, utilities
|   |   |-- database.py               # Supabase client factory (async)
|   |   |-- supabase_client.py        # Supabase Admin/Auth client wrappers
|   |   |-- rate_limiter.py           # Redis sliding window rate limiter
|   |   |-- twilio_client.py          # Twilio REST client + TwiML generator
|   |   |-- whatsapp_client.py        # WhatsApp Business API client
|   |-- models/
|   |   |-- user.py                   # User, DeviceToken, Subscription (Supabase tables)
|   |   |-- spam_report.py            # SpamReport, SpamCategory
|   |   |-- lookup_cache.py           # LookupCache, CacheAudit
|   |   |-- blocklist.py              # BlockedNumber
|   |   |-- ai_agent_config.py        # AIAgentConfig, VoiceProfile
|   |   |-- ai_call_transcript.py     # AICallTranscript, ExtractedEntity
|   |   |-- whatsapp_message.py       # WhatsAppMessage, DiversionLog
|   |   |-- ad_impression.py          # AdImpression, AdClick
|   |   |-- contact_collection.py     # CollectedContact
|   |   |-- maid_registry.py          # MAIDRegistry, DemographicProfile
|   |   |-- data_consent.py           # DataConsentRecord
|   |-- schemas/
|   |   |-- auth.py                   # Registration, OTP, Token schemas
|   |   |-- lookup.py                 # LookupRequest, LookupResponse
|   |   |-- spam.py                   # SpamReport, SpamStats schemas
|   |   |-- user.py                   # UserProfile, UpdateProfile
|   |   |-- ai_agent.py               # AgentConfig, Transcript schemas
|   |   |-- whatsapp.py               # Diversion, Message schemas
|   |-- services/
|   |   |-- aggregator.py             # Multi-tier waterfall engine
|   |   |-- redis_cache.py            # Redis read/write abstraction
|   |   |-- key_rotator.py            # API key pool & rotation manager
|   |   |-- circuit_breaker.py        # Per-provider fault tolerance
|   |   |-- spam_engine.py            # Spam scoring & classification
|   |   |-- ai_voice_service.py       # Speech-to-Text, NLP, TTS pipeline
|   |   |-- ai_response_generator.py  # Template + LLM response generation
|   |   |-- whatsapp_bridge_service.py# WhatsApp diversion & messaging
|   |   |-- ad_service.py             # Ad impression tracking, targeting
|   |   |-- data_collection_service.py # Contact & MAID collection pipeline
|   |   |-- subscription_service.py   # Premium tier management (RevenueCat)
|   |   |-- supabase_auth_service.py  # Supabase Auth wrapper (signup, verify, token)
|   |-- tasks/
|   |   |-- cache_warming.py           # Periodic cache refresh
|   |   |-- analytics.py               # Batch analytics aggregation
|   |   |-- audio_cleanup.py           # Purge expired audio from Supabase Storage
|   |   |-- consent_audit.py           # Verify consent compliance
|-- tests/
|   |-- conftest.py
|   |-- test_auth.py
|   |-- test_lookup.py
|   |-- test_ai_voice.py
|   |-- test_whatsapp.py
|   |-- test_supabase.py
|-- requirements.txt
|-- Dockerfile
|-- docker-compose.yml
|-- .env                              # (gitignored) All API keys & secrets
```

### 5.2 Frontend Project Structure (Flutter)

```
caller_ai_frontend/
|-- android/app/src/main/kotlin/com/app/callerai/
|   |-- MainActivity.kt               # Native overlay + audio bridge
|   |-- CallReceiver.kt               # BroadcastReceiver for PHONE_STATE
|   |-- AudioStreamService.kt         # Audio capture/playback service
|   |-- OverlayService.kt             # Call overlay window management
|-- ios/Runner/
|   |-- CallDirectoryHandler.swift     # CXCallDirectoryProvider
|   |-- AudioHandler.swift            # PushKit audio handling
|   |-- CallDirectoryExtension.swift  # CallKit extension
|-- lib/
|   |-- main.dart                      # App entry, permission initialization
|   |-- core/
|   |   |-- constants/                 # Colors, text styles, dimensions
|   |   |-- network/                   # Dio HTTP client, WebSocket client
|   |   |-- permissions/              # Call log, overlay, mic permissions
|   |   |-- theme/                     # AppTheme, dark/light mode
|   |   |-- env.dart                   # API keys (Supabase URL, Anon Key, AdMob IDs)
|   |-- data/
|   |   |-- models/                    # API response serialization
|   |   |-- repositories/              # Repository pattern abstractions
|   |   |-- datasources/               # Remote API & local cache sources
|   |-- domain/
|   |   |-- entities/                  # Core business logic entities
|   |   |-- usecases/                  # Single-responsibility use cases
|   |-- presentation/
|   |   |-- blocs/
|   |   |   |-- auth_bloc.dart
|   |   |   |-- lookup_bloc.dart
|   |   |   |-- spam_bloc.dart
|   |   |   |-- call_log_bloc.dart
|   |   |   |-- ai_agent_bloc.dart
|   |   |   |-- whatsapp_bloc.dart
|   |   |   |-- dashboard_bloc.dart
|   |   |-- screens/
|   |   |   |-- splash_screen.dart
|   |   |   |-- otp_verification_screen.dart
|   |   |   |-- profile_creation_screen.dart
|   |   |   |-- ai_agent_setup_screen.dart
|   |   |   |-- permission_setup_screen.dart
|   |   |   |-- onboarding_screen.dart
|   |   |   |-- dashboard_screen.dart
|   |   |   |-- call_log_screen.dart
|   |   |   |-- number_search_screen.dart
|   |   |   |-- ai_agent_screen.dart
|   |   |   |-- ai_call_history_screen.dart
|   |   |   |-- spam_center_screen.dart
|   |   |   |-- whatsapp_screen.dart
|   |   |   |-- settings_screen.dart
|   |   |   |-- profile_screen.dart
|   |   |   |-- notification_screen.dart
|   |   |   |-- premium_screen.dart
|   |   |   |-- call_overlay_screen.dart
|   |   |   |-- ai_voice_call_screen.dart
|   |   |-- widgets/
|   |   |   |-- caller_id_card.dart
|   |   |   |-- spam_badge.dart
|   |   |   |-- ai_status_card.dart
|   |   |   |-- ad_banner_widget.dart
|   |   |   |-- transcript_viewer.dart
|   |   |   |-- whatsapp_action_button.dart
|   |   |   |-- otp_input_field.dart
|   |   |   |-- voice_preview_card.dart
|   |   |   |-- stat_metric_card.dart
|-- assets/
|   |-- images/
|   |-- icons/
|   |-- animations/
|-- pubspec.yaml
|-- .env                              # (gitignored) Frontend API keys
```

---

## 6. REST APIs - Complete Specification

### 6.1 Authentication APIs

#### POST /api/v1/auth/register
- **Purpose:** Send OTP to phone number for registration or login
- **Auth Required:** None (public endpoint, uses Supabase Anon Key)
- **Rate Limit:** 5 requests per phone number per hour (Redis sliding window)
- **API Keys Used:** `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SID`
- **Request Body:**
  ```json
  { "phone_number": "+919876543210", "device_uuid": "abc-123", "device_type": "android", "country_code": "IN", "app_version": "2.0.0" }
  ```
- **Success (201):** `{ "status": "success", "message": "OTP sent", "session_id": "sess_xyz", "expires_in": 300 }`
- **Error (409):** `{ "status": "error", "code": "USER_EXISTS", "message": "Account already exists. Verify OTP to login." }`
- **Error (429):** `{ "status": "error", "code": "RATE_LIMITED", "message": "Too many OTP requests. Try again in 58 minutes." }`

#### POST /api/v1/auth/verify-otp
- **Purpose:** Verify OTP and issue JWT tokens
- **Auth Required:** None (uses session_id from registration)
- **Rate Limit:** 10 attempts per session_id
- **API Keys Used:** `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`
- **Request Body:** `{ "session_id": "sess_xyz", "otp_code": "123456" }`
- **Success (200):** `{ "access_token": "eyJ...", "refresh_token": "v1.stoken_...", "expires_in": 1800, "user": { "id": "uuid", "phone_number": "+91...", "created_at": "..." } }`
- **Error (410):** `{ "status": "error", "code": "OTP_EXPIRED", "message": "OTP expired. Please request a new one." }`
- **Error (401):** `{ "status": "error", "code": "INVALID_OTP", "message": "The OTP you entered is incorrect." }`

#### POST /api/v1/auth/refresh-token
- **Purpose:** Exchange refresh token for new access token
- **API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- **Request Body:** `{ "refresh_token": "v1.stoken_..." }`
- **Success (200):** `{ "access_token": "eyJ...", "refresh_token": "v1.stoken_...", "expires_in": 1800 }`

#### POST /api/v1/auth/logout
- **Purpose:** Revoke tokens and invalidate session
- **Auth Required:** Bearer JWT
- **Request Body:** `{ "refresh_token": "v1.stoken_...", "device_uuid": "..." }`

### 6.2 User Profile & Management APIs

#### GET /api/v1/users/profile
- **Purpose:** Retrieve user profile with subscription status
- **Auth Required:** Bearer JWT
- **API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- **Success (200):**
  ```json
  {
    "id": "uuid", "phone_number": "+919876543210", "display_name": "Rahul Sharma",
    "email": "rahul@example.com", "avatar_url": "https://...", "plan": "free",
    "ai_calls_used": 12, "ai_calls_limit": 10, "created_at": "2026-08-01T..."
  }
  ```

#### PUT /api/v1/users/profile
- **Purpose:** Update display name, email, avatar
- **Auth Required:** Bearer JWT
- **API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- **Request Body:** `{ "display_name": "Rahul S.", "email": "rahul@new.com" }`

#### POST /api/v1/users/devices
- **Purpose:** Register device FCM token for push notifications
- **API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FIREBASE_SERVER_KEY`
- **Request Body:** `{ "device_uuid": "...", "fcm_token": "fcm_abc123", "platform": "android" }`

#### DELETE /api/v1/users/devices/{device_uuid}
- **Purpose:** Unregister device token on logout

#### GET /api/v1/users/subscription
- **Purpose:** Get current subscription status
- **API Keys Used:** `SUPABASE_URL`, `REVENUECAT_API_KEY`
- **Success (200):** `{ "plan": "free", "expires_at": null, "features": { "ai_agent_limit": 10, "ads_enabled": true, "busy_mode": false } }`

### 6.3 Lookup APIs

#### GET /api/v1/lookup
- **Purpose:** Real-time caller identification (single number)
- **Auth Required:** Bearer JWT
- **Rate Limit:** 100 req/min per user
- **API Keys Used:** `REDIS_URL`, `TELNYX_API_KEY`, `TRESTLEIQ_API_KEY`, `APIFY_API_TOKEN`
- **Query Params:** `phone_number` (E.164, required), `request_id` (optional UUID)
- **Backend Flow:** Redis Cache (5ms) -> Country Registry (200ms) -> Telnyx + TrestleIQ CNAM (500ms) -> Apify OSINT (800ms)
- **Success (200):**
  ```json
  {
    "phone_number": "+919876543210", "caller_name": "Rahul Sharma", "carrier": "Jio",
    "line_type": "mobile", "country": "IN", "region": "Maharashtra",
    "spam_analytics": { "score": 87, "category": "Telemarketer", "report_count": 23 },
    "verification_status": "verified", "cache_hit": false, "lookup_tier": 3, "latency_ms": 342
  }
  ```

#### POST /api/v1/lookup/batch
- **Purpose:** Bulk caller identification (up to 50 numbers)
- **Request Body:** `{ "phone_numbers": ["+919876543210", "+14155552671"] }`
- **Success (200):** `{ "results": [...], "total": 2, "cached_count": 1, "lookup_count": 1 }`

### 6.4 Spam APIs

#### POST /api/v1/spam/report
- **Purpose:** Submit spam report with category and comment
- **Request Body:** `{ "reported_number": "+91...", "category": "Telemarketer", "comment": "Kept calling about loan" }`
- **Success (200):** `{ "status": "success", "report_id": "uuid", "updated_spam_score": 87 }`

#### GET /api/v1/spam/check
- **Purpose:** Check spam status for a number
- **Success (200):** Full spam analytics with score, categories, confidence, recent reports

#### GET /api/v1/spam/stats
- **Purpose:** Global spam stats for authenticated user
- **Success (200):** `{ "total_blocked": 89, "reports_submitted": 5, "detection_accuracy": 94.2, "top_categories": [...] }`

### 6.5 AI Voice Agent APIs

#### POST /api/v1/ai/agent/config
- **Purpose:** Create or update AI agent configuration
- **API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_TTS_API_KEY` (for voice preview)
- **Request Body:**
  ```json
  {
    "agent_name": "Max", "voice_id": "en-US-Neural2-A", "personality": "friendly",
    "language": "en-US", "busy_mode_enabled": false, "spam_handling_enabled": true,
    "greeting_template": "Hello, I'm Max. Rahul is currently busy. How can I help?"
  }
  ```

#### GET /api/v1/ai/agent/config
- **Purpose:** Retrieve current AI agent configuration

#### POST /api/v1/ai/call/handle
- **Purpose:** Initiate AI voice agent for incoming call (Twilio webhook)
- **Auth Required:** Twilio signature validation (uses `TWILIO_AUTH_TOKEN`)
- **API Keys Used:** `TWILIO_AUTH_TOKEN`, `OPENAI_API_KEY`, `GOOGLE_TTS_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`
- **Request Body:** `{ "call_sid": "CA...", "from_number": "...", "to_number": "...", "call_type": "spam|busy|whatsapp_divert" }`
- **Success (200):** `{ "status": "handling", "websocket_url": "wss://...", "agent_name": "Max", "session_id": "..." }`

#### GET /api/v1/ai/call/transcript/{call_id}
- **Purpose:** Retrieve full transcript of an AI-handled call
- **Success (200):** `{ "call_id": "...", "transcript": [...], "extracted_entities": [...], "summary": "Loan offer: $5000 at 12% interest from XYZ Finance" }`

#### POST /api/v1/ai/call/speak-text
- **Purpose:** Convert text to speech for voice preview on device
- **API Keys Used:** `GOOGLE_TTS_API_KEY`
- **Request Body:** `{ "text": "Hi, I'm Max. How can I help?", "voice_id": "en-US-Neural2-A" }`
- **Success (200):** `{ "audio_url": "https://supabase.co/.../audio.mp3", "duration_seconds": 3.2 }`

#### GET /api/v1/ai/call/history
- **Purpose:** List all AI-handled call transcripts
- **Query Params:** `page`, `per_page`, `call_type` (spam|busy|all)

### 6.6 WhatsApp Bridge APIs

#### POST /api/v1/whatsapp/divert
- **Purpose:** Enable WhatsApp diversion for a contact
- **API Keys Used:** `WHATSAPP_BUSINESS_ACCOUNT_ID`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`
- **Request Body:** `{ "phone_number": "+91...", "auto_reply_template": "Hi, I'm unavailable. Please message me on WhatsApp." }`

#### GET /api/v1/whatsapp/status
- **Purpose:** Check WhatsApp bridge connection status
- **API Keys Used:** `WHATSAPP_BUSINESS_ACCOUNT_ID`, `WHATSAPP_ACCESS_TOKEN`

#### POST /api/v1/whatsapp/send-message
- **Purpose:** Send WhatsApp message to a contact
- **API Keys Used:** `WHATSAPP_BUSINESS_ACCOUNT_ID`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`

#### GET /api/v1/whatsapp/history
- **Purpose:** List WhatsApp diversion and message history

### 6.7 Blocklist, Settings, Number Search, Admin & Health APIs

| Endpoint | Method | Purpose | API Keys Used |
|----------|--------|---------|---------------|
| `/api/v1/blocklist` | POST | Add number to blocklist | Supabase |
| `/api/v1/blocklist` | GET | List blocked numbers (paginated) | Supabase |
| `/api/v1/blocklist/{phone}` | DELETE | Remove from blocklist | Supabase |
| `/api/v1/numbers/search` | GET | Manual number search with enriched results | Redis, Telnyx, TrestleIQ, Apify |
| `/api/v1/numbers/recent-lookups` | GET | User's recent search history | Supabase |
| `/api/v1/settings` | GET | Retrieve all user settings | Supabase |
| `/api/v1/settings` | PUT | Update user settings (partial update) | Supabase |
| `/api/v1/health` | GET | Liveness and readiness probe | None |
| `/api/v1/admin/analytics` | GET | Admin dashboard analytics | Supabase, Mixpanel |
| `/api/v1/admin/users` | GET | User management (paginated) | Supabase |

### 6.8 Global Error Codes

| HTTP Status | Error Code | Description | Client Action |
|-------------|-----------|-------------|----------------|
| 400 | BAD_REQUEST | Malformed request body | Validate input |
| 401 | UNAUTHORIZED | Missing or invalid JWT | Refresh token or re-auth |
| 403 | FORBIDDEN | Premium feature, free tier | Upgrade subscription |
| 404 | NOT_FOUND | Resource does not exist | Verify identifier |
| 409 | CONFLICT | Duplicate resource | Check existing state |
| 410 | GONE | OTP expired | Request new OTP |
| 422 | VALIDATION_ERROR | Pydantic validation failure | Fix field errors |
| 429 | RATE_LIMITED | Rate limit exceeded | Wait for retry_after |
| 500 | INTERNAL_ERROR | Server failure | Retry with backoff |
| 502 | BAD_GATEWAY | Upstream provider failure | Auto waterfall failover |
| 503 | SERVICE_UNAVAILABLE | Service degraded | Retry after delay |

---

## 7. Mobile App Screens - Deep Dive

### 7.1 Screen 1: Splash Screen

**Screen File:** `splash_screen.dart`

**UI Layout Description:**
- Full-screen dark gradient background (dark blue-gray to black, `#1a2332` to `#0d1117`)
- Center: Caller AI logo (white icon with blue glow effect, 120x120px)
- Below logo: Pulsing AI brain animation (concentric circles expanding outward, 2-second loop)
- Below animation: App name "Caller AI" in white, 32px, bold
- Below name: Tagline "Your AI Call Assistant" in muted gray, 14px
- Bottom: Version text "v2.0.0" in very muted gray, 10px

**Operations Performed:**
- Initializes all BLoC providers (AuthBloc, LookupBloc, etc.)
- Checks Hive for cached JWT tokens
- If tokens found: validates expiry, attempts silent refresh via `POST /api/v1/auth/refresh-token`
- Loads AI agent config from local cache
- Syncs local Isar database
- Registers FCM device token via `POST /api/v1/users/devices`

**API Calls:** `POST /api/v1/auth/refresh-token`, `POST /api/v1/users/devices`

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FIREBASE_SERVER_KEY`

**Sample Inputs:** None (automated screen)

**Navigation:** To OTP Screen (new user) OR Dashboard (returning user) OR OTP Screen with pre-filled number (expired session)

---

### 7.2 Screen 2: OTP Verification Screen (New User)

**Screen File:** `otp_verification_screen.dart`

**UI Layout Description:**
- Background: White/light gray (`#f8f9fa`)
- Top: Back arrow button (left), "Verify Your Number" heading (center), 20px bold
- Below heading: Subtitle "We'll send you a 6-digit code to verify your phone number" in muted gray, 13px
- Phone number input section:
  - Country code dropdown (left, flag + "+91")
  - Phone number text field (right, placeholder "Enter mobile number")
  - Real-time format validation with green/red border indicator
- "Send OTP" button (full width, rounded, accent blue `#1f6c92`, disabled when number invalid)
- After OTP sent:
  - 6 individual circular digit input boxes (48x48px each, spaced 12px apart)
  - Each box: light gray border, focused box has blue border + blue shadow
  - Auto-advance to next box on digit entry
  - Backspace goes to previous box
  - "Verify" button (full width, accent blue, disabled until all 6 digits entered)
  - "Resend OTP in 00:59" countdown text (gray, tappable only when at 00:00)
  - "Enter manually" link (opens dialog to paste 6-digit code)
- Bottom: Privacy notice: "By continuing, you agree to our Terms of Service and Privacy Policy" (10px, gray, tappable links)

**Operations Performed:**
1. User enters phone number with country code
2. User taps "Send OTP" -> calls `POST /api/v1/auth/register`
3. If 409 (user exists), shows message: "Account found! Verify OTP to login."
4. If 201 (new user), shows OTP input fields with countdown timer
5. User enters 6 digits -> calls `POST /api/v1/auth/verify-otp`
6. On success: stores tokens, navigates to Profile Creation (new) or Dashboard (existing)
7. On failure: shakes OTP input, shows error message

**API Calls:** `POST /api/v1/auth/register`, `POST /api/v1/auth/verify-otp`

**API Keys Used:**
- `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` (user creation, OTP verification)
- `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SID` (OTP SMS delivery)

**Sample Inputs:**
- Phone number: `+919876543210`
- OTP code: `482916`

**Navigation:** From Splash Screen -> Profile Creation Screen (new user) OR Dashboard (existing user with complete profile)

---

### 7.3 Screen 3: OTP Verification Screen (Existing User)

**Screen File:** `otp_verification_screen.dart` (same file, different state)

**UI Layout Description:**
- Same layout as Screen 2, with these differences:
  - Phone number field is **pre-filled** and **read-only** with the last used number
  - A green checkmark icon appears next to the number: "Recognized number"
  - Heading changes to: "Welcome Back!"
  - Subtitle changes to: "Verify your number to continue where you left off"
  - "Send OTP" button is already enabled and says "Send Verification Code"

**Operations Performed:** Same as Screen 2, but:
- The backend returns `409 USER_EXISTS` which the app intercepts gracefully
- After verification, checks if profile is complete before routing
- If profile complete -> Dashboard directly (skips Profile Creation)

**API Calls:** `POST /api/v1/auth/register`, `POST /api/v1/auth/verify-otp`

**API Keys Used:** Same as Screen 2

**Sample Inputs:**
- Phone number: `+919876543210` (pre-filled)
- OTP code: `739281`

**Navigation:** From Splash Screen (expired token) -> Dashboard (if profile complete) OR Profile Creation (if incomplete)

---

### 7.4 Screen 4: Profile Creation Screen

**Screen File:** `profile_creation_screen.dart`

**UI Layout Description:**
- Background: White with subtle gray pattern
- Top: Skip button (top-right, gray text "Skip for now")
- Center section:
  - "Welcome to Caller AI!" heading, 24px bold, dark text
  - "Let's set up your profile" subtitle, 14px, muted gray
  - Profile photo: Large circular avatar (120x120px) with camera icon overlay, tappable
  - Display Name: Labeled text input ("Display Name *"), placeholder "e.g., Rahul Sharma", required field indicator
  - Email: Labeled text input ("Email (optional)"), placeholder "e.g., rahul@example.com", email keyboard type
  - Real-time validation: green checkmark when name is valid (2+ chars)
- Bottom: "Continue" button (full width, accent blue, disabled until name is valid)

**Operations Performed:**
1. User optionally taps avatar to select photo (uses `image_picker`, uploads to Supabase Storage `avatars` bucket)
2. User enters display name (required) and email (optional)
3. User taps "Continue" -> calls `PUT /api/v1/users/profile`
4. Profile saved to Supabase `profiles` table
5. Navigate to AI Agent Setup Screen

**API Calls:** `PUT /api/v1/users/profile` (with optional avatar upload to Supabase Storage)

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY` (profile update), Supabase Storage (avatar upload)

**Sample Inputs:**
- Display Name: `Rahul Sharma`
- Email: `rahul@gmail.com`
- Avatar: (optional photo from gallery)

**Navigation:** From OTP Screen (new user) -> AI Agent Setup Screen

---

### 7.5 Screen 5: AI Agent Setup Screen

**Screen File:** `ai_agent_setup_screen.dart`

**UI Layout Description:**
- Background: White with light blue accent strip at top (40px, accent color)
- Progress indicator: Step 2 of 3 (dots: filled-filled-empty)
- "Name Your AI Assistant" heading, 22px bold
- "Your AI will answer calls on your behalf" subtitle, 13px, gray
- Agent name input: Large text field, centered, 18px font, placeholder "e.g., Alexa, Max, Sara", max 20 chars
- Below input: Live preview card showing "Hi, I'm [typed name]" in a speech bubble UI
- Voice Selection section:
  - "Choose a Voice" label, 14px, semibold
  - Horizontal scrollable carousel of voice cards (each 160x80px)
  - Each card: voice name ("Rachel"), gender icon (female/male), description ("Warm, Natural"), Play button (circular, 36px)
  - Selected card has blue border + blue checkmark
  - Playing card shows animated waveform
- Personality section:
  - "Personality" label, 14px, semibold
  - Three selectable cards in a row: "Professional" (briefcase icon), "Friendly" (smile icon), "Concise" (zap icon)
  - Selected card has blue background, white text
- Bottom: "Save & Continue" button (full width, accent blue)
- "Skip" link (gray, bottom-left)

**Operations Performed:**
1. User types agent name, live preview updates in speech bubble
2. User taps Play on voice cards -> calls `POST /api/v1/ai/call/speak-text` -> audio plays through speaker
3. User selects a voice and personality
4. User taps "Save & Continue" -> calls `POST /api/v1/ai/agent/config`
5. Config saved to Supabase `ai_agent_configs` table

**API Calls:** `POST /api/v1/ai/call/speak-text` (voice preview), `POST /api/v1/ai/agent/config` (save config)

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY` (save config), `GOOGLE_TTS_API_KEY` (voice preview audio generation)

**Sample Inputs:**
- Agent Name: `Max`
- Voice: `en-US-Neural2-A` ("Rachel - Female, Warm")
- Personality: `friendly`

**Navigation:** From Profile Creation -> Permission Setup Screen

---

### 7.6 Screen 6: Permission Setup Screen

**Screen File:** `permission_setup_screen.dart`

**UI Layout Description:**
- Background: White
- Progress indicator: Step 3 of 3
- "Permissions Needed" heading, 22px bold
- "Caller AI needs these permissions to protect your calls" subtitle
- List of permission cards (each 80px height, white card with left colored icon):
  - **Phone** (green phone icon): "Detect incoming calls and identify callers" - Required toggle (ON by default)
  - **Microphone** (red mic icon): "AI voice agent needs microphone to talk" - Required toggle
  - **Overlay** (blue layers icon): "Show caller ID on incoming call screen" - Required toggle
  - **Contacts** (orange people icon): "Read contacts for WhatsApp diversion" - Optional toggle
  - **Notifications** (purple bell icon): "Get alerts for spam calls and AI transcripts" - Optional toggle
- Each card: toggle switch (right side), tapping toggles and triggers native permission dialog
- Required permissions denied: Red warning banner "This permission is required for Caller AI to work" with "Grant" button
- Bottom: "Continue to App" button (enabled only when all required permissions granted)

**Operations Performed:**
1. App checks current permission states via `permission_handler` package
2. Pre-grants permissions that are already allowed (green checkmarks)
3. User taps each toggle -> native permission dialog appears
4. If user grants: toggle turns green, card gets checkmark
5. If user denies required permission: red warning appears, "Grant" button opens app settings
6. When all required permissions granted: "Continue" button enables
7. Permission states saved to Hive

**API Calls:** None (local operation only)

**API Keys Used:** None

**Sample Inputs:** User grants Phone (Allow), Microphone (Allow), Overlay (Allow), Contacts (Deny), Notifications (Allow)

**Navigation:** From AI Agent Setup -> Onboarding Screen (or skip to Dashboard)

---

### 7.7 Screen 7: Onboarding Screen

**Screen File:** `onboarding_screen.dart`

**UI Layout Description:**
- Full-screen vertical paging (PageView with 4 pages)
- Each page: illustration (top 40%), title (bold 22px), description (14px gray, 3-4 lines)
- Page indicator dots at bottom (4 dots, active dot is accent blue)
- Page 1: "Know Who Calls" - Caller ID illustration, "Identify every caller instantly with AI-powered caller ID and spam protection"
- Page 2: "AI Answers Your Calls" - Robot assistant illustration, "Your AI assistant attends spam calls, extracts details, and reports back to you"
- Page 3: "Never Miss Important Calls" - WhatsApp + busy mode illustration, "Busy? Your AI handles calls and diverts contacts to WhatsApp"
- Page 4: "Your Privacy Matters" - Shield illustration, "Transparent data collection. You control what's shared. GDPR & DPDP compliant."
- Bottom-right: "Next" button (pages 1-3) / "Get Started" button (page 4, accent blue, full width)
- Bottom-left: "Skip" text link (pages 1-3 only)

**Operations Performed:**
1. User swipes through 4 onboarding pages
2. On page 4, user taps "Get Started" -> updates onboarding_complete flag in Hive and Supabase
3. App requests background sync permissions if not already granted
4. Navigates to Dashboard

**API Calls:** `PUT /api/v1/users/profile` (marks onboarding_complete: true)

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`

**Navigation:** From Permission Setup -> Dashboard (main entry point)

---

### 7.8 Screen 8: Main Dashboard

**Screen File:** `dashboard_screen.dart`

**UI Layout Description:**
- **Top App Bar:** Caller AI logo (left), "Dashboard" title (center), User avatar + notification bell with badge count (right)
- **Search Bar:** Rounded search input with country code flag (+91), placeholder "Enter number to identify", search icon (right), microphone icon (left, for voice search - premium feature)
- **AdMob Banner:** 320x50px banner ad below search bar (only free tier, hidden for premium users)
- **Stats Summary Row:** Three horizontal cards (equal width, 100px height each):
  - Card 1: "247" (large blue number) + "Total Lookups" (small gray label)
  - Card 2: "12" (large green number) + "AI Handled" (small gray label)
  - Card 3: "89" (large red number) + "Spam Blocked" (small gray label)
- **AI Agent Status Card:** (if AI agent configured)
  - Card with agent avatar, name ("Max"), status badge ("Active" green / "Standby" gray)
  - Recent AI call count: "Handled 3 calls today"
  - Tappable -> navigates to AI Agent Screen
- **Recent Calls Section:** "Recent Calls" heading (left) + "See All" link (right)
  - Vertically scrolling list (max 8 items visible)
  - Each item: caller avatar/initial, name/number, call type icon (incoming/outgoing/missed/AI), timestamp, spam badge if applicable
  - AI-handled calls show blue "AI" badge with agent name
  - Spam calls show red "Spam" badge
  - Swipe right: instant spam report
  - Swipe left: Block, Copy, WhatsApp Divert, Search options
- **Bottom Navigation Bar:** 5 tabs with icons + labels:
  - Home (house icon) - Active (blue)
  - Call Log (clock icon)
  - AI Agent (robot icon)
  - Spam (shield icon)
  - Settings (gear icon)

**Operations Performed:**
1. On screen load: fetches user profile, AI agent config, spam stats, recent calls
2. Registers FCM token for push notifications
3. AdMob SDK loads banner ad (free tier only)
4. User taps search bar -> navigates to Number Search Screen
5. User taps a recent call -> expands to show call details + caller ID info
6. User taps AI Agent Status Card -> navigates to AI Agent Screen
7. User taps notification bell -> navigates to Notification Screen
8. User taps bottom nav tabs -> switches to respective screens

**API Calls:**
- `GET /api/v1/users/profile` (Supabase)
- `GET /api/v1/ai/agent/config` (Supabase)
- `GET /api/v1/spam/stats` (Supabase)
- `GET /api/v1/lookup/recent` (Supabase)
- `POST /api/v1/users/devices` (Supabase + Firebase)

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `FIREBASE_SERVER_KEY`, `ADMOB_APP_ID`, `ADMOB_AD_UNIT_ID`, `MIXPANEL_TOKEN`

**Sample Inputs:** User taps search bar, types `9876543210`, taps search

**Navigation:** Central hub - navigates to all other screens via bottom nav, cards, and header actions

---

### 7.9 Screen 9: Call Log Screen

**Screen File:** `call_log_screen.dart`

**UI Layout Description:**
- **Top Bar:** "Call Log" title, filter icon (right) - opens filter sheet (All/Missed/AI Handled/Spam/Blocked)
- **Search Bar:** Filter calls by number or name
- **Call List:** Chronological list grouped by date ("Today", "Yesterday", "August 15", etc.)
  - Each entry (72px height):
    - Left: Caller avatar circle (initial letter or photo), spam indicator (red dot top-right if spam)
    - Center: Caller name (or number if unknown), call type subtitle ("Incoming - 2m 34s"), AI badge ("Handled by Max" in blue)
    - Right: Timestamp ("10:30 AM"), call type icon (green incoming / red missed / blue AI)
  - Swipe right: Quick spam report (red swipe with thumbs-down icon)
  - Swipe left: Action buttons - Block, Copy Number, WhatsApp Divert, Search
  - Long press: Multi-select mode for bulk actions
- **Empty State:** If no calls: illustration + "No calls yet. Caller AI will log calls as they come in."

**Operations Performed:**
1. Loads call log from local Isar database (fast, offline-first)
2. Background syncs with Supabase `call_logs` table
3. Each call entry enriched with cached caller ID data from Redis lookups
4. User applies filters -> updates list query
5. User swipe-right -> calls `POST /api/v1/spam/report`
6. User swipe-left -> shows action sheet (Block -> `POST /api/v1/blocklist`, WhatsApp -> `POST /api/v1/whatsapp/divert`)

**API Calls:** `POST /api/v1/spam/report`, `POST /api/v1/blocklist`, `POST /api/v1/whatsapp/divert`

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `WHATSAPP_BUSINESS_ACCOUNT_ID`, `WHATSAPP_ACCESS_TOKEN`

**Navigation:** From Dashboard (Call Log tab) -> Call Detail (tap) -> Number Search (swipe action)

---

### 7.10 Screen 10: Number Search Screen

**Screen File:** `number_search_screen.dart`

**UI Layout Description:**
- **Search Input:** Large input field with country code selector (+91 flag dropdown), phone number input (18px font), clear button (x icon), search button (blue magnifying glass)
- **Recent Searches:** Horizontal scrollable chips below search bar ("+91 98765 43210", "+1 415 555 2671", etc.), each chip tappable to re-search, long-press to delete
- **Search Results Card** (appears after search):
  - Caller name: "Rahul Sharma" (bold, 20px, with blue verification badge if verified)
  - Number: "+91 98765 43210" (14px, gray, copy icon button)
  - Info grid (2x2):
    - Carrier: "Jio Mobile" (with signal icon)
    - Location: "Mumbai, Maharashtra" (with map pin icon)
    - Line Type: "Mobile" (with phone icon)
    - Country: "India" (with flag icon)
  - Spam Analysis Section:
    - Spam Score bar (horizontal progress bar, red gradient, score "87/100")
    - Category badges: ["Telemarketer" (red), "Loan" (orange), "Reported 23 times"]
    - Community verdict: "87% of users marked as spam"
  - Action Buttons Row (full width, 4 buttons):
    - Block (red shield icon), Report Spam (orange flag icon), AI Handle (blue robot icon), WhatsApp Divert (green chat icon)
- **Search Loading State:** Skeleton loading animation (shimmer effect) on results card area

**Operations Performed:**
1. User enters phone number (auto-formatted by libphonenumber)
2. User taps search -> calls `GET /api/v1/lookup?phone_number=...`
3. Backend executes waterfall lookup: Redis -> Country Registry -> Telnyx + TrestleIQ -> Apify
4. Results rendered with all caller identity, carrier, location, spam data
5. User taps action buttons:
   - Block -> `POST /api/v1/blocklist`
   - Report -> `POST /api/v1/spam/report`
   - AI Handle -> enables AI agent for this number (future calls auto-handled)
   - WhatsApp -> `POST /api/v1/whatsapp/divert`

**API Calls:** `GET /api/v1/lookup`, `POST /api/v1/blocklist`, `POST /api/v1/spam/report`, `POST /api/v1/whatsapp/divert`

**API Keys Used:** `REDIS_URL`, `TELNYX_API_KEY`, `TRESTLEIQ_API_KEY`, `APIFY_API_TOKEN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`

**Sample Inputs:** User types `9876543210`, taps search

**Navigation:** From Dashboard (search bar tap) -> Call Log (from action buttons)

---

### 7.11 Screen 11: AI Agent Configuration Screen

**Screen File:** `ai_agent_screen.dart`

**UI Layout Description:**
- **Top Bar:** "AI Agent" title, edit icon (right)
- **Agent Identity Card:**
  - Large avatar (80px, AI robot illustration with user's chosen color)
  - Agent name: "Max" (22px, bold, editable on tap)
  - Status badge: "Active - Spam Handling ON" (green) or "Standby" (gray)
- **Voice Preview Section:**
  - Current voice: "Rachel - Female, Warm" with Play button
   - "Change Voice" button -> opens voice carousel (same as setup screen)
- **Personality Selector:** Three cards (Professional/Friendly/Concise), selected one highlighted
- **Call Handling Toggles Section:**
  - **Spam Handling:** Toggle ON/OFF with description "AI attends spam calls and extracts details"
  - **Busy Mode:** Toggle ON/OFF with time scheduler (start time - end time, days of week selector)
    - When ON: shows schedule card "Active: 9:00 AM - 6:00 PM, Mon-Fri"
  - **WhatsApp Diversion:** Toggle ON/OFF with description "Divert calls to WhatsApp when busy"
- **Greeting Template Editor:**
  - Editable text area with preview: "Hello, I'm {{agent_name}}. {{user_name}} is currently busy. How can I help?"
  - "Preview" button -> plays greeting via TTS
  - Character count: "45/200 characters"
- **Premium Upsell Banner** (free users only):
  - "Unlock Unlimited AI Calls" card with crown icon
   - "You've used 8/10 free AI calls this month"
  - "Upgrade to Premium" button (gold)
- **Recent AI Activity Feed:**
  - List of last 5 AI-handled calls with transcript previews
   - Each item: caller number, type badge (Spam/Busy), duration, summary line
  - "View All" link -> navigates to AI Call History Screen

**Operations Performed:**
1. Loads AI agent config from Supabase
2. User toggles features -> calls `POST /api/v1/ai/agent/config`
3. User changes voice -> previews via `POST /api/v1/ai/call/speak-text` -> saves config
4. User edits greeting -> live preview via TTS
5. User sets busy schedule -> saves to config
6. Free user taps upgrade -> navigates to Premium Screen

**API Calls:** `GET /api/v1/ai/agent/config`, `POST /api/v1/ai/agent/config`, `POST /api/v1/ai/call/speak-text`

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_TTS_API_KEY`

**Sample Inputs:** User toggles Busy Mode ON, sets 9:00 AM - 6:00 PM, Mon-Fri, taps Save

**Navigation:** From Dashboard (AI Agent tab) -> AI Call History (from activity feed)

---

### 7.12 Screen 12: AI Call History & Transcript Screen

**Screen File:** `ai_call_history_screen.dart`

**UI Layout Description:**
- **Top Bar:** "AI Call History" title, filter icon (right: All/Spam/Busy)
- **Search Bar:** Filter by keyword, caller number, or entity type
- **Stats Bar:** "47 calls handled | 12 spam extracted | 35 busy mode"
- **Transcript List:** Chronological, each entry expandable
  - **Collapsed View:**
    - Caller: "+91 98765 43210" (with name if identified)
    - Type badge: ["SPAM" red] or ["BUSY" blue]
    - Agent badge: "Max" (small blue pill)
    - Duration: "2m 34s"
    - Timestamp: "Today, 10:30 AM"
    - Summary: "Loan offer: $5000 at 12% interest from XYZ Finance"
  - **Expanded View (tap to expand):**
    - Full conversation transcript with speaker labels:
      - **AI Max:** "Hello, this is Max speaking on behalf of Rahul. How can I help you today?"
      - **Caller:** "Hi, I'm calling from XYZ Finance. We're offering a personal loan at 12% interest rate."
      - **AI Max:** "That sounds interesting. Could you tell me more about the loan amount and tenure?"
      - **Caller:** "Sure, we offer loans from $1000 to $5000 with tenure up to 36 months."
    - Extracted Entities (highlighted in blue with tag):
      - Company: "XYZ Finance"
      - Loan Amount: "$5000"
      - Interest Rate: "12%"
      - Tenure: "36 months"
    - Action buttons: Call Back, Block Number, Report Spam, Share Transcript
- **Empty State:** "Your AI agent hasn't handled any calls yet. Enable spam handling or busy mode to get started."

**Operations Performed:**
1. Loads AI call history from Supabase `ai_call_transcripts` table (paginated, 20 per page)
2. Full-text search via Meilisearch (`MEILISEARCH_API_KEY`)
3. User taps entry -> expands to show full transcript + entities
4. User taps Call Back -> opens native dialer with the number
5. User taps Block -> `POST /api/v1/blocklist`
6. User taps Share -> shares transcript as text via system share sheet

**API Calls:** `GET /api/v1/ai/call/history`, `GET /api/v1/ai/call/transcript/{call_id}`

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MEILISEARCH_API_KEY`

**Navigation:** From AI Agent Screen (activity feed) -> Call Log (action buttons)

---

### 7.13 Screen 13: Spam Center Screen

**Screen File:** `spam_center_screen.dart`

**UI Layout Description:**
- **Top Bar:** "Spam Center" title
- **Protection Summary Card:**
  - Large circular progress indicator: "94%" (detection accuracy, green gradient)
  - Stats row: "89 Blocked" | "5 Reported" | "127 Community Reports"
  - "Your phone is 94% protected from spam calls"
- **Top Spam Categories:** Horizontal scrollable category chips:
  - ["Telemarketer" (red, count: 34)] ["Loan" (orange, count: 21)] ["Fraud" (dark red, count: 18)]
  - ["Trading" (yellow, count: 12)] ["Scam" (purple, count: 8)] ["Shopping" (blue, count: 6)]
  - Tapping a category filters the reports list below
- **Recent Spam Reports:**
  - List of spam reports with: number, category badge, report timestamp, report status ("Confirmed" green / "Pending Review" yellow / "Disputed" gray)
  - Each item tappable to expand: shows full report details, comment, community agreement percentage
- **Floating Action Button (FAB):** "+" icon, bottom-right, red accent
  - Taps opens bottom sheet: "Report a Number"
    - Phone number input (with contacts picker button)
    - Category dropdown: Telemarketer, Fraud, Robocall, Scam, Loan, Trading, Shopping, Political, Survey, Other
    - Comment text area (optional): "Describe the spam call..."
    - "Submit Report" button

**Operations Performed:**
1. Fetches spam stats from `GET /api/v1/spam/stats`
2. Fetches recent reports from Supabase `spam_reports` table
3. User taps FAB -> opens report form
4. User submits report -> `POST /api/v1/spam/report`
5. Spam score updated in Redis cache and Supabase

**API Calls:** `GET /api/v1/spam/stats`, `POST /api/v1/spam/report`, `GET /api/v1/spam/search`

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REDIS_URL`

**Navigation:** From Dashboard (Spam tab) -> Call Log (from report item)

---

### 7.14 Screen 14: WhatsApp Bridge Screen

**Screen File:** `whatsapp_screen.dart`

**UI Layout Description:**
- **Top Bar:** "WhatsApp Bridge" title, connection status indicator (green dot = connected, red dot = disconnected)
- **Connection Status Card:**
  - WhatsApp Business API status: "Connected" (green) or "Disconnected" (red)
  - Phone number: "+91 98765 43210" (linked WhatsApp number)
  - Daily message limit: "423/500 messages remaining today"
  - "Test Connection" button
- **Active Diversions List:**
  - "Contacts with WhatsApp Diversion" heading
  - List of contacts with diversion enabled:
    - Each item: contact avatar, name, phone number, toggle switch (ON/OFF)
    - Toggling OFF -> confirmation dialog "Disable WhatsApp diversion for [name]?"
  - "+ Add Contact" button -> opens contact picker
- **Diversion History:**
  - "Recent Diversions" heading
  - List of diverted calls:
    - Caller name/number, diversion timestamp, auto-reply status ("Sent" green / "Failed" red)
    - Original call type: "Missed Call" or "Rejected Call"
- **Auto-Reply Templates:**
  - Default: "Hi, I'm currently unavailable. Please message me on WhatsApp."
  - Custom template editor (expandable section):
    - Text area with placeholder variables: `{{user_name}}`, `{{time}}`
    - "Save Template" button

**Operations Performed:**
1. Checks WhatsApp Business API connection via `GET /api/v1/whatsapp/status`
2. Loads active diversions from Supabase `diversion_logs` table
3. User adds contact -> selects from device contacts -> enables diversion
4. User toggles diversion -> calls `POST /api/v1/whatsapp/divert` (enable) or DELETE (disable)
5. When call diverted: backend sends WhatsApp message via `POST /api/v1/whatsapp/send-message`

**API Calls:** `GET /api/v1/whatsapp/status`, `POST /api/v1/whatsapp/divert`, `POST /api/v1/whatsapp/send-message`, `GET /api/v1/whatsapp/history`

**API Keys Used:** `WHATSAPP_BUSINESS_ACCOUNT_ID`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`

**Navigation:** From Dashboard (settings) or Call Log (swipe action)

---

### 7.15 Screen 16: Profile & Account Screen

**Screen File:** `profile_screen.dart`

**UI Layout Description:**
- **Profile Header:** Large avatar (100px), display name ("Rahul Sharma", 22px bold), phone number ("+91 98765 43210", 14px, gray), "Edit Profile" button (outline style)
- **Account Section:**
  - Email: "rahul@gmail.com" (with edit icon)
  - Member Since: "August 1, 2026"
  - Account ID: "usr_abc123" (with copy icon)
- **Subscription Card:**
  - Current plan: "Free Plan" (gray badge) or "Premium" (gold badge with crown icon)
  - Usage: "AI Calls: 8/10 used" (progress bar, 80%)
  - "Upgrade to Premium" button (if free user)
- **Data & Privacy Section:**
  - "Your Data" card with data categories:
    - Contacts: "234 contacts collected" (with view/delete buttons)
    - MAID Data: "Device ID registered" (with view/delete buttons)
    - Spam Patterns: "89 patterns analyzed" (view only)
  - Each category expandable to show collected data details
  - "Download My Data" button (exports all user data as JSON)
  - "Delete My Account" button (red, at bottom, requires confirmation dialog with typed phone number verification)

**Operations Performed:**
1. Loads profile from `GET /api/v1/users/profile`
2. User edits profile -> `PUT /api/v1/users/profile`
3. User views collected data -> fetches from Supabase tables
4. User downloads data -> backend compiles all user data, returns as JSON file
5. User deletes account -> confirmation flow -> `DELETE /api/v1/users/profile` (soft delete, 30-day recovery)

**API Calls:** `GET /api/v1/users/profile`, `PUT /api/v1/users/profile`, `GET /api/v1/users/subscription`, `DELETE /api/v1/users/profile`

**API Keys Used:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_API_KEY`

**Navigation:** From Dashboard (avatar tap) -> Settings (link)

---

### 7.17 Screen 17: Premium Subscription Screen

**Screen File:** `premium_screen.dart`

**UI Layout Description:**
- **Top Bar:** Back arrow, "Go Premium" title
- **Hero Section:** Gradient card (gold/amber) with crown icon, "Unlock the Full Power of Caller AI", "No ads, unlimited AI calls, advanced protection"
- **Pricing Cards (horizontal scroll):**
  - **Monthly:** "$4.99/month" - "Billed monthly, cancel anytime"
  - **Yearly:** "$39.99/year" (recommended, with "SAVE 33%" badge) - "Billed annually"
  - **Lifetime:** "$99.99" - "One-time payment, forever access"
- **Feature Comparison Table:**
  | Feature | Free | Premium |
  |---------|------|---------|
  | AI Calls/Month | 10 | Unlimited |
  | Ads | Yes (dashboard only) | None |
  | Busy Mode | No | Yes |
  | WhatsApp Diversion | No | Yes |
  | Advanced Spam Protection | Basic | AI-Powered |
  | Voice Search | No | Yes |
  | Priority Support | No | Yes |
- **Testimonials:** Horizontal scroll cards with user quotes
- **CTA Button:** "Subscribe Now - $4.99/month" (full width, gold, prominent)
- **Bottom:** "Restore Purchases" link, Terms & Conditions link

**Operations Performed:**
1. Fetches current subscription status from RevenueCat
2. User selects plan -> RevenueCat handles in-app purchase (Apple/Google payment)
3. On successful purchase -> `POST /api/v1/users/subscription/webhook` (RevenueCat webhook updates Supabase)
4. AdMob banner hidden, AI call limit removed, busy mode unlocked

**API Calls:** `GET /api/v1/users/subscription`, webhook from RevenueCat

**API Keys Used:** `REVENUECAT_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`

**Navigation:** From AI Agent Screen (upgrade banner) or Profile Screen (upgrade button)

---

### 7.19 Screen 19: Call Overlay (Incoming Call UI)

**Screen File:** `call_overlay_screen.dart`

**UI Layout Description:**
- **Full-screen overlay** (transparent background, drawn over the native call screen via WindowManager on Android / CallKit on iOS)
- **Caller ID Section (top 40%):**
  - Large caller avatar or initial circle (100px)
  - Caller name: "Rahul Sharma" (28px, white, bold) or "Unknown Caller" (if unidentified)
  - Phone number: "+91 98765 43210" (14px, white, 70% opacity)
  - Verification badge: Blue checkmark if verified
  - Spam warning: "SPAM ALERT" in red banner if spam score > 70
- **AI Agent Status Section (middle 30%):**
  - If spam detected + AI handling enabled:
    - Animated AI robot icon with "Max is handling this call" text
    - Live waveform animation showing conversation is active
    - "Listening..." / "Responding..." status text alternating
  - If busy mode + AI enabled:
    - "Max is attending this call for you" text
    - "Taking message..." status
  - If WhatsApp diversion active for this contact:
    - Green WhatsApp icon with "Redirecting to WhatsApp..." text
- **Action Buttons (bottom 30%):**
  - **Answer** (green circle, phone icon) - answers call normally
  - **AI Handle** (blue circle, robot icon) - forces AI to handle (if not auto-triggered)
  - **WhatsApp** (green circle, chat icon) - diverts to WhatsApp
  - **Block & Report** (red circle, X icon) - blocks and reports as spam
  - **Dismiss** (gray circle, down arrow) - silences/dismisses the call

**Operations Performed:**
1. Native bridge detects incoming call, sends event to Flutter via MethodChannel
2. Flutter checks spam score (on-device TFLite model + cached Redis data)
3. If spam + AI enabled: automatically triggers `POST /api/v1/ai/call/handle` (call_type: "spam")
4. If not spam + busy mode + AI enabled: triggers `POST /api/v1/ai/call/handle` (call_type: "busy")
5. If WhatsApp diversion active: triggers WhatsApp message send
6. User can override with manual action buttons
7. Real-time status updates via WebSocket during AI handling

**API Calls:** `POST /api/v1/ai/call/handle`, `POST /api/v1/spam/report`, `POST /api/v1/blocklist`, `POST /api/v1/whatsapp/send-message`

**API Keys Used:** `TWILIO_AUTH_TOKEN`, `OPENAI_API_KEY`, `GOOGLE_TTS_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `REDIS_URL`, `WHATSAPP_BUSINESS_ACCOUNT_ID`, `WHATSAPP_ACCESS_TOKEN`

**Navigation:** Overlay appears on top of ANY screen when call comes in. After call ends, overlay dismisses and user returns to previous screen.

---

### 7.20 Screen 20: AI Voice Call Live Screen

**Screen File:** `ai_voice_call_screen.dart`

**UI Layout Description:**
- **Full-screen dark background** (same as call overlay but persistent during AI conversation)
- **Top:** Caller info (name/number), call duration timer ("02:34"), call type badge ("SPAM" red / "BUSY" blue)
- **Center:** Large AI agent avatar with animated mouth (lip-sync animation when speaking), pulsing ring animation when listening
- **Live Transcript Section (bottom half):**
  - Scrollable transcript view with speaker labels:
    - AI Max (blue text): "Hello, this is Max. How can I help you today?"
    - Caller (white text): "I'm calling about a loan offer..."
    - Entity highlights: Loan amounts, company names, interest rates shown in blue with underline
  - Auto-scrolls to latest message
  - "Extracting details..." indicator when NLP is processing
- **Bottom Action Bar:**
  - "Take Over" button (green) - disconnects AI and connects user to the call
  - "End AI Call" button (red) - terminates the AI conversation
  - Mute toggle (microphone icon)
- **Side Panel (swipe from right):**
  - Real-time extracted entities list (updates as conversation progresses)
  - Confidence score for each extraction
  - Call quality indicator (signal strength, latency)

**Operations Performed:**
1. WebSocket connection established with backend for real-time audio
2. Audio streamed: caller -> Twilio -> WebSocket -> Whisper API (STT)
3. Transcribed text displayed in real-time in transcript view
4. NLP extracts entities, displayed in side panel
5. AI responses generated -> Google TTS -> streamed back to caller via Twilio
6. User can tap "Take Over" to join the call at any point
7. On call end: full transcript + entities saved to Supabase

**API Calls:** WebSocket connection (via Twilio), real-time Whisper (OPENAI_API_KEY), real-time TTS (GOOGLE_TTS_API_KEY), transcript save (SUPABASE)

**API Keys Used:** `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `OPENAI_API_KEY`, `GOOGLE_TTS_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`

**Navigation:** From Call Overlay (when AI is actively handling a call). After call ends, returns to previous screen with notification.

---

## 8. Database Schema (Supabase)

### 8.1 Supabase Project Configuration

| Setting | Value |
|---------|-------|
| Project Name | caller-ai-production |
| Region | ap-south-1 (Mumbai, India) |
| PostgreSQL Version | 16.x |
| Connection Pooling | Supavisor (transaction mode) |
| Row Level Security (RLS) | Enabled on all tables |
| Realtime | Enabled for call_logs, ai_call_transcripts |
| Backup | Daily automated backups, 7-day retention |

### 8.2 Supabase Auth Configuration

- **Auth Provider:** Phone (OTP via Twilio)
- **JWT Expiry:** 1800 seconds (30 minutes) for access token, 7776000 seconds (90 days) for refresh token
- **Auto-confirm:** Disabled (requires OTP verification)
- **Security:** RLS policies enforce users can only access their own data (using `auth.uid() = user_id`)

### 8.3 Database Tables

#### profiles
```sql
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_number TEXT NOT NULL UNIQUE,
  display_name TEXT,
  email TEXT,
  avatar_url TEXT,
  plan TEXT DEFAULT 'free' CHECK (plan IN ('free', 'premium')),
  onboarding_complete BOOLEAN DEFAULT false,
  ai_calls_used INT DEFAULT 0,
  ai_calls_limit INT DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
-- RLS Policy: Users can only read/update their own profile
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
```

#### otp_sessions
```sql
CREATE TABLE public.otp_sessions (
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
-- Auto-cleanup: Delete expired sessions after 24 hours
```

#### ai_agent_configs
```sql
CREATE TABLE public.ai_agent_configs (
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
```

#### call_logs
```sql
CREATE TABLE public.call_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone_number TEXT NOT NULL,
  caller_name TEXT,
  call_type TEXT NOT NULL CHECK (call_type IN ('incoming', 'outgoing', 'missed', 'ai_handled_spam', 'ai_handled_busy', 'whatsapp_diverted', 'blocked')),
  call_duration INT DEFAULT 0,
  spam_score INT,
  spam_category TEXT,
  ai_agent_name TEXT,
  transcript_summary TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_call_logs_user_created ON call_logs(user_id, created_at DESC);
ALTER TABLE public.call_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own call logs" ON public.call_logs FOR SELECT USING (auth.uid() = user_id);
```

#### ai_call_transcripts
```sql
CREATE TABLE public.ai_call_transcripts (
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
CREATE INDEX idx_transcripts_user_created ON ai_call_transcripts(user_id, created_at DESC);
ALTER TABLE public.ai_call_transcripts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own transcripts" ON public.ai_call_transcripts FOR SELECT USING (auth.uid() = user_id);
```

#### spam_reports
```sql
CREATE TABLE public.spam_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reported_number TEXT NOT NULL,
  category TEXT NOT NULL,
  comment TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'disputed')),
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_spam_reports_number ON spam_reports(reported_number);
```

#### blocked_numbers
```sql
CREATE TABLE public.blocked_numbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_number TEXT NOT NULL,
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, blocked_number)
);
```

#### whatsapp_diversions
```sql
CREATE TABLE public.whatsapp_diversions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_number TEXT NOT NULL,
  contact_name TEXT,
  auto_reply_template TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### device_tokens
```sql
CREATE TABLE public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_uuid TEXT NOT NULL,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  last_active_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, device_uuid)
);
```

#### collected_contacts
```sql
CREATE TABLE public.collected_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contact_name TEXT,
  contact_number TEXT NOT NULL,
  contact_email TEXT,
  source TEXT DEFAULT 'device',
  consent_given BOOLEAN DEFAULT true,
  collected_at TIMESTAMPTZ DEFAULT now()
);
```

#### maid_registry
```sql
CREATE TABLE public.maid_registry (
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
```

#### data_consent_records
```sql
CREATE TABLE public.data_consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL CHECK (consent_type IN ('contacts', 'maid', 'spam_patterns', 'analytics')),
  granted BOOLEAN NOT NULL,
  consent_version TEXT DEFAULT '1.0',
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### ad_impressions
```sql
CREATE TABLE public.ad_impressions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ad_unit_id TEXT NOT NULL,
  ad_network TEXT,
  impression_type TEXT CHECK (impression_type IN ('banner', 'interstitial')),
  clicked BOOLEAN DEFAULT false,
  screen_name TEXT DEFAULT 'dashboard',
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## 9. Backend Services

### 9.1 Service Architecture Overview

| Service | File | Purpose | External APIs Used |
|---------|------|---------|-------------------|
| Supabase Auth Service | `supabase_auth_service.py` | User registration, OTP verification, JWT management | Supabase Auth API |
| Aggregator Service | `aggregator.py` | Multi-tier waterfall caller ID lookup | Redis, Telnyx, TrestleIQ, Apify |
| Redis Cache Service | `redis_cache.py` | Read/write abstraction with TTL management | Redis |
| Key Rotator Service | `key_rotator.py` | API key pool management and rotation | None (manages keys) |
| Circuit Breaker Service | `circuit_breaker.py` | Per-provider fault tolerance (3 failures = open circuit) | None (monitors providers) |
| Spam Engine Service | `spam_engine.py` | Spam scoring, classification, pattern detection | Redis, Supabase |
| AI Voice Service | `ai_voice_service.py` | Whisper STT, NLP intent classification, TTS synthesis | OpenAI Whisper, Google TTS |
| AI Response Generator | `ai_response_generator.py` | Template-based + optional GPT response generation | OpenAI GPT (optional) |
| WhatsApp Bridge Service | `whatsapp_bridge_service.py` | WhatsApp diversion and messaging | WhatsApp Business API |
| Ad Service | `ad_service.py` | Ad impression tracking, targeting | Supabase, Mixpanel |
| Data Collection Service | `data_collection_service.py` | Contact & MAID collection pipeline | Supabase |
| Subscription Service | `subscription_service.py` | Premium tier management | RevenueCat, Supabase |

---

## 10. AI Voice Processing Pipeline

### 10.1 Pipeline Stages

```
Incoming Call -> Twilio -> WebSocket -> Audio Buffer (2s segments)
  -> OpenAI Whisper (STT) -> Text Segment
  -> spaCy NLP (Intent Classification + Entity Extraction)
  -> AI Response Generator (Template/GPT)
  -> Google Cloud TTS -> Audio Response
  -> Twilio WebSocket -> Caller hears response
  -> Full Transcript + Entities -> Supabase + Push Notification to User
```

### 10.2 Intent Categories

| Intent | Triggers | Entity Types Extracted |
|--------|----------|----------------------|
| Loan Offer | "loan", "emi", "interest", "principal" | loan_amount, interest_rate, tenure, company_name, processing_fee |
| Trading Promotion | "trading", "stock", "returns", "portfolio" | stock_name, expected_returns, risk_level, company_name |
| Shopping Deal | "offer", "discount", "sale", "price" | product_name, discount_percentage, original_price, website |
| Insurance | "insurance", "premium", "coverage", "claim" | insurance_type, premium_amount, coverage_amount, company_name |
| Survey/Research | "survey", "question", "research", "opinion" | survey_topic, organization, duration_minutes |
| Fraud/Scam | "urgent", "verify", "account", "suspicious" | scam_type, urgency_level, requested_action |
| General Inquiry | (default fallback) | topic, caller_sentiment |

---

## 11. Data Collection & Privacy Framework

### 11.1 Data Collection Categories

| Category | Data Collected | Purpose | Consent Required | Storage |
|----------|---------------|---------|-----------------|---------|
| User Account | Phone, name, email, avatar | Account management | Yes (implicit on registration) | Supabase `profiles` |
| Device Tokens | FCM token, device UUID, platform | Push notifications | Yes (on permission grant) | Supabase `device_tokens` |
| Saved Contacts | Name, phone, email | WhatsApp diversion, caller enrichment | Yes (explicit opt-in) | Supabase `collected_contacts` |
| MAID Data | Advertising ID, device model, OS, age, gender | Analytics, ad targeting | Yes (explicit opt-in) | Supabase `maid_registry` |
| Spam Patterns | Reported numbers, categories, call times | Spam detection improvement | Yes (implicit on report) | Supabase `spam_reports` + Redis |
| AI Call Transcripts | Full conversation text, entities, audio | Call history, user reference | Yes (implicit on feature use) | Supabase `ai_call_transcripts` |
| Ad Interactions | Impressions, clicks, screen context | Ad revenue optimization | Yes (implicit on app use) | Supabase `ad_impressions` |
| App Analytics | Screen views, feature usage, funnels | Product improvement | Yes (implicit on app use) | Mixpanel (anonymized) |

### 11.2 Compliance
- **GDPR:** Right to access, rectify, erase, port data. Consent records maintained.
- **CCPA:** Do Not Sell flag honored. Data deletion within 45 days of request.
- **India DPDP Act:** Consent notices in local language. Data minimization principle.
- **All consent records** stored with timestamp, IP, user agent, and consent version in `data_consent_records` table.

---

## 12. Revenue Model

### 12.1 Revenue Streams

| Stream | Mechanism | Estimated Revenue | Notes |
|--------|-----------|-------------------|-------|
| AdMob (Banner) | Banner ads on dashboard only | $0.50-2.00 eCPM | Free tier only, ~500 DAU target |
| Premium Monthly | $4.99/month subscription | $4.99/user/month | Unlimited AI, no ads, busy mode |
| Premium Yearly | $39.99/year subscription | $39.99/user/year | 33% discount, higher retention |
| Premium Lifetime | $99.99 one-time | $99.99/user | Low volume, high margin |

### 12.2 Monthly Cost Estimates

| Service | Usage | Monthly Cost |
|---------|-------|-------------|
| Supabase (Pro) | 8GB DB, 50GB storage | $25 |
| Redis (2-node) | 4GB each | $15 |
| Twilio (Phone + Verify) | 1 number, ~5000 OTPs | $30 |
| OpenAI Whisper | ~2000 min/month AI calls | $12 |
| Google Cloud TTS | ~500K characters/month | $2 |
| WhatsApp Business API | ~1000 conversations | $30-80 |
| Telnyx + TrestleIQ | ~50K lookups | $200-400 |
| Apify | ~5K OSINT scrapes | $15 |
| Firebase | Push notifications | Free (under 1M) |
| Meilisearch | 50MB index | Free |
| Mixpanel | 100K events | Free |
| RevenueCat | Subscription management | Free + 1% |
| Hosting (AWS/GCP) | 2 instances + DB | $50-100 |
| **Total** | | **$379-679/month** |

---

## 13. Deployment Pipeline

### 13.1 Architecture

```
GitHub Push -> GitHub Actions -> Docker Build -> AWS ECR -> ECS Fargate (Blue/Green Deploy)
                                                                    |
                                                          Supabase (Managed PostgreSQL + Auth + Storage + Realtime)
                                                                    |
                                                          Redis Cluster (ElastiCache)
                                                                    |
                                                          Twilio (Voice + Verify)
                                                                    |
                                                          S3 (Audio file temporary storage)
```

### 13.2 Environments

| Environment | URL | Supabase Project | Purpose |
|-------------|-----|-----------------|---------|
| Development | `dev-api.callerai.app` | `caller-ai-dev` | Local development + testing |
| Staging | `staging-api.callerai.app` | `caller-ai-staging` | QA, integration testing, UAT |
| Production | `api.callerai.app` | `caller-ai-production` | Live users |

---

## 14. Monitoring & Observability

### 14.1 Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| Metrics | Prometheus + Grafana | API latency, error rates, API key usage, spam detection accuracy |
| Logging | Structured JSON (structlog) | Centralized logs to CloudWatch |
| Tracing | OpenTelemetry | Distributed tracing across services |
| Alerting | Grafana Alerting + PagerDuty | SLO violations, error spike, API key exhaustion |
| Uptime | BetterUptime | Endpoint monitoring, 1-minute interval |

### 14.2 Key SLOs

| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| API Response Time (p99) | < 500ms | > 1000ms for 5 min |
| Caller ID Lookup Latency | < 1500ms | > 3000ms for 5 min |
| AI Call Handling Success Rate | > 95% | < 90% for 10 min |
| OTP Delivery Rate | > 99% | < 95% for 5 min |
| Uptime | > 99.9% | < 99.5% for 5 min |

---

## 15. Error Handling Strategy

### 15.1 Error Categories

| Category | Examples | Handling Strategy |
|----------|----------|-----------------|
| Upstream Provider Failure | Twilio, Telnyx, OpenAI timeout | Circuit breaker (3 failures = 30s open), auto-failover to next provider |
| Authentication Error | Expired JWT, invalid OTP | Transparent token refresh, user-friendly error with re-auth option |
| Rate Limit Exceeded | Twilio Verify, OpenAI API limits | Exponential backoff, queue for retry, notify user of delay |
| Network Error | No connectivity, DNS failure | Local cache fallback, retry with jitter, offline mode |
| Validation Error | Invalid phone number, malformed request | Pydantic validation with field-level error messages |
| Database Error | Supabase connection failure, RLS violation | Connection pool retry, fallback to local Isar database |
