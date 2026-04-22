# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LeisureRyde is a Flutter mobile ride-sharing app serving three user roles: **passenger (user)**, **driver**, and **admin**. All roles share one codebase; role-based routing happens at startup based on the Firestore `role` field.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Lint check (flutter_lints)
flutter test             # Run all unit tests
flutter build apk        # Android release build
flutter build ios        # iOS release build
```

## Architecture

### State Management & DI

- **Provider** (`ChangeNotifier` + `Consumer<T>` / `Provider.of<T>()`) for reactive UI state
- **GetIt** as the service locator; all ViewModels and Services are registered in `lib/app/service_locator.dart`
- ViewModels are singletons registered at app startup and injected into widgets via `GetIt.instance<T>()`

### Layer Structure

```
lib/
├── app/              # Theme, enums, service_locator.dart
├── screens/          # UI — organized by role (shared/, user/, driver/, admin/)
├── viewmodel/        # ChangeNotifier ViewModels — one per feature area
├── services/         # Pure business logic; talk directly to Firebase/APIs
├── models/           # Data classes with fromFirestore / toMap serialization
├── widgets/          # Shared reusable UI components
└── globa/            # global_var.dart — Google Maps API keys per platform
```

### Role-Based Routing

`SplashScreen` reads `getCurrentUserRole()` from Firestore and pushes to the appropriate home screen. Navigation uses `Navigator.push` / `pushReplacement` (no named routes or GoRouter).

### ViewModel → Service → Firebase Flow

ViewModels coordinate the UI flow and hold state. Services contain the actual Firebase calls. Example ride-booking chain:

```
HomeViewModel → RideService / DirectionsService / FareCalculationService → Firebase
```

ViewModels cancel all stream subscriptions in `dispose()` — preserve this pattern.

### Firebase Integration

| Firebase product | Usage |
|---|---|
| Auth | Email/password for all three roles |
| Firestore | `users`, `rides`, `chats` collections |
| Realtime Database | Live driver location updates (lat/lng + heading) |
| Cloud Storage | Driver license uploads, profile images |
| Cloud Functions | Backend logic invoked via `cloud_functions` package |
| Messaging | Push notifications for ride status changes |

Key Firestore collections:
- **`users`** — uid as document ID; `role` field is `user` / `driver` / `admin`
- **`rides`** — status lifecycle: `pending → accepted → enroute → ongoing → completed / cancelled`

`RideStatus` is an enum with extension methods (e.g., `isTerminal`). Models use `copyWith()` for immutability.

### Real-Time Patterns

- Driver location streams from Firebase Realtime Database; `HomeViewModel` renders polylines and updates markers on each location tick.
- `HomeViewModel` also writes active ride state to `SharedPreferences` so a cold restart can resume an in-progress trip.
- Multi-step payment flow lives inside `HomeViewModel` (route selection → vehicle choice → payment → ride request creation).

### Key Files to Know

| File | Purpose |
|---|---|
| `lib/app/service_locator.dart` | All DI registration |
| `lib/globa/global_var.dart` | Google Maps API keys |
| `lib/viewmodel/home/home_view_model.dart` | Core passenger booking flow (~3000 lines) |
| `lib/viewmodel/home/driver_home_view_model.dart` | Driver-side ride acceptance flow |
| `lib/viewmodel/ride/active_trip_view_model.dart` | In-progress trip state |
| `lib/viewmodel/maps/maps_viewmodel.dart` | Map rendering helpers |
| `lib/screens/shared/` | Splash, welcome, auth screens |
| `firebase_options.dart` | Firebase project config (leisureryde-3ca0b) |
