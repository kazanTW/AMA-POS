# AMA-POS

A simple Android tablet-first Point of Sale (POS) system built with Flutter.

**Package name:** `tw.kazan.amapos`

## Features

### Cashier (櫃台)
- Create orders: add/remove items, adjust quantities
- Switch between dine-in (內用) and takeout (外帶), with table number for dine-in
- Quick cash checkout: shows amount due, enter received amount, displays change
- Support for "add items after sub-total": navigate back from checkout to add more items

### Backoffice (商家後台)
- Category management (CRUD + enable/disable)
- Product management (CRUD + enable/disable)
- Shift management: open/close shifts with statistics
- Daily reports: view daily sales by date
- Import/Export: JSON config file for merchant settings, categories, and products

## Tech Stack
- **Flutter** (3.x)
- **Riverpod** (state management, plain providers — no code generation)
- **go_router** (navigation)
- **sqflite** (SQLite local database, no code generation needed)
- **file_picker** + **path_provider** (file import/export)
- **intl** (formatting)
- **uuid** (ID generation)

## Project Structure

```
lib/
  app/             # app.dart, router.dart, theme.dart
  core/
    db/            # AppDatabase (sqflite), models, dao stubs
    utils/         # money, datetime, id helpers
  features/
    cashier/       # Cashier feature (pages, widgets, state, repo)
    backoffice/    # Backoffice feature (pages, state, repo)
android/           # Android-specific configuration
```

## Getting Started

### Prerequisites
- Flutter SDK >= 3.10.0
- Android SDK with API 21+
- Android tablet or emulator (landscape orientation recommended)

### Setup

```bash
# Install dependencies
flutter pub get

# Run on Android
flutter run
```

> **No code generation required.** This project uses `sqflite` for the database and plain Riverpod providers, so `build_runner` is not needed.

### First Run
The app automatically seeds sample data on first launch:
- Categories: 飲料 (drinks), 餐點 (food), 小食 (snacks)
- 12 sample products across the categories

## Architecture

- **Feature-first** folder structure
- **Riverpod** `StreamProvider` / `Provider` for dependency injection and reactive state
- **sqflite** for all persistent storage with polling-based reactive streams
- **Repository pattern** for data access isolation
- **go_router** for declarative navigation

## Database Schema

| Table | Description |
|---|---|
| `categories` | Product categories with sort order and active flag |
| `products` | Products with price (in NT$), category, sort order |
| `orders` | Sales orders with type (dineIn/takeOut), status, totals |
| `orderItems` | Line items with name/price snapshots |
| `payments` | Payment records (cash) |
| `shifts` | Cashier shifts with open/close times and cash amounts |
| `merchantConfigs` | Single-row merchant settings |

## MVP Scope
- Offline-only, single device
- Cash payments only (no payment gateway)
- No receipt printing (can be added later)
- Import/Export does not include order history or images

## Android Configuration
- **applicationId:** `tw.kazan.amapos`
- **minSdk:** 21
- **targetSdk:** 34
- **compileSdk:** 34
- **Orientation:** Landscape (tablet-optimised layout)
