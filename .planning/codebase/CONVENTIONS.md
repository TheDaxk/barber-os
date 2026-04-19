# Coding Standards and Patterns - BarberOS

This document describes the coding conventions and patterns observed in the BarberOS Flutter project.

## Language

- **Primary Language**: Brazilian Portuguese for all user-facing strings, comments, and documentation
- **Code Comments**: Portuguese comments explaining business logic and complex operations
- **UI Labels**: All UI text in Portuguese (e.g., "E-mail", "Senha", "Entrar", "Clientes")
- **Error Messages**: Portuguese error messages (e.g., "Erro: $err", "Login realizado com sucesso!")

## Naming Conventions

### Files and Directories
- **Directories**: lowercase_with_underscores or feature-based naming
  - `lib/core/presentation/`, `lib/features/auth/presentation/`
  - Feature directories: `lib/features/orders/`, `lib/features/clients/`

- **Files**: lowercase_with_underscores for Dart files
  - `login_screen.dart`, `main_navigation.dart`, `clients_provider.dart`
  - Screen files suffixed with `_screen.dart`
  - Provider files suffixed with `_provider.dart`

### Classes and Types
- **Classes**: PascalCase
  - `BarberOSApp`, `LoginScreen`, `MainNavigation`, `ClientsProvider`
- **State Classes**: PascalCase with `State` suffix
  - `_LoginScreenState`, `_MainNavigationState`

### Variables and Functions
- **Variables**: camelCase
  - `_emailController`, `_passwordController`, `_isLoading`
- **Functions/Methods**: camelCase
  - `_signIn()`, `capitalize()`, `formatCurrency()`

### Constants
- **Constants**: camelCase or PascalCase with `k` prefix
  - `supabaseUrl`, `supabaseAnonKey` (hardcoded in main.dart)

## Code Organization

### Directory Structure
```
lib/
├── core/
│   ├── presentation/     # Main navigation and core UI components
│   ├── supabase/        # Supabase providers and configuration
│   ├── database/        # Database schemas (Drift)
│   ├── router/          # Navigation routing (go_router)
│   ├── theme/           # App theming
│   └── utils/            # Utility functions
├── features/            # Feature-based modules
│   ├── auth/           # Authentication
│   ├── dashboard/      # Home dashboard
│   ├── orders/         # Appointment scheduling and management
│   ├── clients/        # Client management
│   ├── services/       # Service management
│   ├── reports/        # Financial reports
│   ├── team/           # Employee management
│   └── settings/       # User settings and profile
└── main.dart           # App entry point
```

### Feature Module Structure
Each feature follows a consistent pattern:
```
features/[feature_name]/
├── presentation/
│   ├── [feature_name]_screen.dart
│   └── widgets/
└── providers/
    └── [feature_name]_provider.dart
```

## State Management

### Riverpod Pattern
- **Provider Definition**: Providers are defined in feature-specific `providers/` directories
- **Core Providers**: Central providers in `lib/core/supabase/providers.dart`
- **Auto-Dispose**: Uses `FutureProvider.autoDispose` for data fetching with automatic cleanup
- **Pattern**:
  ```dart
  final someProvider = FutureProvider.autoDispose<Type>((ref) async {
    final supabase = ref.watch(supabaseProvider);
    // fetch and return data
  });
  ```

### Key Providers
- `supabaseProvider`: Provides SupabaseClient instance
- `userProfileProvider`: Fetches logged-in user data from `users` and `barbers` tables
- `servicesProvider`: Fetches active services
- `barbersProvider`: Fetches active barbers
- Feature-specific providers in each feature directory

### State Access
- Use `ref.watch()` to observe providers in widgets
- Use `ref.read()` for one-time reads
- Use `.when()` for AsyncValue handling (loading, error, data)

## Error Handling

### Authentication Errors
- Catch `AuthException` specifically for auth errors
- Display user-friendly messages via SnackBar
- Use `mounted` check before updating state

### General Error Handling
```dart
try {
  // operation
} on AuthException catch (e) {
  // Handle auth-specific errors
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: Colors.red),
    );
  }
} catch (e) {
  // Handle unexpected errors
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro inesperado ocorreu'), backgroundColor: Colors.red),
    );
  }
}
```

### AsyncValue Handling
```dart
return userProfileAsync.when(
  loading: () => const Scaffold(..., body: Center(child: CircularProgressIndicator())),
  error: (err, stack) => Scaffold(..., body: Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red)))),
  data: (user) { /* render UI */ },
);
```

## UI Component Patterns

### Screen Pattern
- Screens extend `ConsumerStatefulWidget` or `StatefulWidget`
- Controllers initialized as fields
- `dispose()` method properly cleans up controllers

### Form Fields
```dart
TextField(
  controller: _emailController,
  keyboardType: TextInputType.emailAddress,
  decoration: const InputDecoration(
    labelText: 'E-mail',
    prefixIcon: Icon(Icons.email_outlined),
    border: OutlineInputBorder(),
  ),
)
```

### Loading States
- Use `CircularProgressIndicator` for loading states
- Disable buttons during loading (`onPressed: _isLoading ? null : _signIn`)
- Show loading indicator inside button (`_isLoading ? CircularProgressIndicator(...) : Text('Entrar')`)

### SnackBar Messages
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(message), backgroundColor: Colors.green),
);
```

### Theme
- Dark theme with seed color `0xFF1E1E1E`
- Material Design 3 (`useMaterial3: true`)
- Brightness dark by default
- Color scheme generated from seed

## Navigation Patterns

### Main Navigation
- `MainNavigation` extends `ConsumerStatefulWidget`
- `IndexedStack` for maintaining tab state
- `BottomNavigationBar` for tab switching
- Role-based tab visibility using `isLeader` check

### Role-Based Access
```dart
final isLeader = user['category'] == 'Barbeiro Líder' || user['role'] == 'admin';

final List<Widget> tabs = [
  const HomeScreen(),
  const ScheduleAgendaScreen(),
  const ClientsScreen(),
  if (isLeader) const FinancialScreen(),  // Conditionally show
];
```

### Screen Transitions
- `Navigator.of(context).pushReplacement()` for replacing screens
- `MaterialPageRoute` for standard navigation
- Some screens use `MaterialPageRoute` directly

## API/Data Patterns

### Supabase Queries
```dart
final response = await supabase
    .from('table_name')
    .select('column1, column2')
    .eq('field', value)
    .order('field');

return List<Map<String, dynamic>>.from(response);
```

### Data Transformation
- Convert responses to `List<Map<String, dynamic>>` using `.from(response)`
- Handle nullable fields with null checks and defaults
- Use `.maybeSingle()` for optional single results

## Security Patterns

### Row Level Security (RLS)
- RLS policies enforced at database level
- Multi-tenant isolation via `unit_id`
- User role/category determines data visibility

### User Roles
- `Barbeiro Líder` (Barber Leader): Full access to financial data
- `barber`: Limited to own appointments/revenue
- `admin`: Full administrative access

## Code Style Rules

### Analysis Options
- Strict casts enabled (`strict-casts: true`)
- Strict inference enabled (`strict-inference: true`)
- Strict raw types enabled (`strict-raw-types: true`)
- Generated files excluded from analysis

### Lint Rules
- `avoid_print: false` - Prints allowed in code (often removed in production)
- `prefer_const_constructors: true` - Prefer const constructors
- `prefer_final_locals: true` - Prefer final local variables

### Test-Specific Rules
- `public_member_api_docs: false` - No documentation requirement in tests
- `lines_longer_than_80_chars: false` - Longer lines allowed in tests
- `test_types_in_equals: true` - Use exact types in equals

## Import Organization

### Standard Pattern
```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/presentation/main_navigation.dart';  // Relative to file location
import 'package:barber_os/features/...';
```

### Import Order
1. Dart/Flutter SDK imports
2. Package imports (supabase, riverpod, etc.)
3. Core module imports
4. Feature imports

## Database Schema (Supabase)

### Key Tables
- `users`: User accounts with `unit_id`
- `barbers`: Barber profiles with `user_id`, `category`, `commission_rate`
- `orders`: Appointments with `unit_id`, `barber_id`, `client_id`, `service_id`
- `services`: Available services

### Key Relationships
- `users` to `barbers` via `user_id`
- `orders` to `barbers` via `barber_id`
- `orders` to `services` via `service_id`

## Testing Patterns

### Test Organization
- Widget tests: `test/barberos_widget_test.dart`
- Unit tests: `test/barberos_unit_test.dart`
- Integration tests: `test/barberos_integration_test.dart`
- Test helpers: `test/test_config.dart`

### Test Data
- Use `TestData` class for mock data
- `TestData.regularUser`, `TestData.leaderUser`, `TestData.adminUser`
- `TestData.sampleServices`, `TestData.sampleBarbers`

### Common Assertions
- `expect(find.text('...'), findsOneWidget)` - Text present
- `expect(find.byType(TextField), findsNWidgets(2))` - Multiple widgets
- `expect(theme!.brightness, Brightness.dark)` - Theme check