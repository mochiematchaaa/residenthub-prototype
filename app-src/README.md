# ResidentHub: Facility Management System for City Residences Condominium (app prototype)

Flutter app (web and Android) for **City Residences Condominium Corporation**, capstone project of Team LockedIn.

This folder is the **front-end prototype** of the app. It shows every screen and flow of the system, but it
**does not use a database**. People, units, dues, bookings, grievances, announcements and maintenance tasks are
sample data kept in memory (`lib/services/demo.dart`). Nothing is saved, and everything resets when the page is closed.

## Run the prototype

Requirements: Flutter 3.22 or newer (Dart 3.3+). On Windows, turn on Developer Mode
(Settings > System > Advanced or For developers), then open a new terminal.

1. Double-click `RUN-PROTOTYPE.bat`, or run this in the folder that has `pubspec.yaml`:

   ```
   flutter clean
   flutter pub get
   flutter run -d chrome --dart-define=PROTOTYPE=true
   ```

2. On the sign-in screen, choose **Continue as Administrator** or **Continue as Resident (Maria, Unit 3B)**.
   You can also type an email or a mobile number and the password. Administrator: `admin@demo.test` or `0917 000 0000`.
   Resident: `resident@demo.test` or `0917 000 1108`. Password for both: `Demo@1234`.

To make a web build you can host or open later, double-click `BUILD-PROTOTYPE-WEB.bat`
(the files are created in `build\web`).

## What you can try

Resident: Home, Book a facility, Reservations, Dues and payment proof, Motor parking, Events, Polls, Directory and
house rules, Grievances (with who is fixing it), Maintenance (closed areas and coming work), Documents, Unit Rental, Settings.

Administrator: Home with a Maintenance card, Units, Facility (a facility with broken equipment is closed to bookings),
Announcements, Polls, Finance and payment checking, Expenses, Reports, Grievances with repair assignment,
Maintenance (schedule, equipment, staff), Motor parking, Rentals, Activity log, Manage access, Settings.

## What the prototype does not do

- It does not connect to Supabase or any other database, so changes are not shared between devices.
- Password, account and text-message features are switched off ("This feature is not available in the prototype").
- The sample data is made up. Some documents are marked "(sample)".

## Prototype or official app

It is the same code. One setting decides which one runs:

| Command | Result |
|---|---|
| `flutter run -d chrome --dart-define=PROTOTYPE=true` | Prototype: sample data, no database, no "demo" wording |
| `flutter run -d chrome --dart-define=DEMO=true` | Demo: same, with the "Demo mode" box on the sign-in screen |
| `flutter run -d chrome` | Official app: real sign-in and the Supabase database |

The full documentation of the official app (accounts, database, Edge Functions, documents, payments) is kept in
`docs/README-official-app.md`.

## Where things are

```
lib/
  main.dart                       app entry, theme, sign-in and role switching
  services/demo.dart              the sample data and the PROTOTYPE / DEMO switch
  core/                           models, shared state, theme, maintenance (prototype only)
  screens/auth/login_screen.dart  sign-in and Quick access
  screens/resident/               resident screens (Home, Book, Dues, More ...)
  screens/admin/                  administrator screens (Home, Units, Facility, Finance, More ...)
  screens/shared/                 calendar, document viewer, maintenance widgets
  widgets/                        reusable UI pieces
assets/                           images (building photo, tiles)
database/ and supabase/           schema and Edge Functions of the official app (not used by the prototype)
```
