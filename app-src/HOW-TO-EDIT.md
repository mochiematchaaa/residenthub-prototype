# How to edit (the easy guide)

> In this GitHub repository the app is the repo root (`lib/`, `supabase/functions/`). `website/` means the repository mochiematchaaa/mochiematchaaa.github.io. The full package with all three parts is ResidentHub-System.zip.

The code now has a short comment above every function and a "what is this file" note at the top of every file.
Search for the PAGE: / ADMIN page: / RESIDENT page: words to find a screen quickly. Comments never change how the program runs.

## Website (JavaScript, `website/` or `web/`)
| I want to… | Go to |
|---|---|
| change colors | the `:root{ ... }` block at the top of `admin.css` and `resident.css` (e.g. `--yellow`, `--pink`, `--card`) |
| change the text/look of one admin page | `admin.js` (Home, Units, Facility, Announcements, Polls) or `admin-more.js` (Finance, Expenses, Reports, Parking, Log, Access, Settings). Find `function viewXxx()` |
| change a resident page | `resident.js`, `function viewXxx()` (viewHome, viewBook, viewDues, viewParkingPage...) |
| add a menu item | admin: `render()` in `admin.js` (the `navBtn(...)` lines) + `view()` + `titles()`. resident: same in `resident.js` |
| change the default facilities (pool, gym…) | `DEFAULT_AMENITIES` in `core.js` |
| change the password rules | `PW_RULES` in `core.js` |
| change how far ahead a resident can book | `BOOK_AHEAD_DAYS` in `core.js` |
| change the unit usage names | `USAGE_NAMES` in `core.js` |
| change the sign-in page | `renderLogin()` in `core.js` |
| save or delete something in the database | `put(kind, id, unit, value)` and `del(kind, id)` in `core.js` |
| the public website (home page) | `index.html`, `index.css`, `index.js` |
After editing a `.js` or `.css` file, raise the number in `?v=30` inside `admin.html` and `resident.html` so browsers load the new file.

## App (Flutter, `app/lib/`)
| I want to… | Go to |
|---|---|
| change colors | `lib/core/theme.dart` |
| change a page | `lib/screens/admin/…` or `lib/screens/resident/…` (file name = page name) |
| change what data exists or what an action does | `lib/core/app_state.dart` (all data and actions) |
| change how data is saved to the database | `lib/core/cloud_codec.dart` (rows) and `lib/services/cloud_sync.dart` |
| change sign-in, accounts, codes | `lib/services/session.dart` |
| add a menu tab | `lib/screens/admin/admin_shell.dart` or `lib/screens/resident/resident_shell.dart` |
| change booking days ahead | `_aheadDays` in `lib/screens/resident/book_screen.dart` |
| change password rules | `lib/core/password_rules.dart` |
| reusable pieces (cards, pills, forms) | `lib/widgets/` |
Run `flutter analyze` before you commit: it must show no errors.

## Database
Tables and rules are in `database/schema.sql`. The website and the app both use the table `records` (see `database/README.md`).
If you change what a resident may write, change `records_guard` in the schema as well, or the database will refuse it.

## Demo
`web/demo-backend.js` (sample data for the website) and `app/lib/services/demo.dart` (sample data for the app) hold the made-up data.
If you change one, change the other so both demos match.
