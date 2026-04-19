# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BarberOS is a Flutter-based barbershop management system built with:
- **Frontend**: Flutter (Dart) with Material Design 3
- **Backend**: Supabase (PostgreSQL + Auth)
- **State Management**: Riverpod
- **Local Database**: Drift (SQLite)
- **Navigation**: go_router (with some MaterialPageRoute usage)
- **Language**: Brazilian Portuguese (code comments, UI labels, error messages)

## Development Commands

### Running the Application
```bash
# Run on connected device/emulator
flutter run

# Run with hot reload
flutter run --hot-reload

# Run in release mode
flutter run --release
```

### Building
```bash
# Build APK for Android
flutter build apk

# Build App Bundle for Android
flutter build appbundle

# Build for iOS
flutter build ios

# Build for web
flutter build web
```

### Testing & Analysis
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Analyze code for errors and warnings
flutter analyze

# Format code
flutter format lib/
```

### Dependency Management
```bash
# Get packages
flutter pub get

# Upgrade packages
flutter pub upgrade

# Check for outdated packages
flutter pub outdated

# Run build_runner for code generation (drift)
flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture

### Directory Structure
```
lib/
├── core/
│   ├── presentation/     # Main navigation and core UI components
│   ├── supabase/        # Supabase providers and configuration
│   └── (theme/, router/, database/, utils/ planned but not fully implemented)
├── features/            # Feature-based modules
│   ├── auth/           # Authentication
│   ├── dashboard/      # Home dashboard
│   ├── orders/         # Appointment scheduling and management
│   ├── clients/        # Client management
│   ├── services/       # Service management
│   ├── reports/        # Financial reports
│   ├── team/           # Employee management
│   └── settings/       # User settings and profile
├── main.dart           # App entry point
```

### Key Architectural Patterns

1. **Feature-Based Organization**: Each feature has its own directory with `presentation/` (screens/widgets) and `providers/` (state management).

2. **State Management with Riverpod**:
   - Providers are defined in feature-specific `providers/` directories
   - Core Supabase providers in `lib/core/supabase/providers.dart`
   - Uses `FutureProvider.autoDispose` for data fetching with automatic cleanup

3. **Authentication Flow**:
   - Login screen (`LoginScreen`) authenticates with Supabase Auth
   - After login, navigates to `MainNavigation` with bottom navigation
   - User role/category determines UI visibility (e.g., financial screens for leaders only)

4. **Navigation**:
   - Main app uses `MainNavigation` with bottom navigation bar
   - Conditional tabs based on user role (`isLeader` check)
   - Some screens use `MaterialPageRoute` for navigation

5. **Database**:
   - Supabase for cloud data with Row Level Security (RLS)
   - See `supabase_rls_fix.sql` for RLS policies
   - Local SQLite with Drift (though not heavily implemented yet)

### Supabase Integration
- Project ID: `akqvqyiyhyuzrnvpvfxt`
- URL and anon key hardcoded in `main.dart` (consider moving to environment variables)
- Tables: `users`, `barbers`, `orders`, `services`
- RLS policies enforce unit-based access control

### UI/UX Patterns
- Dark theme with seed color `0xFF1E1E1E`
- Portuguese language throughout
- Role-based UI (leaders see financial screens)
- Loading states with `CircularProgressIndicator`
- Error handling with SnackBars

## Important Notes

1. **Security**: Supabase credentials are hardcoded in `main.dart`. For production, move to environment variables or secure storage.

2. **Database Schema**: Refer to `supabase_rls_fix.sql` for table structures and RLS policies. Key relationships:
   - `users` have `unit_id` for multi-tenant isolation
   - `barbers` reference `users` via `user_id`
   - `orders` reference `unit_id`, `barber_id`, `client_id`, `service_id`

3. **User Roles**: System distinguishes between:
   - Regular barbers
   - "Barbeiro Líder" (Barber Leader) 
   - Admin users
   - Role determines feature access in `MainNavigation`

4. **Code Generation**: Drift requires build_runner for generating database code. Run after modifying database schemas.

5. **Testing**: Comprehensive test suite implemented with:
   - **Widget tests**: `test/barberos_widget_test.dart` - UI component testing
   - **Unit tests**: `test/barberos_unit_test.dart` - Business logic and validation
   - **Integration tests**: `test/barberos_integration_test.dart` - Complete user flows
   - **Test helpers**: `test/test_config.dart` - Mock data (TestData) and utilities
   - **Automation scripts**: `run_tests.sh` (Linux/macOS) and `run_tests.bat` (Windows)
   - **Detailed guide**: `TESTING.md` - Complete testing documentation
   - **Dependencies**: mockito for mocking, test package for advanced testing features
   - **Lint configuration**: `analysis_options.yaml` updated with test-specific rules

6. **Platform Support**: Full Flutter multi-platform support (Android, iOS, web, Windows, macOS, Linux).

## Common Development Tasks

### Adding a New Feature
1. Create directory under `lib/features/feature_name/`
2. Add `presentation/` for screens/widgets
3. Add `providers/` for state management
4. Register navigation in `MainNavigation` if needed
5. Update Supabase RLS policies if new tables required

### Modifying Database Schema
1. Update Supabase tables via dashboard
2. Update RLS policies in `supabase_rls_fix.sql`
3. Run SQL in Supabase SQL Editor
4. Update Drift schemas if using local database
5. Run `flutter pub run build_runner build`

### Styling/Theming
- Theme defined in `BarberOSApp` class in `main.dart`
- Uses Material 3 with dark theme
- Custom colors should extend the color scheme

### Internationalization
- Currently Portuguese-only
- For multi-language support, implement Flutter localization

### Running Tests
```bash
# Using automation scripts (recommended)
./run_tests.sh          # Linux/macOS - runs all tests
run_tests.bat           # Windows - runs all tests

# Manual Flutter commands
flutter test                           # Run all tests
flutter test --coverage                # Run with code coverage
flutter test test/barberos_widget_test.dart    # Run specific test file
flutter analyze                        # Static analysis

# Test options with automation scripts
./run_tests.sh widget          # Widget tests only
./run_tests.sh unit            # Unit tests only  
./run_tests.sh integration     # Integration tests only
./run_tests.sh coverage        # Tests with coverage
./run_tests.sh analyze         # Static analysis
./run_tests.sh clean           # Clean build and dependencies

# See TESTING.md for detailed testing guide
```
- All user-facing strings need extraction