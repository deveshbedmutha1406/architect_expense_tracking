# Architect Expense Tracker - Project Context

This document serves as the persistent context for the Flutter-based Architect Expense Tracking application.

## Project Overview
A Flutter application designed for architects to track client projects, receive money from clients, and manage payments to various agencies (contractors/vendors).

## Tech Stack
- **Framework:** Flutter (Dart)
- **Local Storage:** `sqflite` (SQLite)
- **PDF Generation:** `pdf`, `printing`, `google_fonts`
- **Date Handling:** `intl`
- **Media & Files:** `image_picker`, `path_provider`, `share_plus`, `file_picker`, `archive`

## Database Schema (Version 7)
The database uses **Cascading Deletes** (requires `PRAGMA foreign_keys = ON`).

### 1. `clients` Table
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `name`: TEXT (Client Name)
- `project_name`: TEXT
- `site_address`: TEXT
- `total_amount`: REAL (Default 0.0)

### 2. `client_contributions` Table
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `client_id`: INTEGER (FK -> clients.id, CASCADE)
- `amount`: REAL
- `date`: TEXT (ISO8601)

### 3. `agencies` Table
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `name`: TEXT
- `client_id`: INTEGER (FK -> clients.id, CASCADE)

### 4. `payments` Table
- `id`: INTEGER PRIMARY KEY AUTOINCREMENT
- `agency_id`: INTEGER (FK -> agencies.id, CASCADE)
- `amount`: REAL
- `date`: TEXT (ISO8601)
- `payment_given_by`: TEXT ('Client' or 'Self')
- `qty`: REAL (Default 1.0)
- `remarks`: TEXT (Default '')
- `receipt_path`: TEXT (Stores filename of receipt image, relative to App Docs)

## Key Features & Logic

### Financial Logic
- **Currency:** All financial representations use the Rupee (**₹**) symbol.
- **Effective Amount:** All payment calculations now use `amount * qty`.
- **Current Balance:** `Total Received from Client` - `Payments to Agencies (Source: Client, Date <= Today)`.
- **Future Payments:** Payments dated after today are tracked as "Planned" and do not affect the current balance.
- **Self Payments:** Tracked separately; do not affect the client's balance.

### CRUD Capabilities
- **Clients:** Create, Read, Edit, Delete (removes all associated data).
- **Agencies:** Create, Read (per client), Edit (rename), Delete (removes associated payments).
- **Payments:** Create, Read (per agency), Edit (with qty/remarks/receipts), Delete.
- **Money History:** View and edit all historical contributions from the client.

### Data Management
- **Receipt Management:** Capture/Select receipts via Camera or Gallery. Images are stored internally.
- **Backup & Restore:** Export a single `.zip` file containing the JSON database dump and all receipt images. Import a ZIP to migrate data between devices.

### Analytics & Reporting
- **Analytics Screen:** Provides two types of reports:
    - **Summary View:** (Both, Client, or Self) showing Previous Week, Current Week, and Future payment totals for each agency.
    - **Custom Detailed Report:** A comprehensive list of all payments (past, present, future) including Date, Agency, Amount, Qty, Total, Receipt Status, and Remarks.
- **PDF Export:** Generates a professional summary or detailed report reflecting the current view selection.

## Project Structure
- `lib/models/`: Data classes (`Client`, `Agency`, `Payment`, `ClientContribution`).
- `lib/database/db_helper.dart`: Singleton for SQLite operations and schema management.
- `lib/database/backup_service.dart`: Handles ZIP-based backup/restore logic.
- `lib/main.dart`: Unified UI containing all screens (`HomeScreen`, `ClientDetailScreen`, `AgencyDetailScreen`, `AnalyticsScreen`, `ContributionHistoryScreen`).

## Session Summary (Feb 28, 2026)
- **Receipt Management:** Added support for capturing and storing receipt images for each payment.
- **Receipt Visualization:** Added an interactive, zoomable receipt viewer accessible via "View" links in the Analytics (Custom) section.
- **Receipt Sharing:** Integrated `share_plus` into the receipt viewer to allow users to share/export images.
- **Backup & Restore:** Implemented a robust ZIP-based backup system for data and media portability.
- **Currency Localization:** Switched the app's default currency symbol to Rupee (**₹**) and ensured consistent display in reports.
- **Stability & Fixes:** Resolved rendering issues in `AlertDialog`, fixed icon name errors, and added `context.mounted` checks for safer async navigation.
- **Architecture Update:** Migrated to relative paths for all stored media and upgraded DB to Version 7.

## Developer Notes
- Always call `WidgetsFlutterBinding.ensureInitialized()` in `main()` to support plugin initialization.
- Database Version 7 is the current stable schema.
