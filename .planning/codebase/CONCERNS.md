# Concerns, Issues, and Technical Debt

## Security Issues

### CRITICAL: Hardcoded Supabase Credentials in main.dart
- **Location**: `lib/main.dart` (lines 9-10)
- **Issue**: Supabase URL and anon key are hardcoded as constants
- **Risk**: If this code is committed to version control (especially public repos), credentials are exposed
- **Recommendation**: Move to environment variables or a secure configuration mechanism:
  ```dart
  // Use environment variables or flutter_dotenv
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  ```

### Supabase Anon Key Exposed in Client-Side Code
- The anon key is visible in client-side Dart code
- While this is standard for Supabase client implementations, it allows anyone to access the Supabase project
- RLS policies mitigate this risk, but the exposure remains

## Architecture Concerns

### Mixed Navigation Patterns
- **Location**: `lib/core/presentation/main_navigation.dart`
- **Issue**: Uses both `go_router` (mentioned in pubspec.yaml) and `MaterialPageRoute` inconsistently
- **Example**: MainNavigation uses IndexedStack with manual state, but other screens use `Navigator.push(MaterialPageRoute(...))`
- **Recommendation**: Standardize on one navigation approach for consistency

### State Management Inconsistencies
- Riverpod providers are spread across feature directories
- Some providers use `FutureProvider.autoDispose` while others may use different patterns
- No clear convention for when to use which provider type

### Missing Feature Implementation
- Drift (SQLite) is listed as a dependency but not visibly implemented in the codebase
- `lib/core/` directory was planned but not fully implemented per CLAUDE.md

## Code Quality Issues

### TODO Items Not Completed
The following TODO comments were found in the codebase:

| File | Line | Description |
|------|------|-------------|
| `lib/core/presentation/main_navigation.dart` | 61 | `// TODO: Abrir notificações` |
| `lib/features/auth/presentation/login_screen.dart` | 141 | `// TODO: Implementar reset de senha` |
| `lib/features/dashboard/presentation/home_screen.dart` | 254 | `// TODO: Implementar navegação para nova comanda` |
| `lib/features/dashboard/presentation/home_screen.dart` | 265 | `// TODO: Implementar navegação para agenda` |
| `lib/features/dashboard/presentation/home_screen.dart` | 276 | `// TODO: Implementar visualização de clientes em espera` |
| `lib/features/dashboard/presentation/home_screen.dart` | 287 | `// TODO: Implementar geração de relatório` |

### Incomplete Error Handling
- Many providers and screens catch general `Exception` types without specific handling
- Error states show raw error messages to users rather than user-friendly messages
- No retry logic for failed network requests

### Missing Input Validation
- `create_service_screen.dart`: Price parsing with `double.tryParse` defaults to 0.0 silently
- `create_appointment_screen.dart`: No validation for negative prices or durations
- User inputs are not sanitized before database operations

## Dependency Concerns

### Outdated Package Versions
- Flutter SDK constraint: `^3.11.1` - Current stable is much newer (April 2026)
- No `flutter pub outdated` check has been run recently
- `go_router: ^17.1.0` - newer versions available with breaking changes

### Vulnerable Transitive Dependencies
- No lock file auditing for known CVEs
- `sqlite3_flutter_libs: ^0.6.0+eol` - marked as end-of-life

### Build Runner Not Automated
- Drift code generation requires manual `flutter pub run build_runner build`
- No pre-commit hook to ensure generated files are up-to-date

## Configuration Problems

### Environment Configuration
- No `.env` file support or environment variable loading
- All configuration is hardcoded
- No distinction between dev/staging/prod environments

### Analysis Options Too Lenient
- `analysis_options.yaml` has relaxed rules for test files but not for main code
- `unused_import`, `unused_element`, `unused_local_variable` set to `warning` rather than `error`
- This allows code quality issues to accumulate

## Missing Infrastructure

### No Error Monitoring/Reporting
- No crash reporting service (e.g., Sentry)
- No analytics for tracking user behavior
- No network error logging

### No Offline Support
- Drift is configured but not actively used
- No local data caching for offline operation
- Users must be online for all operations

### No Backup/Recovery
- No database backup strategy
- No data export functionality
- No disaster recovery plan

## UI/UX Issues

### Hardcoded Colors
- `Color(0xFF1E1E1E)` used directly in multiple places instead of theme tokens
- `Color(0xFF121212)` also hardcoded in navigation
- Theme colors not centralized

### Loading States
- Some screens use `CircularProgressIndicator` while others may not
- No skeleton loading UI
- No distinction between loading, error, and empty states in some providers

### Responsive Design
- Login screen has `maxWidth: 400` constraint but other screens may not
- No tablet-specific layouts
- Bottom navigation may not work well on larger screens

## Testing Gaps

### Tests Exist But Coverage Unknown
- Test infrastructure exists (`test/barberos_widget_test.dart`, `test/barberos_unit_test.dart`)
- No recent coverage report
- Integration tests may be incomplete

### Mock Data Not Centralized
- `test/test_config.dart` has TestData but may not cover all scenarios

## Database Concerns

### RLS Policy Complexity
- SQL file `supabase_rls_fix.sql` has dynamic policy dropping with `DO $$` blocks
- Hard to audit which policies are actually in place
- No version control for database schema

### No Database Migration Strategy
- Schema changes require manual SQL execution
- No migration scripts or version tracking
- Changes to RLS must be applied manually per CLAUDE.md

### Potential N+1 Query Issues
- `appointmentsProvider` fetches orders with nested `barbers(id, users(name))`
- Multiple providers make sequential database calls without batching
- No query optimization or caching layer

## Performance Concerns

### Unbounded FutureProvider Usage
- Providers like `userProfileProvider` make multiple sequential queries
- No request deduplication
- Each widget that watches a provider creates a new request on rebuild

### Missing Pagination
- `servicesProvider`, `employeesProvider` fetch ALL records without pagination
- No limit/offset on queries
- Large datasets will cause memory issues

### No Image Optimization
- If service images or client photos are used, no caching/resizing strategy
- No thumbnail generation

## Documentation Debt

### Missing API Documentation
- No OpenAPI/Swagger specs
- Supabase REST API used implicitly
- No clear contract for expected responses

### Code Comments in Portuguese
- While consistent for this project, may hinder international contributions
- Some comments are sparse (e.g., `// NOVO:` tags suggest iterative development without cleanup)

### No Architecture Decision Records (ADRs)
- Key decisions (e.g., going_router vs Navigator 2.0) not documented
- No record of why certain packages were chosen

## Refactoring Opportunities

### Duplicate Code Patterns
- Multiple screens have similar scaffold/body patterns
- Error handling SnackBars are repeated
- No shared widget library for common components

### Provider Structure Could Be Improved
- Large providers do multiple things (e.g., `userProfileProvider` gets user data AND barber data)
- Could be split into more focused providers

### String Management
- All strings are hardcoded in UI
- No i18n support despite being a single-language app currently
- Hard to maintain if multilingual support is needed

---

*Document generated from codebase analysis - April 2026*