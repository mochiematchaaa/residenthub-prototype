# ResidentHub: Facility Management System for City Residences Condominium (prototype)

Website and mobile app prototype of the system. Front end only: no database, sample data.

- Website (public site, resident portal, administrator dashboard): this folder (`index.html`, `resident.html`, `admin.html` ...)
- Mobile app (Flutter): `app-src/`. GitHub Actions builds it and publishes it at `/app/` next to the website.

The rest of this file is about the website. For the app, see `app-src/README.md`.

## Website prototype

This is the official website of City Residences Condominium Corporation (public site, resident portal and
administrator dashboard) running **without a database**. It does not use Supabase. The sign-in, the people, units,
dues, bookings, grievances, maintenance tasks and announcements are sample data kept in the browser (`demo-backend.js`).
Nothing is sent to a server. Changes stay in this browser.

## Run it in VS Code

Option 1 (easiest):
1. Open this folder in VS Code (File > Open Folder).
2. Install the extension **Live Server** (Ritwick Dey).
3. Right-click `index.html` and choose **Open with Live Server**.

Option 2 (no extension), in the VS Code terminal:
```
python -m http.server 5500
```
then open http://localhost:5500 (with Node: `npx serve .`).

## Pages

| Address | What it is |
|---|---|
| `index.html` | Public website (amenities, contact, Sign In) |
| `resident.html` | Resident portal sign-in and dashboard |
| `admin.html` | Administrator sign-in and dashboard |
| `app.html` | Page about the mobile app |

The Sign In button on the website opens the resident portal. Open `admin.html` for the administrator.

## Sign in

Type an email or a mobile number, then the password `Demo@1234`.

| Role | Email | Mobile number |
|---|---|---|
| Administrator | `admin@demo.test` | `0917 000 0000` |
| Resident (Maria Reyes, Unit 3B) | `resident@demo.test` | `0917 000 1108` |

Shortcuts: `admin.html?as=admin` and `resident.html?as=resident` open the dashboards already signed in.

## Reset the sample data or switch role

Add `?tools` to the address, for example `admin.html?tools`. A small **PROTOTYPE TOOLS** button appears at the
bottom-left with "Reset sample data" and "Open as Resident / Admin". Without `?tools` it is hidden.

## Files

| File | What it is |
|---|---|
| `demo-backend.js` | Replaces the database with sample data in the browser (edit this file to change the sample data) |
| `core.js`, `shared.js` | Code shared by both dashboards (sign-in, data access, helpers) |
| `admin.html/.js/.css`, `admin-more.js` | Administrator dashboard |
| `resident.html/.js/.css` | Resident dashboard |
| `maintenance.js`, `export-all.js` | Maintenance pages and "Export all data" Excel workbook (prototype only) |
| `index.html/.css/.js`, `app.html/.css`, `app-links.js` | Public website and app page |

The official website with the Supabase database is a separate project (`ResidentHub-Official-Web.zip`).
