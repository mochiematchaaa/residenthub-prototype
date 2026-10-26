# Step by step: open the database in Supabase

> In this GitHub repository the app is the repo root (`lib/`, `supabase/functions/`). `website/` means the repository mochiematchaaa/mochiematchaaa.github.io. The full package with all three parts is ResidentHub-System.zip.

Menu names in Supabase can look a little different over time, but the order of the steps stays the same.
Choose **A** to look at the real project, or **B** to make your own copy for testing (recommended for classmates).

---
## A. Look at the real project (the owner must invite you)

**Owner (the person who created the project):**
1. Go to https://supabase.com and sign in.
2. Open your **Organization**, then **Team**.
3. Click **Invite**, type your classmate's email and choose a role: **Read-only** or **Developer** for viewing and helping. Do not give **Owner** unless you trust the person completely.
4. Click **Send invitation**.

**Classmate:**
1. Open the invitation email and click **Accept invitation**. Sign in (or create a free Supabase account with the same email).
2. Choose the project **iexsitqmmhokmffmmaed** (ResidentHub).
3. Left menu **Table Editor**: you can see the tables `profiles` and `records`.
4. Left menu **SQL Editor**: run queries. Left menu **Authentication**: the list of accounts.
5. Be careful: this is the real data. Editing or deleting here changes the live system.

---
## B. Make your own copy (safe for testing)

### Step 1. Create the project
1. Go to https://supabase.com and **Sign up** (free). Sign in.
2. Click **New project**. Choose an organization, type a **Name** (for example `residenthub-test`), type a **Database password** (write it down, you will not need it again for this guide), pick the nearest **Region** (for example Singapore).
3. Click **Create new project** and wait 1 to 3 minutes until it says the project is ready.

### Step 2. Create the tables (run schema.sql)
1. Left menu **SQL Editor**, then **New query**.
2. Open `database/schema.sql` from this zip with any text editor (Notepad, VS Code). Select all (Ctrl+A) and copy (Ctrl+C).
3. Paste it into the SQL Editor and click **Run**. It should say *Success. No rows returned.*
4. Check: left menu **Table Editor**. You should see `profiles`, `records`, `verification_codes`, `reset_codes`.
   If you see a red error, copy the message and send it to the team. Do not run the file twice if the first run stopped in the middle; ask first.

### Step 3. Turn off public sign-up
1. Left menu **Authentication**, then **Sign In / Providers** (older name: Settings).
2. Turn **off** *Allow new users to sign up*. Click **Save**.
   (Only the administrator creates resident accounts, from inside the dashboard.)

### Step 4. Create the first administrator
1. Left menu **Authentication**, then **Users**, then **Add user**, then **Create new user**.
2. Type an email and a password. Tick **Auto Confirm User**. Click **Create user**.
3. Left menu **SQL Editor**, **New query**, paste this (change the email and the name), then **Run**:
   ```sql
   update public.profiles set role = 'admin', name = 'Your Name' where email = 'you@example.com';
   ```
   It should say 1 row affected. If it says 0 rows, the email is spelled differently from the user you created.

### Step 5. Deploy the 3 Edge Functions
They send the email codes and create/reset accounts. The code is in `supabase/functions/`: `manage-users`, `verify-contact`, `reset-password`.
1. Left menu **Edge Functions**, then **Deploy a new function** (choose **Via Editor** if asked).
2. Name it exactly `manage-users`. Delete the sample code, open `supabase/functions/manage-users/index.ts`, copy everything, paste it, click **Deploy**.
3. Repeat for `verify-contact` and `reset-password`.
4. Open each function's **Settings** (or the details tab) and set **Verify JWT**:
   - `manage-users`: **ON**
   - `verify-contact`: **ON**
   - `reset-password`: **OFF** (people who forgot their password are not signed in)
   (If you prefer the command line, the Supabase CLI can do the same: `supabase functions deploy manage-users`, and so on.)

### Step 6. Set the secrets (only for the email/text codes)
Skip this step if you only want to look around; sign-in will work but the email codes will not be sent.
1. **Project Settings**, then **Edge Functions**, then **Secrets** (or **Edge Functions**, then **Secrets**).
2. Add these, one by one (**name** exactly as written, **value** is yours):
   - `SMTP_HOST` = `smtp.gmail.com`
   - `SMTP_PORT` = `465`
   - `SMTP_USER` = your Gmail address
   - `SMTP_PASS` = a Google **App Password** (Google Account, Security, 2-Step Verification, App passwords). Never your normal password.
   - `SMTP_FROM` = the name/email shown to residents
   - Optional, for text messages: `SMS_PROVIDER` = `twilio` plus `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM`; or `SMS_PROVIDER` = `semaphore` plus `SEMAPHORE_API_KEY`.
3. Nobody else, and no file in this zip, should ever contain these values.

### Step 7. Connect the website and the app to YOUR project
1. **Project Settings**, then **API** (or **API Keys**). Copy the **Project URL** and the **anon public** key.
   Never copy the `service_role` key into any file.
2. Website: open `supabase-config.js` (website repository) and replace the URL and the anon key.
3. App: open `lib/services/supabase_config.dart` and replace the URL and the anon key
   (or run it with `flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`).

### Step 8. Install the tools (once)
| Tool | For | Get it |
|---|---|---|
| **VS Code** (with the extension **Live Server**) or **Python 3** | running the website on your computer | https://code.visualstudio.com / https://www.python.org |
| **Google Chrome** | opening the website and the app | https://www.google.com/chrome |
| **Flutter SDK** (3.22 or newer) | running the app | https://docs.flutter.dev/get-started/install |
After installing Flutter, open a terminal (PowerShell on Windows, Terminal on Mac) and run `flutter doctor`. You only need the **Flutter** and **Chrome** lines to be green to run the app in Chrome. (Android Studio is only needed for a phone/emulator.)

### Step 9. Run the website with your database
1. Unzip `ResidentHub-System.zip` (or clone the two repositories: the app repository and the website repository).
2. Make sure Step 7 is done: `supabase-config.js` (website repository) contains **your** Project URL and anon key. If it still has the original URL, you are connected to the REAL project.
3. Start a small server in the website folder. Pick one:
   - **VS Code:** *File, Open Folder*, choose the website folder. Right-click `admin.html`, choose **Open with Live Server**.
   - **Terminal:** `cd` into the website folder, then `python3 -m http.server 8000` (on Windows: `py -m http.server 8000`). Open `http://localhost:8000/admin.html` in Chrome.
   (Double-clicking the HTML file does not work; it needs the small server.)
4. Sign in with the administrator email and password from Step 4. You should see the Dashboard (empty, because a new database has no data).
5. Add data to try it: **Units**, add a unit (for example `Unit 101`). Then **Manage access**, **Create resident account**: type a name, an email, and choose the Unit. Copy the temporary password that appears (it is shown only once).
6. Open a second window (Chrome Incognito) at `http://localhost:8000/resident.html` and sign in with that resident account. It asks for a new password, then for the email/mobile codes. If you skipped Step 6, the codes cannot be sent, so for testing use the Demo instead of the real resident flow.
7. Try: the resident books a facility; in the admin window, **Facility**, approve it. It updates live.

### Step 10. Run the app with your database
1. Open a terminal in the app folder (this repository)
2. Download the packages (once): `flutter pub get`
3. Run it in Chrome, with YOUR project (replace the two values with the ones from Step 7). Write it as one line:
   ```
   flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
   ```
   (If you already edited `lib/services/supabase_config.dart` in Step 7, plain `flutter run -d chrome` is enough.)
4. The first run takes a few minutes. Chrome opens the app. Sign in with the same administrator or resident accounts. The website and the app share ONE database, so what you add in one appears in the other.
5. To stop it, press `q` in the terminal.
6. Optional, an Android phone file (APK): `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`. The file is in `build/app/outputs/flutter-apk/app-release.apk`. This needs Android Studio / the Android SDK installed.

### Step 11. Check that everything is connected
1. In the app, as a resident, book a facility.
2. In the website admin window, open **Facility**. The same request must appear.
3. Approve it there. In the app, **My reservations** shows it as Approved.
4. In your Supabase dashboard, **Table Editor**, `records`: you can see the new rows (`kind` = `booking`, `unit`, `value`).
If all four work, the website, the app and the database are connected.

### Something wrong?
| Problem | Check |
|---|---|
| "Invalid login" for the admin | Step 4: was *Auto Confirm User* ticked and did the `update` say 1 row? |
| Admin sees an empty/blocked page | Step 4 `update` not applied (role is still `resident`) |
| Cannot create resident accounts | Step 5: `manage-users` deployed with *Verify JWT* ON? |
| Codes are never received | Step 6 secrets, and `verify-contact` deployed? |
| "Forgot password" fails | `reset-password` deployed with *Verify JWT* OFF? |
| Data does not appear after login | Step 7: URL and anon key belong to the same project? |
| Website shows a blank page or says it cannot connect | You opened the file by double-click. Use Step 9 (local server). Press F12, then Console, to read the error. |
| `flutter` is not recognized | Flutter is not installed or not in PATH; redo Step 8, then close and reopen the terminal. |
| The app opens but cannot sign in | The two `--dart-define` values are missing or from another project (Step 7). |
| I see the real project's data | `supabase-config.js` / `supabase_config.dart` still have the original URL. Replace them (Step 7). |
