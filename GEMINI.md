# Architect Expense Tracker - Project Context

This document serves as the persistent context for the Flutter-based Architect Expense Tracking application.

## Project Overview
A Flutter application designed for architects to track client projects, receive money from clients, and manage payments to various agencies (contractors/vendors).

## Tech Stack
- **Framework:** Flutter (Dart)
- **Local Storage:** `sqflite` (SQLite)
- **PDF Generation:** `pdf`, `printing`, `google_fonts`
- **Date Handling:** `intl`

## Database Schema (Version 5)
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

## Key Features & Logic

### Financial Logic
- **Current Balance:** `Total Received from Client` - `Payments to Agencies (Source: Client, Date <= Today)`.
- **Future Payments:** Payments dated after today are tracked as "Planned" and do not affect the current balance.
- **Self Payments:** Tracked separately; do not affect the client's balance.

### CRUD Capabilities
- **Clients:** Create, Read, Edit, Delete (removes all associated data).
- **Agencies:** Create, Read (per client), Edit (rename), Delete (removes associated payments).
- **Payments:** Create, Read (per agency), Edit, Delete.
- **Money History:** View and edit all historical contributions from the client.

### Analytics & Reporting
- **Analytics Screen:** Provides two tables (Client vs. Self) showing Previous Week, Current Week, and Future payment totals for each agency.
- **PDF Export:** Generates a professional summary report using Roboto fonts for Unicode support.

## Project Structure
- `lib/models/`: Data classes (`Client`, `Agency`, `Payment`, `ClientContribution`).
- `lib/database/db_helper.dart`: Singleton for SQLite operations and schema management.
- `lib/main.dart`: Unified UI containing all screens (`HomeScreen`, `ClientDetailScreen`, `AgencyDetailScreen`, `AnalyticsScreen`, `ContributionHistoryScreen`).

## Developer Notes
- Always call `WidgetsFlutterBinding.ensureInitialized()` in `main()` to support plugin initialization.
- Database Version 5 is the current stable schema.
