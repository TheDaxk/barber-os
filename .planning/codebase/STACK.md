# Technology Stack Overview

## Core Framework

### Flutter SDK
- **Version**: Dart SDK ^3.11.1
- **Platform Support**: Android, iOS, Web, Windows, macOS, Linux
- **UI Framework**: Material Design 3 with dark theme (seed color: 0xFF1E1E1E)

### Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^3.3.1 | State management |
| `supabase_flutter` | ^2.12.1 | Backend-as-a-service (PostgreSQL + Auth) |
| `drift` | ^2.32.1 | Local SQLite ORM for Flutter |
| `sqlite3_flutter_libs` | ^0.6.0+eol | SQLite native libraries |
| `path_provider` | ^2.1.5 | File system access for local database |
| `go_router` | ^17.1.0 | Declarative routing/navigation |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

### Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Widget and unit testing |
| `flutter_lints` | ^6.0.0 | Code quality lints |
| `build_runner` | ^2.13.1 | Code generation runner |
| `drift_dev` | ^2.32.1 | Drift code generation |
| `mockito` | ^5.4.4 | Mocking for tests |
| `test` | ^1.24.0 | Advanced testing features |

---

## State Management

**Approach**: Riverpod with `FutureProvider.autoDispose`

The application uses Flutter Riverpod for state management with the following patterns:
- `FutureProvider.autoDispose` for async data fetching with automatic cleanup when screens are disposed
- Feature-specific providers located in `providers/` directories within each feature module
- Core providers in `lib/core/supabase/providers.dart` for shared state

Example provider pattern:
```dart
final servicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('services').select('*').eq('is_active', true);
  return List<Map<String, dynamic>>.from(response);
});
```

---

## Database Architecture

### Cloud Database: Supabase (PostgreSQL)

- **Project ID**: `akqvqyiyhyuzrnvpvfxt`
- **URL**: `https://akqvqyiyhyuzrnvpvfxt.supabase.co`
- **Tables**: `users`, `barbers`, `orders`, `services`
- **Security**: Row Level Security (RLS) with unit-based multi-tenant isolation

### Local Database: Drift (SQLite)

- **Purpose**: Offline data persistence (planned/implemented but not heavily used yet)
- **Code Generation**: Requires `flutter pub run build_runner build` after schema changes
- **Location**: Typically stored in app documents directory via `path_provider`

### Database Schema Relationships

```
users (id, email, unit_id, role)
  └── barbers (user_id, category) - references users
  └── orders (unit_id, barber_id, client_id, service_id) - references barbers
  └── services (id, name, price) - referenced by orders
```

---

## Navigation

**Primary Solution**: `go_router` (^17.1.0)

**Secondary**: `MaterialPageRoute` for certain screen transitions

### Navigation Architecture

1. **Entry Point**: `LoginScreen` handles authentication
2. **Main Navigation**: `MainNavigation` widget with bottom navigation bar
3. **Conditional Tabs**: Role-based tabs (e.g., FinancialScreen only visible to leaders)

### Bottom Navigation Structure

| Tab | Screen | Access |
|-----|--------|--------|
| Home | `HomeScreen` | All users |
| Agenda | `ScheduleAgendaScreen` | All users |
| Clientes | `ClientsScreen` | All users |
| Caixa | `FinancialScreen` | Leaders/Admin only |

---

## Project Directory Structure

```
lib/
├── core/
│   ├── presentation/     # MainNavigation (bottom nav shell)
│   ├── supabase/        # Supabase providers and client config
│   └── (theme/, router/, database/, utils/ - planned)
├── features/
│   ├── auth/           # Login screen
│   ├── dashboard/      # Home dashboard
│   ├── orders/        # Scheduling, appointments, checkout
│   ├── clients/       # Client management
│   ├── services/      # Service management
│   ├── reports/       # Financial reports (leader-only)
│   ├── team/          # Employee/barber management
│   └── settings/      # User settings and profile
└── main.dart          # App entry point, Supabase init, theme config
```

---

## Testing Stack

| Type | File | Framework |
|------|------|-----------|
| Widget Tests | `test/barberos_widget_test.dart` | flutter_test |
| Unit Tests | `test/barberos_unit_test.dart` | flutter_test + mockito |
| Integration Tests | `test/barberos_integration_test.dart` | flutter_test |
| Test Helpers | `test/test_config.dart` | TestData utilities |

Run tests: `flutter test` or use automation scripts (`run_tests.sh`/`run_tests.bat`)

---

## Build Commands

```bash
# Development
flutter run
flutter run --hot-reload

# Build
flutter build apk           # Android APK
flutter build appbundle    # Android App Bundle
flutter build ios          # iOS
flutter build web          # Web

# Code Generation (Drift)
flutter pub run build_runner build --delete-conflicting-outputs

# Analysis
flutter analyze
```
