# ResidentHub (residenthub_dashboard)

Flutter app (web and Android) for **City Residences Condominium Corporation**. It is a real
system: it starts empty, the administrator enters all details and creates every resident account,
and everything is stored in a Supabase database shared by all devices.

## Demo (sample data, no database)

`flutter build web --dart-define=DEMO=true` builds a **demo** of the app: it never connects to Supabase and starts with made-up
people, units, dues, bookings and announcements (`lib/services/demo.dart`, dates built around today). The sign-in screen shows
"Try as Administrator" and "Try as Resident"; anything changed stays in memory and is gone when the page closes. Password,
account and text-message features are switched off. The GitHub Action publishes the demo next to the real app at
`/Residenthub/demo/` (the website's `demo/` folder links to it).

## Open in Android Studio
1. Create a project: *File > New > New Flutter Project*, name it `residenthub_dashboard`
   (org e.g. `ph.residenthub`). Or, in this folder, run:
   `flutter create --project-name residenthub_dashboard --org ph.residenthub .`
2. Copy `lib/`, `assets/`, `test/`, `pubspec.yaml` and `analysis_options.yaml` from this
   folder over the generated project (overwrite).
3. `flutter pub get`, pick an emulator or device, press Run.
Requires Flutter 3.22+ (Dart 3.3+). Two packages are used for documents: `file_picker`
(import files, save exports) and `archive` (reads/writes .docx and .xlsx). Run `flutter pub get`
after copying `pubspec.yaml`.

## Sign-in accounts and data
- There are no sample accounts and no sample data. Sign-in uses Supabase Authentication (email + password;
  5 wrong tries lock sign-in for a minute).
- The first administrator is created by the owner in the Supabase dashboard (Authentication > Users, Auto Confirm),
  then set to admin with SQL: `update public.profiles set role='admin', name='...' where email='...';`
- The administrator creates resident accounts in Manage access. The app shows a temporary password once; the
  resident must choose a new password at first sign-in. The administrator can reset a password, suspend or delete
  a resident account. This runs through the Edge Function `supabase/functions/manage-users` (it uses the
  service role key on the server only; never put that key or the database password in the app).
- Forgot password: the person enters their email, gets one 6-digit code by email and one by text message (Edge Function `supabase/functions/reset-password`, deployed with Verify JWT off because nobody is signed in), and chooses a new password with both codes. The reply never says whether an email has an account. Only a verified, active account can do this; otherwise the administrator resets the password in Manage access.
- Data is stored in the table `public.records` (kind, id, unit, value) and `public.profiles`. Row-level security
  keeps residents to their own unit's rows (and the public ones: announcements, events, polls, slots...).
  Changes sync in real time between devices. The public URL and anon key are in `lib/services/supabase_config.dart`.
- Turn off "Allow new users to sign up" in Supabase (Authentication > Sign In / Providers) so only the
  administrator can create accounts.

## Password rules
A new password must have at least 8 characters, an uppercase letter, a lowercase letter, a number and a symbol. The screens (first password, change password, forgot password) show a live checklist with a check mark for each rule that is followed (`lib/core/password_rules.dart`, `lib/widgets/password_rules.dart`); the Edge Function `reset-password` checks the same rules, and the temporary passwords made by `manage-users` follow them. For the same rules on every path, also set the password requirements in Supabase (Authentication > Sign In / Providers > Email) to a minimum length of 8 with lowercase, uppercase, digits and symbols.

## Verifying a new account (email code + text message code)
A resident created by the administrator must, at first sign-in, choose a new password and then confirm the
email address and the mobile number with two 6-digit codes. Until both are right the database shows the
resident nothing (`my_unit()` returns an empty unit while `profiles.contact_verified_at` is null).
Codes expire after 10 minutes, allow 5 tries, a new set can be requested every 60 seconds (5 per hour) and are
stored only as hashes. The administrator is not asked for codes. If the administrator changes a resident's
mobile number, that resident has to verify again.

The Edge Functions `supabase/functions/verify-contact` (new accounts) and `reset-password` (forgot password) send the codes. Set these in the Supabase dashboard under
Edge Functions > Secrets (never in the app, the website or this repository):
- Email (SMTP, port 465): `SMTP_HOST`, `SMTP_PORT` (465), `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`
  (for Gmail: host `smtp.gmail.com`, an App Password as the password).
- Text message, one of:
  - Twilio: `SMS_PROVIDER=twilio`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN` and `TWILIO_FROM` (or `TWILIO_MESSAGING_SERVICE_SID`)
  - Semaphore (Philippines): `SMS_PROVIDER=semaphore`, `SEMAPHORE_API_KEY`, optional `SEMAPHORE_SENDER`

## Project structure (one file per screen)
```
lib/
  main.dart                      app entry, theme + login/role switching
  core/
    app_state.dart               models and shared AppState
    cloud_codec.dart             record <-> model conversion for the database
    ../services/session.dart     sign-in, accounts (Supabase Auth + manage-users)
    ../services/cloud_sync.dart  generic sync of records, realtime refresh
    theme.dart                   pastel palette + Material 3 theme (light/dark)
    doc_model.dart               document model (blocks: headings, text, bullets, tables)
    doc_seed.dart                the documents that ship with the app (edit the wording here)
  services/doc_files.dart        Word/Excel export, Word/Excel/CSV/text import, save dialog
  widgets/                       reusable UI: floating_nav, ring_gauge, line_chart,
                                 pastel cards/tiles, page scaffolds, form_sheet, ...
  screens/
    shared/calendar_screen.dart  month calendar (events, bookings, dues dates) + home card
    shared/document_viewer_screen.dart  opens a document, download as Word / Excel
    auth/login_screen.dart
    resident/
      resident_shell.dart        floating bottom navigation (Home, Book, Dues, More)
      home_screen.dart  book_screen.dart  dues_screen.dart
      more_screen.dart  reservations_screen.dart  grievances_screen.dart
      documents_screen.dart  finance_docs_screen.dart  unit_status_screen.dart  settings_screen.dart
      notifications_sheet.dart   resident_screens.dart (barrel)
    admin/
      admin_shell.dart           floating bottom navigation (Home, Units, Facility, Finance, More)
      home_screen.dart  units_screen.dart  facility_screen.dart  finance_screen.dart
      more_screen.dart  announcements_screen.dart
      grievances_screen.dart  unit_status_screen.dart  documents_screen.dart  finance_docs_screen.dart
      access_screen.dart
      admin_actions.dart         jump targets, attention sheet, search items
      admin_screens.dart (barrel)
```
Each bottom-navigation tab and each "More" page lives in its own file.

## Notes
- Visitor management and vendor management have been removed from this build (both resident and admin sides).
- Everything is saved in the Supabase database; nothing is sample data.
- Resident and admin share one state: a booking, grievance, unit status update or
  parking request made as a resident shows up for the admin, and decisions flow back.
- The earnings line chart, "Recent activity", "Upcoming facility bookings" and the resident notifications are built from what is recorded in the app (payments, bookings, grievances, announcements). They start empty and fill in as people use the app.
- Documents: every document opens in the app and can be downloaded as Word (.docx) or Excel (.xlsx).
  Categories: Policy, Finance, Form, Notice, Minutes, Other. Finance includes the dues schedule, the
  annual budget, a live collection report (admin) and a live statement of account (resident).
  The administrator can import .docx, .xlsx, .csv, .txt/.md or .pdf files (Documents > Import file);
  Word/Excel/CSV/text files are readable in the app, PDFs can be downloaded back. In Finance the
  administrator can export the dues report and import an Excel/CSV list of paid units to record payments.
  The wording of the built-in documents is a template: edit it in `lib/core/doc_seed.dart`. Imported documents are stored in the database (max 2 MB each).
- Finance documents are kept apart from the community documents: More > Finance documents (admin and
  resident). They hold the dues schedule, budget, collection report, payment history, statement of account
  and every receipt. Community documents (rules, forms, notices, minutes) no longer list finance files.
  Files the administrator imports under Finance documents are admin-only unless shared with residents.
- Announcements: with "Also text residents" on, the phone's messaging app opens with all resident mobile
  numbers (from Manage access) and the announcement typed in; the administrator taps Send. No SMS provider is needed.
- Finance > Charge adds a real one-off charge to a unit (it appears under the unit's dues and the resident's
  Dues & payment). The admin Home figures (units, residents, documents, bookings, earnings) come from the app data.
- Payments: residents see "How to pay" (office, bank transfer, GCash, Maya) under Dues & payment, send the
  reference number of their payment, and get a receipt once the administrator confirms it. Every receipt
  opens in the app and downloads as Word or Excel, and the payment history can be exported too. The
  administrator edits the account details (Finance > Payment options), checks proofs and records payments
  (Finance > Record payment). Only "Pay at the office" is on by default: the administrator adds the real bank/e-wallet details.
  There is no online payment gateway: money is paid outside the app and recorded here as proof.
- There is no online payment in this build; the resident sends proof of payment and the administrator confirms it.
- Expenses (administrator only): Finance > Expenses, or More > Expenses. Every purchase of the corporation is encoded:
  what was bought, quantity, price of one, store or supplier, official receipt no., the facility or area it is for,
  category and date. The screen has a month picker, the month's total, a "where the money went" breakdown and the list
  of purchases. The Monthly expense report (summary, all purchases, spending by category against the monthly budget,
  spending by facility, change from last month) can be viewed and exported to Word or Excel for any month, and the
  current month also appears under Finance documents (admin only), next to the year-to-date Expense Report.
  The list starts empty.
- Profile: the administrator edits name, email, mobile number, photo and password under More > Settings (tap the avatar on the home screen or the profile card). Residents edit the same under More > Settings, including a profile photo. The administrator can also sign in with the email saved in the profile. 
- The "Needs attention" cards on the administrator home are picture cards (ImageTile). The pictures are in assets/images (need_dues, need_bookings, need_units, need_grievances) and can be replaced with your own photos of the same name.

## Background photo

The City Residences building photo (`assets/images/building.png`) is the full-screen background of the login page. Inside the app it sits softly faded behind the dashboard tabs and sub-pages (`lib/widgets/backdrop.dart`). To make it clearer or fainter, change the two alpha numbers (`topVeil`, `midVeil`) in that file.

## Animations and layout

- `lib/widgets/motion.dart` holds the animations: page change (fade and slide), press effect on cards and buttons, numbers that count up, tabs that fade in when opened, a pulsing notification dot, and tiles that pop in one after another. The earnings chart draws itself from left to right.
- Home screens are grouped into titled sections with the same spacing (`DashSection` in `lib/widgets/common.dart`). Admin: quick actions, Overview, Needs attention, Finance, Calendar, Announcements, Upcoming facility bookings, Recent activity. Resident: quick actions, Overview, Quick access, My unit, Calendar, Announcements, Community events.
- The More tabs are grouped with small labels (`NavGroup`): Community / Money and files / Administration for the admin, My unit / Documents / Account for the resident.

