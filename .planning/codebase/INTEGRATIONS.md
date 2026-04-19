# External Services and APIs

## Supabase Configuration

### Project Details

| Property | Value |
|----------|-------|
| **Project ID** | `akqvqyiyhyuzrnvpvfxt` |
| **Region** | Default (not specified) |
| **URL** | `https://akqvqyiyhyuzrnvpvfxt.supabase.co` |
| **Anon Key** | Hardcoded in `lib/main.dart` |

### Supabase Components Used

1. **PostgreSQL Database** - Cloud relational database
2. **Authentication** - Supabase Auth for user authentication
3. **Row Level Security (RLS)** - Multi-tenant data isolation

### Initialization

Supabase is initialized in `main.dart`:

```dart
const supabaseUrl = 'https://akqvqyiyhyuzrnvpvfxt.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

await Supabase.initialize(
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
);
```

**Note**: Credentials are hardcoded. For production, consider moving to environment variables or secure storage.

---

## Authentication

**Provider**: Supabase Auth

### Authentication Method
- **Email/Password** authentication via `supabase.auth.signInWithPassword()`
- Session management handled by Supabase client

### Login Flow
1. User enters email and password on `LoginScreen`
2. `supabase.auth.signInWithPassword()` validates credentials
3. On success, navigates to `MainNavigation`
4. On error, displays `AuthException` message via SnackBar

### User Profile Integration
- User profile data fetched from `users` table via `userProfileProvider`
- Barber data fetched from `barbers` table (joined by `user_id`)
- User role/category determines UI visibility

---

## Database Schema

### Tables

#### users
Primary user table with multi-tenant support.
- `id` (uuid, primary key) - links to Supabase Auth
- `email` (text)
- `unit_id` (uuid) - tenant isolation key
- `role` (text) - user role (e.g., 'admin', 'Barbeiro', 'Gestor')

#### barbers
Barber/employee records.
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key) - references users.id
- `category` (text) - e.g., 'Barbeiro Líder', 'Barbeiro'
- `is_active` (boolean)

#### orders
Service appointments/orders.
- `id` (uuid, primary key)
- `unit_id` (uuid) - tenant isolation
- `barber_id` (uuid) - references barbers.id
- `client_id` (uuid)
- `service_id` (uuid) - references services.id
- `payment_method` (text) - e.g., 'pix', 'credit_card', 'cash'
- Standard timestamp fields

#### services
Available services offered.
- `id` (uuid, primary key)
- `name` (text)
- `price` (numeric)
- `is_active` (boolean)

#### products
Product and inventory records.
- `id` (uuid, primary key)
- `unit_id` (uuid) - tenant isolation
- `name` (text)
- `price` (numeric)
- `stock` (integer)
- `updated_at` (timestamptz)

#### units
Barbershop unit/branch records.
- `id` (uuid, primary key)
- `name` (text)
- `address` (text)
- `is_active` (boolean)

---

## Row Level Security (RLS)

RLS policies enforce multi-tenant data isolation. See `supabase_rls_fix.sql` for full implementation.

### Security Functions (SECURITY DEFINER)
These functions bypass RLS to enable cross-table access:

```sql
-- Gets unit_id for current authenticated user
auth_user_unit_id() RETURNS uuid

-- Gets role for current authenticated user
auth_user_role() RETURNS text
```

### RLS Policies

| Table | SELECT | INSERT | UPDATE |
|-------|--------|--------|--------|
| users | Same unit_id | - | Own record only |
| barbers | All authenticated | - | - |
| orders | Same unit_id | Same unit_id | Same unit_id |
| services | All authenticated | - | - |
| products | Same unit_id | Same unit_id | Same unit_id |
| units | All authenticated | - | - |

---

## Third-Party Packages

### Core Backend Integration

| Package | Purpose |
|---------|---------|
| `supabase_flutter` | Supabase client for Flutter |

### Local Storage

| Package | Purpose |
|---------|---------|
| `drift` | Type-safe SQLite ORM |
| `sqlite3_flutter_libs` | Native SQLite bindings |
| `path_provider` | Access to device file system |

### State Management

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | Reactive state management |

### Navigation

| Package | Purpose |
|---------|---------|
| `go_router` | Declarative routing |

### Document Generation & Sharing

| Package | Purpose |
|---------|---------|
| `pdf` | PDF creation |
| `printing` | PDF printing and preview |
| `excel` | Excel spreadsheet creation |
| `csv` | CSV format generation |
| `share_plus` | Sharing files and data |
| `open_filex` | Opening external files |

### UI

| Package | Purpose |
|---------|---------|
| `cupertino_icons` | iOS-style icons |

### Testing

| Package | Purpose |
|---------|---------|
| `mockito` | Mocking framework |
| `test` | Testing framework |

---

## API Usage Patterns

### Fetching Data

```dart
// Fetch services
final response = await supabase
    .from('services')
    .select('*')
    .eq('is_active', true)
    .order('name');

// Fetch barbers with user names (via RLS join)
final response = await supabase
    .from('barbers')
    .select('id, category, users(name)')
    .eq('is_active', true);
```

### User Profile Query

```dart
final userData = await supabase.from('users').select().eq('id', user.id).single();
final barberData = await supabase.from('barbers').select('id, category').eq('user_id', user.id).maybeSingle();
```

---

## Environment Considerations

### Current State
- Supabase URL and anon key are hardcoded in `main.dart`
- No environment variable configuration currently implemented

### Production Recommendations
1. Move credentials to environment variables
2. Use `flutter_dotenv` package for local development
3. Consider secure storage solutions for sensitive data
4. Implement proper secret management for CI/CD

---

## External Dependencies Summary

```
supabase_flutter (^2.12.1)
  └── Provides: SupabaseClient, Auth, Database, Realtime

drift (^2.32.1)
  └── Provides: Local SQLite ORM (code generation required)

flutter_riverpod (^3.3.1)
  └── Provides: State management primitives

go_router (^17.1.0)
  └── Provides: Declarative navigation

path_provider (^2.1.5)
  └── Provides: Platform-specific storage paths

sqlite3_flutter_libs (^0.6.0+eol)
  └── Provides: Native SQLite libraries
```
