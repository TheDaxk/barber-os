# BarberOS Directory Structure

## Complete Project Structure

```
barber_os - atual/
├── .claude/                    # Claude AI configuration
├── .dart_tool/                  # Dart SDK tooling
├── .flutter-plugins-dependencies/
├── .gitignore
├── .idea/                       # IntelliJ IDEA project files
├── .metadata                    # Flutter project metadata
├── android/                     # Android platform files
├── ios/                         # iOS platform files
├── linux/                       # Linux platform files
├── macos/                       # macOS platform files
├── web/                         # Web platform files
├── windows/                     # Windows platform files
├── build/                       # Build output
├── lib/                         # Dart source code (MAIN)
├── test/                        # Test files
├── .planning/                   # Planning documentation
│   └── codebase/
│       ├── ARCHITECTURE.md
│       └── STRUCTURE.md (this file)
├── analysis_options.yaml        # Dart linting rules
├── pubspec.yaml                 # Flutter dependencies
├── pubspec.lock                 # Locked dependency versions
├── README.md                    # Project readme
├── CLAUDE.md                    # Claude AI instructions
├── TESTING.md                  # Testing documentation
├── supabase_rls_fix.sql        # Database RLS policies
├── run_tests.sh                # Linux/macOS test runner
├── run_tests.bat               # Windows test runner
├── setup_barberos.py           # Python setup script
└── test.dart                   # Test entry point
```

## lib/ Directory Structure

```
lib/
├── main.dart                    # App entry point, initialization
│
├── core/                        # Core infrastructure
│   ├── database/                # Drift database (planned)
│   ├── presentation/
│   │   └── main_navigation.dart # Main navigation shell
│   ├── router/                  # go_router configuration (partial)
│   ├── supabase/
│   │   └── providers.dart       # Supabase client + core providers
│   ├── theme/                   # Theme configuration (planned)
│   └── utils/                   # Utility functions (planned)
│
└── features/                    # Feature-based modules
    ├── auth/
    │   └── presentation/
    │       └── login_screen.dart
    │
    ├── barbers/
    │   └── presentation/
    │
    ├── clients/
    │   ├── clients_screen.dart
    │   └── providers/
    │       └── clients_provider.dart
    │
    ├── dashboard/
    │   ├── presentation/
    │   │   └── home_screen.dart
    │   └── providers/
    │       └── dashboard_provider.dart
    │
    ├── orders/
    │   ├── presentation/
    │   │   ├── checkout_screen.dart
    │   │   ├── create_appointment_screen.dart
    │   │   ├── schedule_agenda_screen.dart
    │   │   └── schedule_screen.dart
    │   └── providers/
    │       └── appointments_provider.dart
    │
    ├── reports/
    │   ├── presentation/
    │   │   └── financial_screen.dart
    │   └── providers/
    │       └── financial_provider.dart
    │
    ├── services/
    │   ├── create_service_screen.dart
    │   └── services_provider.dart
    │
    ├── settings/
    │   ├── edit_profile_screen.dart
    │   └── menu_screen.dart
    │
    └── team/
        ├── presentation/
        │   ├── employee_details_screen.dart
        │   └── employees_screen.dart
        └── providers/
            ├── barber_metrics_provider.dart
            ├── employees_provider.dart
            └── units_provider.dart
```

## Core Layer (`lib/core/`)

The `core/` directory contains shared infrastructure and providers used across features.

### lib/core/supabase/providers.dart

**File Path**: `lib/core/supabase/providers.dart`

**Purpose**: Central Supabase client configuration and core providers

**Key Exports**:
- `supabaseProvider`: Singleton Supabase client
- `userProfileProvider`: Current authenticated user data
- `servicesProvider`: Active services catalog
- `barbersProvider`: Active barbers list

### lib/core/presentation/main_navigation.dart

**File Path**: `lib/core/presentation/main_navigation.dart`

**Purpose**: Main app shell with bottom navigation bar

**Responsibilities**:
- Bottom navigation with role-based tabs
- User profile loading and role determination
- Tab persistence with IndexedStack
- AppBar with notifications and settings

### Planned Core Directories

| Directory | Purpose | Status |
|-----------|---------|--------|
| `core/database/` | Drift SQLite database | Planned |
| `core/router/` | go_router configuration | Partial |
| `core/theme/` | Theme definitions | Planned |
| `core/utils/` | Utility functions | Planned |

## Features Layer (`lib/features/`)

Each feature module follows a consistent pattern with `presentation/` and `providers/` directories.

### Feature: auth

**Directory**: `lib/features/auth/`

| File | Purpose |
|------|---------|
| `presentation/login_screen.dart` | Login form with Supabase authentication |

### Feature: dashboard

**Directory**: `lib/features/dashboard/`

| File | Purpose |
|------|---------|
| `presentation/home_screen.dart` | Main dashboard with KPIs, rankings, recent orders |
| `providers/dashboard_provider.dart` | Dashboard data fetching (today's metrics, rankings) |

### Feature: orders

**Directory**: `lib/features/orders/`

| File | Purpose |
|------|---------|
| `presentation/schedule_screen.dart` | Order list view |
| `presentation/schedule_agenda_screen.dart` | Agenda/calendar view |
| `presentation/create_appointment_screen.dart` | New appointment creation |
| `presentation/checkout_screen.dart` | Order checkout |
| `providers/appointments_provider.dart` | Orders/schedule data fetching |

### Feature: clients

**Directory**: `lib/features/clients/`

| File | Purpose |
|------|---------|
| `clients_screen.dart` | Client list and management |
| `providers/clients_provider.dart` | Client data management |

### Feature: services

**Directory**: `lib/features/services/`

| File | Purpose |
|------|---------|
| `create_service_screen.dart` | Service creation/editing |
| `services_provider.dart` | Services catalog management |

### Feature: reports

**Directory**: `lib/features/reports/`

| File | Purpose |
|------|---------|
| `presentation/financial_screen.dart` | Financial reports and metrics |
| `providers/financial_provider.dart` | Financial data fetching |

### Feature: team

**Directory**: `lib/features/team/`

| File | Purpose |
|------|---------|
| `presentation/employees_screen.dart` | Employee list |
| `presentation/employee_details_screen.dart` | Employee detail view |
| `providers/employees_provider.dart` | Employee data |
| `providers/barber_metrics_provider.dart` | Barber performance metrics |
| `providers/units_provider.dart` | Unit/branch management |

### Feature: settings

**Directory**: `lib/features/settings/`

| File | Purpose |
|------|---------|
| `menu_screen.dart` | Settings menu |
| `edit_profile_screen.dart` | Profile editing |

## Entry Points

### main.dart

**Path**: `lib/main.dart`

**Purpose**: Application entry point and initialization

**Key Responsibilities**:
1. Initialize Flutter bindings: `WidgetsFlutterBinding.ensureInitialized()`
2. Initialize Supabase: `Supabase.initialize(url, anonKey)`
3. Wrap app with `ProviderScope`
4. Define app theme (Material 3, dark mode, seed color `#1E1E1E`)
5. Set `LoginScreen` as initial home (or `MainNavigation` if already authenticated)

**Supabase Configuration**:
```dart
const supabaseUrl = 'https://akqvqyiyhyuzrnvpvfxt.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

### LoginScreen

**Path**: `lib/features/auth/presentation/login_screen.dart`

**Purpose**: Authentication entry point

**Flow**:
1. User enters email/password
2. `supabase.auth.signInWithPassword()` called
3. On success: Navigate to `MainNavigation`
4. On error: Display SnackBar with error message

## Configuration Files

### pubspec.yaml

**Path**: `pubspec.yaml`

**Purpose**: Flutter project dependencies

**Key Dependencies**:
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter` | SDK | Flutter framework |
| `supabase_flutter` | ^2.12.1 | Backend services |
| `flutter_riverpod` | ^3.3.1 | State management |
| `go_router` | ^17.1.0 | Navigation (partial) |
| `drift` | ^2.32.1 | Local SQLite (partial) |
| `sqlite3_flutter_libs` | ^0.6.0+eol | SQLite native libs |
| `path_provider` | ^2.1.5 | File system paths |

**Dev Dependencies**:
| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Testing framework |
| `flutter_lints` | ^6.0.0 | Linting rules |
| `build_runner` | ^2.13.1 | Code generation |
| `drift_dev` | ^2.32.1 | Drift code gen |
| `mockito` | ^5.4.4 | Mocking for tests |
| `test` | ^1.24.0 | Advanced testing |

### analysis_options.yaml

**Path**: `analysis_options.yaml`

**Purpose**: Dart linting and static analysis configuration

### supabase_rls_fix.sql

**Path**: `supabase_rls_fix.sql`

**Purpose**: Database RLS policies for Supabase

**Tables Affected**:
- `users`
- `barbers`
- `orders`
- `services`

**Key Security Functions**:
- `auth_user_unit_id()`: Returns current user's unit_id (SECURITY DEFINER)
- `auth_user_role()`: Returns current user's role (SECURITY DEFINER)

## Test Structure

```
test/
├── barberos_integration_test.dart
├── barberos_unit_test.dart
├── barberos_widget_test.dart
├── test_config.dart                   # Test helpers and mock data
├── test.dart                          # Alternative test entry
├── automation/
│   ├── run_tests.sh                   # Linux/macOS automation
│   └── run_tests.bat                  # Windows automation
└── (platform specific test directories)
```

### Test Configuration (`test/test_config.dart`)

**Purpose**: Shared test utilities and mock data (TestData class)

## Development Scripts

### run_tests.sh / run_tests.bat

**Purpose**: Automated test execution script

**Supported Commands**:
- All tests
- Widget tests only
- Unit tests only
- Integration tests only
- Coverage reports
- Static analysis (`flutter analyze`)
- Clean build

### setup_barberos.py

**Purpose**: Python setup script for project initialization

## Database Schema (Supabase)

### Table: users

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key (auth.uid) |
| `email` | text | User email |
| `name` | text | Display name |
| `role` | text | User role (admin, etc.) |
| `unit_id` | uuid | Tenant/branch identifier |

### Table: barbers

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `user_id` | uuid | FK to users |
| `category` | text | Barbeiro Líder, etc. |
| `commission_rate` | numeric | Commission percentage |
| `is_active` | boolean | Active status |

### Table: orders

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `unit_id` | uuid | Tenant identifier |
| `barber_id` | uuid | FK to barbers |
| `client_id` | uuid | FK to clients (optional) |
| `service_id` | uuid | FK to services |
| `client_name` | text | Client name (for walk-ins) |
| `start_time` | timestamptz | Appointment start |
| `end_time` | timestamptz | Appointment end |
| `status` | text | open, closed, canceled |
| `total` | numeric | Order total |

### Table: services

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `name` | text | Service name |
| `price` | numeric | Service price |
| `duration_minutes` | integer | Service duration |
| `is_active` | boolean | Active status |

## Navigation Routes

| Screen | Route Type | File |
|--------|------------|------|
| Login | Initial | `features/auth/presentation/login_screen.dart` |
| Main Navigation | Shell | `core/presentation/main_navigation.dart` |
| Home Dashboard | Tab 0 | `features/dashboard/presentation/home_screen.dart` |
| Schedule Agenda | Tab 1 | `features/orders/presentation/schedule_agenda_screen.dart` |
| Clients | Tab 2 | `features/clients/clients_screen.dart` |
| Financial | Tab 3 (leader) | `features/reports/presentation/financial_screen.dart` |
| Settings Menu | Push | `features/settings/menu_screen.dart` |
| Edit Profile | Push | `features/settings/edit_profile_screen.dart` |

## Key Patterns

### Provider Definition Pattern

```dart
// Feature provider using autoDispose
final featureProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  // ... fetch data
  return List<Map<String, dynamic>>.from(response);
});
```

### ConsumerWidget Pattern

```dart
class FeatureScreen extends ConsumerStatefulWidget {
  const FeatureScreen({super.key});

  @override
  ConsumerState<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends ConsumerState<FeatureScreen> {
  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(featureProvider);
    
    return dataAsync.when(
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Erro: $err'),
      data: (data) => ContentWidget(data),
    );
  }
}
```

### Role-Based Visibility

```dart
final isLeader = user['category'] == 'Barbeiro Líder' || user['role'] == 'admin';

if (isLeader)
  BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Caixa'),
```
