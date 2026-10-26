# Database (Supabase)

> In this GitHub repository the app is the repo root (`lib/`, `supabase/functions/`). `website/` means the repository mochiematchaaa/mochiematchaaa.github.io. The full package with all three parts is ResidentHub-System.zip.

**New to Supabase? Read `SETUP-STEP-BY-STEP.md` first** (clicks, in order). This file is the short reference.

ResidentHub uses **one Supabase project** for everything: sign-in (Supabase Auth), the data (PostgreSQL) and three Edge Functions. The website and the app talk to the same project, so they always show the same data.

## What is in this folder
- `schema.sql`: the tables, helper functions, triggers, row-level-security policies and realtime setting. **Schema only. No data, no passwords, no keys.**
- The Edge Functions are in `supabase/functions/` (`manage-users`, `verify-contact`, `reset-password`).

## Tables
| Table | What it holds |
|---|---|
| `profiles` | one row per sign-in account (name, email, phone, unit, role `admin` or `resident`, suspended, must change password, contact verified) |
| `records` | everything else, one row each: `kind` (unit, due, payment, proof, booking, grievance, announcement, event, poll, vote, rsvp, doc, slot, request, setting, expense, activity, statusUpdate), `id`, `unit` (owner: a unit, `''` for everyone, `__admin` for the administrator only) and `value` (JSON) |
| `verification_codes`, `reset_codes` | hashed one-time codes. Only the Edge Functions use them. |

Safety is enforced **in the database**, not only in the screens: a resident can read and write only their own unit's rows plus the public ones, and cannot confirm payments, decide bookings, change unit details or change their own role (`records_guard`, `profiles_guard` and the policies in `schema.sql`).

## Set up your own copy (new Supabase project)
1. Create a free project at https://supabase.com.
2. **SQL Editor**: paste and run `schema.sql`.
3. **Authentication → Sign In / Providers**: turn **off** "Allow new users to sign up" (only the administrator creates accounts). Optionally set the password rules to at least 8 characters with lower case, upper case, digits and symbols.
4. **Edge Functions**: deploy the three folders from `supabase/functions/` (`manage-users` and `verify-contact` with *Verify JWT* **on**, `reset-password` with *Verify JWT* **off**, because nobody is signed in when they forget a password).
5. **Edge Functions → Secrets** (set these yourself in the dashboard; never put them in the app, the website or any file):
   - Email codes: `SMTP_HOST`, `SMTP_PORT` (465), `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` (for Gmail: `smtp.gmail.com` and a Google *App Password*)
   - Text-message codes (optional, pick one): `SMS_PROVIDER=twilio` with `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM` (or `TWILIO_MESSAGING_SERVICE_SID`); or `SMS_PROVIDER=semaphore` with `SEMAPHORE_API_KEY` (+ optional `SEMAPHORE_SENDER`)
6. **First administrator**: *Authentication → Users → Add user* (tick *Auto Confirm User*), then in the SQL Editor:
   `update public.profiles set role = 'admin', name = 'Your Name' where email = 'you@example.com';`
   Every resident account after that is created by this administrator in the dashboards (Manage access).
7. **Connect the website and the app** to your project (Project Settings → API → Project URL and the `anon public` key):
   - website: `supabase-config.js` in the website repository
   - app: `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` or `lib/services/supabase_config.dart`

## Never share or commit
The `service_role` key, the database password, the SMTP password and the SMS keys. The `anon public` key is meant to be public (it is in the website's `supabase-config.js`); the row-level-security rules above are what protect the data.

## Notes
- The live project also has an old table `shared_records` from the first prototype. Nothing uses it any more and it is **not** in `schema.sql`; do not recreate it.
- Migrations that built the live project (for history): `profiles_and_auth_helpers`, `records_table_rls_guard`, `records_policies_v2`, `contact_verification`, `password_reset_codes`, `residents_may_save_usage_info`. `schema.sql` is their combined result.
