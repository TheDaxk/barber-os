# BarberOS Architecture

## Overview

BarberOS is a Flutter-based barbershop management system built with a modern, feature-based architecture. The system uses a multi-layered approach combining cloud infrastructure (Supabase) with local state management (Riverpod).

## High-Level Architecture Patterns

### Technology Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Flutter (Dart) with Material Design 3 |
| **Backend/Cloud** | Supabase (PostgreSQL + Auth) |
| **State Management** | Riverpod (flutter_riverpod) |
| **Local Database** | Drift (SQLite) - partially implemented |
| **Navigation** | go_router + MaterialPageRoute |
| **Language** | Brazilian Portuguese (pt-BR) |

### Architecture Principles

1. **Feature-Based Organization**: Each business domain (auth, dashboard, orders, clients, etc.) is encapsulated in its own feature module with clear separation between presentation and state management.

2. **Provider Pattern**: Riverpod providers manage all data fetching, caching, and state. Features use `FutureProvider.autoDispose` for automatic resource cleanup.

3. **Repository Pattern for Data**: Data access is abstracted through providers that handle Supabase queries and transformations.

4. **Multi-Tenant Isolation**: Row Level Security (RLS) policies in Supabase enforce unit-based data isolation.

## Feature Organization

### Features Directory Structure

```
lib/features/
├── auth/                    # Authentication
│   └── presentation/
│       └── login_screen.dart
├── dashboard/              # Home dashboard
│   ├── presentation/
│   │   └── home_screen.dart
│   └── providers/
│       └── dashboard_provider.dart
├── orders/                 # Appointments and scheduling
│   ├── presentation/
│   │   ├── schedule_screen.dart
│   │   ├── schedule_agenda_screen.dart
│   │   ├── create_appointment_screen.dart
│   │   └── checkout_screen.dart
│   └── providers/
│       └── appointments_provider.dart
├── clients/                # Client management
│   ├── clients_screen.dart
│   └── providers/
│       └── clients_provider.dart
├── services/               # Service catalog management
│   ├── create_service_screen.dart
│   └── services_provider.dart
├── reports/                # Financial reporting
│   ├── presentation/
│   │   └── financial_screen.dart
│   └── providers/
│       └── financial_provider.dart
├── team/                   # Employee management
│   ├── presentation/
│   │   ├── employees_screen.dart
│   │   └── employee_details_screen.dart
│   └── providers/
│       ├── employees_provider.dart
│       ├── barber_metrics_provider.dart
│       └── units_provider.dart
└── settings/              # User settings
    ├── menu_screen.dart
    └── edit_profile_screen.dart
```

### Feature Module Pattern

Each feature follows a consistent structure:

```
feature_name/
├── presentation/           # UI layer (screens, widgets)
│   ├── screen.dart
│   └── widgets/
├── providers/              # State management (Riverpod providers)
│   └── feature_provider.dart
└── models/                # Data models (if separate from providers)
```

## State Management Flow

### Provider Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      main.dart                              │
│  - ProviderScope wraps entire app                           │
│  - Initializes Supabase connection                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Core Supabase Providers                         │
│  (lib/core/supabase/providers.dart)                        │
│                                                              │
│  - supabaseProvider: SupabaseClient singleton               │
│  - userProfileProvider: Current user data + role           │
│  - servicesProvider: Available services list               │
│  - barbersProvider: Active barbers list                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           Feature-Specific Providers                         │
│                                                              │
│  - dashboardProvider: KPIs, rankings, recent orders         │
│  - appointmentsProvider: Order/schedule data               │
│  - clientsProvider: Client management                       │
│  - employeesProvider: Team management                       │
│  - financialProvider: Financial metrics                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Screens/Widgets                          │
│                                                              │
│  - ConsumerWidget for reactive UI updates                   │
│  - ref.watch() for observing provider state                │
│  - ref.read() for one-time provider access                 │
│  - ref.invalidate() for cache refresh                      │
└─────────────────────────────────────────────────────────────┘
```

### Key Providers

#### Core Providers (`lib/core/supabase/providers.dart`)

| Provider | Type | Purpose |
|----------|------|---------|
| `supabaseProvider` | `Provider<SupabaseClient>` | Supabase singleton access |
| `userProfileProvider` | `FutureProvider.autoDispose<Map<String, dynamic>>` | Current user data with role/category |
| `servicesProvider` | `FutureProvider.autoDispose<List<Map<String, dynamic>>>` | Active services list |
| `barbersProvider` | `FutureProvider.autoDispose<List<Map<String, dynamic>>>` | Active barbers with user info |

#### Feature Providers

| Provider | Purpose |
|----------|---------|
| `dashboardProvider` | Today's KPIs, rankings, recent orders, operational metrics |
| `appointmentsProvider` | Orders from today onwards |
| `clientsProvider` | Client list and management |
| `employeesProvider` | Employee/team data |
| `financialProvider` | Financial reports and metrics |

### State Management Patterns

1. **Auto-Dispose Pattern**: Most providers use `FutureProvider.autoDispose` for automatic cleanup when screens are disposed.

2. **Async Data Handling**: UI uses `.when()` pattern for handling loading, error, and data states:
   ```dart
   providerAsync.when(
     loading: () => CircularProgressIndicator(),
     error: (err, stack) => ErrorWidget(err),
     data: (data) => ContentWidget(data),
   )
   ```

3. **Cache Invalidation**: Pull-to-refresh uses `ref.invalidate(providerName)` to force fresh data.

## Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     App Launch                               │
│                   BarberOSApp (main.dart)                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   LoginScreen                                │
│                                                              │
│  - Email/password form                                      │
│  - Supabase.auth.signInWithPassword()                       │
│  - On success: Navigate to MainNavigation                   │
│  - On error: Show SnackBar with error message               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ (success)
┌─────────────────────────────────────────────────────────────┐
│                 MainNavigation                                │
│                                                              │
│  - Loads userProfileProvider                                │
│  - Determines user role (isLeader check)                    │
│  - Builds role-based navigation tabs                        │
│  - role = 'Barbeiro Líder' || role == 'admin'               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Role-Based Navigation Tabs                      │
│                                                              │
│  ALL USERS:                                                 │
│  - HomeScreen (Dashboard)                                   │
│  - ScheduleAgendaScreen                                     │
│  - ClientsScreen                                            │
│                                                              │
│  LEADERS/ADMINS ONLY:                                       │
│  - FinancialScreen (Caixa)                                  │
└─────────────────────────────────────────────────────────────┘
```

### Authentication Implementation

**Login Screen** (`lib/features/auth/presentation/login_screen.dart`):
- Uses `Supabase.instance.client` directly
- Calls `supabase.auth.signInWithPassword(email, password)`
- On success, navigates via `MaterialPageRoute` to `MainNavigation`
- Handles `AuthException` and generic exceptions with SnackBar

**User Profile** (`userProfileProvider`):
- Fetches from `users` table by `auth.uid()`
- Joins with `barbers` table to get `category` and `barber_id`
- Returns combined map with user data, role, and barber info

## Navigation Structure

### Navigation Hierarchy

```
App Entry
    │
    ▼
LoginScreen (initial, if not authenticated)
    │
    └──► MainNavigation (after login)
              │
              ├── BottomNavigationBar
              │     ├── Tab 0: HomeScreen (Dashboard)
              │     ├── Tab 1: ScheduleAgendaScreen
              │     ├── Tab 2: ClientsScreen
              │     └── Tab 3: FinancialScreen (leader/admin only)
              │
              └──► AppBar Actions
                    ├── Notifications (TODO)
                    └── Settings → MenuScreen
                              │
                              └──► EditProfileScreen
```

### Navigation Methods

1. **Bottom Navigation**: `MainNavigation` uses `IndexedStack` with `BottomNavigationBar` for tab persistence.

2. **MaterialPageRoute**: Used for push navigation to settings screens:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(builder: (context) => const MenuScreen()),
   );
   ```

3. **Role-Based Tab Visibility**: Tabs are conditionally added based on `isLeader`:
   ```dart
   if (isLeader) const BottomNavigationBarItem(
     icon: Icon(Icons.attach_money),
     label: 'Caixa',
   ),
   ```

### go_router Integration

The project includes `go_router: ^17.1.0` in dependencies, though primary navigation currently uses `MaterialPageRoute`. The router configuration exists in `lib/core/router/` but is not the main navigation method.

## Data Flow and API Design

### Supabase Database Schema

**Core Tables:**

| Table | Purpose | Key Relationships |
|-------|---------|-------------------|
| `users` | User accounts | `unit_id` (tenant), `role` |
| `barbers` | Barber profiles | `user_id` -> users, `category` (Barbeiro Líder, etc.) |
| `orders` | Appointments/commissions | `unit_id`, `barber_id`, `client_id`, `service_id` |
| `services` | Service catalog | `is_active` flag |

### Row Level Security (RLS)

RLS policies enforce multi-tenant isolation:

```sql
-- Users: Same unit can read
CREATE POLICY "users_select" ON users
  FOR SELECT TO authenticated
  USING (unit_id = auth_user_unit_id());

-- Orders: Same unit can access
CREATE POLICY "orders_select" ON orders
  FOR SELECT TO authenticated
  USING (unit_id = auth_user_unit_id());
```

### Query Pattern Example

```dart
final supabase = ref.watch(supabaseProvider);
final userId = supabase.auth.currentUser!.id;

// Fetch with filtering
final response = await supabase
    .from('orders')
    .select('id, start_time, client_name, status, total, barbers(id, commission_rate, users(name))')
    .eq('unit_id', unitId)
    .gte('start_time', startOfToday)
    .order('start_time', ascending: false);
```

## Theme and Styling

### Dark Theme Configuration

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF1E1E1E),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
)
```

### Color Palette

| Element | Color |
|---------|-------|
| Seed/Primary | `#1E1E1E` |
| Background | `#121212` (via dark theme) |
| AppBar | `#1E1E1E` |
| Selected items | Green |
| Unselected items | Grey |
| KPI cards | Contextual (green, blue, orange, purple) |

## Project Entry Points

| File | Purpose |
|------|---------|
| `lib/main.dart` | App initialization, Supabase setup, ProviderScope |
| `lib/core/presentation/main_navigation.dart` | Main app shell with bottom navigation |
| `lib/features/auth/presentation/login_screen.dart` | Authentication entry point |

## Testing Architecture

The project includes comprehensive testing infrastructure:

- **Widget Tests**: `test/barberos_widget_test.dart`
- **Unit Tests**: `test/barberos_unit_test.dart`
- **Integration Tests**: `test/barberos_integration_test.dart`
- **Test Helpers**: `test/test_config.dart` with mock data utilities

Dependencies: `mockito`, `test` package

## Security Considerations

1. **Hardcoded Credentials**: Supabase URL and anon key are hardcoded in `main.dart` (should be moved to environment variables for production).

2. **RLS Enforcement**: All data access is protected by Supabase Row Level Security policies.

3. **Multi-Tenant Isolation**: `unit_id` based access control ensures data separation between barbershops.

4. **Auth on Client**: Authentication happens client-side with Supabase Auth, tokens are handled automatically.
