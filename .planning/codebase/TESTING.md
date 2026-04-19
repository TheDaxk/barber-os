# Testing Infrastructure - BarberOS

This document describes the testing infrastructure, tools, and patterns used in the BarberOS Flutter project.

## Test Framework and Tools

### Dependencies
The project uses the following testing dependencies (from `pubspec.yaml`):

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  test: ^1.24.0
```

- **flutter_test**: Flutter's built-in testing framework
- **mockito**: Mocking library for creating mocks (not yet heavily used)
- **test**: Extended testing package for advanced features

### Test Runner
```bash
flutter test                    # Run all tests
flutter test --coverage         # Run with code coverage
flutter test test/file.dart     # Run specific file
flutter analyze                 # Static analysis
```

## Test File Locations and Naming

### Main Test Directory
```
test/
├── barberos_widget_test.dart          # Widget tests
├── barberos_unit_test.dart            # Unit tests
├── barberos_integration_test.dart     # Integration tests
├── test_config.dart                   # Test helpers and mock data
├── widget_test.dart                   # Original template test
└── unit/                              # Additional unit tests (directory)
```

### File Naming Conventions
- Widget tests: `barberos_widget_test.dart`
- Unit tests: `barberos_unit_test.dart`
- Integration tests: `barberos_integration_test.dart`
- Test configuration: `test_config.dart`

## Types of Tests Implemented

### 1. Widget Tests
Widget tests verify UI components in isolation.

**Location**: `test/barberos_widget_test.dart`

**Scope**:
- Verifies UI elements are present (text, icons, buttons)
- Tests navigation components
- Validates theme configuration
- Tests user interactions (tap, scroll)

**Example**:
```dart
testWidgets('App inicia na tela de login', (WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));
  expect(find.text('BarberOS'), findsOneWidget);
  expect(find.text('Acesse sua unidade'), findsOneWidget);
  expect(find.byType(LoginScreen), findsOneWidget);
});

testWidgets('Tela de login tem campos de email e senha', (WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  expect(find.text('E-mail'), findsOneWidget);
  expect(find.text('Senha'), findsOneWidget);
  expect(find.byType(TextField), findsNWidgets(2));
  expect(find.text('Entrar'), findsOneWidget);
});
```

### 2. Unit Tests
Unit tests verify business logic in isolation.

**Location**: `test/barberos_unit_test.dart`

**Scope**:
- Validation functions (email, password)
- Data formatting (currency, capitalization)
- Business logic (role checking)
- Provider logic (mocked)

**Example**:
```dart
test('Verificação de role de líder funciona corretamente', () {
  final userLeader = {'category': 'Barbeiro Líder', 'role': 'barber'};
  bool isLeader = userLeader['category'] == 'Barbeiro Líder' || userLeader['role'] == 'admin';
  expect(isLeader, isTrue);
});

test('Validação de email simples', () {
  bool isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }
  expect(isValidEmail('usuario@exemplo.com'), isTrue);
  expect(isValidEmail('usuario@exemplo'), isFalse);
});
```

### 3. Integration Tests
Integration tests verify complete user flows.

**Location**: `test/barberos_integration_test.dart`

**Scope**:
- Complete app initialization flow
- Navigation between screens
- Form filling and submission
- Responsive layout testing
- Accessibility verification

**Example**:
```dart
testWidgets('Fluxo completo de inicialização do app', (WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));
  expect(find.text('BarberOS'), findsOneWidget);
  expect(find.byType(LoginScreen), findsOneWidget);
  expect(find.text('E-mail'), findsOneWidget);
  await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'teste@exemplo.com');
  await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
  expect(find.text('teste@exemplo.com'), findsOneWidget);
});
```

## Test Helpers and Utilities

### Location
`test/test_config.dart`

### TestData Class
Provides mock data for tests:

```dart
class TestData {
  // User types
  static const validEmail = 'teste@barberos.com';
  static const validPassword = 'senha123';
  static const invalidEmail = 'email-invalido';
  static const shortPassword = '123';

  // User mocks
  static Map<String, dynamic> get regularUser => {
    'id': 'user-123',
    'email': 'barbeiro@exemplo.com',
    'name': 'João Silva',
    'unit_id': 'unit-001',
    'role': 'barber',
    'category': 'barber',
  };

  static Map<String, dynamic> get leaderUser => {
    'id': 'user-456',
    'email': 'lider@exemplo.com',
    'name': 'Maria Santos',
    'role': 'barber',
    'category': 'Barbeiro Líder',
  };

  static Map<String, dynamic> get adminUser => {
    'id': 'user-789',
    'email': 'admin@exemplo.com',
    'name': 'Admin Sistema',
    'role': 'admin',
    'category': 'Gestor',
  };

  // Service mocks
  static List<Map<String, dynamic>> get sampleServices => [
    {'id': 'service-1', 'name': 'Corte de Cabelo', 'price': 35.00, 'duration': 30, 'is_active': true},
    {'id': 'service-2', 'name': 'Barba', 'price': 25.00, 'duration': 20, 'is_active': true},
  ];

  // Barber mocks
  static List<Map<String, dynamic>> get sampleBarbers => [
    {'id': 'barber-1', 'user_id': 'user-123', 'category': 'barber', 'is_active': true, 'users': {'name': 'João Silva'}},
    {'id': 'barber-2', 'user_id': 'user-456', 'category': 'Barbeiro Líder', 'is_active': true, 'users': {'name': 'Maria Santos'}},
  ];
}
```

### TestConstants Class
```dart
class TestConstants {
  static const testTimeout = Duration(seconds: 30);
}
```

### Helper Functions

**`setupTestEnvironment()`**: Initializes test environment
```dart
void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
}
```

**`createTestableWidget(child)`**: Creates MaterialApp wrapper
```dart
Widget createTestableWidget(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
```

**`waitForWidget(tester, finder, timeout)`**: Waits for widget to appear
```dart
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final endTime = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw Exception('Widget não encontrado: $finder');
}
```

**`safeTap(tester, finder)`**: Safe tap with existence check
```dart
Future<void> safeTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.tap(finder);
    await tester.pump();
  } else {
    throw Exception('Não foi possível tocar no widget: $finder');
  }
}
```

**`findTextWithStyle(text, style)`**: Finds text with specific style
```dart
Finder findTextWithStyle(String text, {TextStyle? style}) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is Text) {
        final matchesText = widget.data == text;
        final matchesStyle = style == null || widget.style == style;
        return matchesText && matchesStyle;
      }
      return false;
    },
  );
}
```

## Automation Scripts

### Windows: `run_tests.bat`
Windows batch script for running tests.

**Usage**:
```cmd
run_tests.bat              # Run all tests
run_tests.bat widget       # Widget tests only
run_tests.bat unit         # Unit tests only
run_tests.bat integration   # Integration tests only
run_tests.bat coverage     # Tests with coverage
run_tests.bat analyze      # Static analysis
run_tests.bat clean        # Clean project and rebuild
```

**Features**:
- Checks Flutter installation
- Runs `flutter pub get` to ensure dependencies
- Runs `build_runner` if needed (for Drift code generation)
- Displays results with success/failure indicators

### Unix/Linux/macOS: `run_tests.sh`
Bash script for running tests on Unix-like systems.

**Usage**:
```bash
./run_tests.sh              # Run all tests
./run_tests.sh widget        # Widget tests only
./run_tests.sh unit          # Unit tests only
./run_tests.sh integration   # Integration tests only
./run_tests.sh coverage      # Tests with coverage + HTML report
./run_tests.sh analyze       # Static analysis
./run_tests.sh clean         # Clean project and rebuild
./run_tests.sh help          # Show help
```

**Features**:
- Colored output (red/green/yellow/blue)
- Environment validation
- HTML coverage report generation (if lcov/genhtml available)
- Comprehensive help system

### Key Script Functions
- `check_flutter()`: Verifies Flutter is installed
- `prepare_environment()`: Runs pub get and build_runner
- `run_all_tests()`: Executes all tests
- `run_widget_tests()`: Executes widget tests only
- `run_unit_tests()`: Executes unit tests only
- `run_integration_tests()`: Executes integration tests only
- `run_coverage_tests()`: Runs with coverage and generates HTML report
- `run_analyze()`: Runs static analysis
- `clean_project()`: Cleans build artifacts and reinstalls dependencies

## Coverage Approach

### Running with Coverage
```bash
flutter test --coverage
```

### Coverage Output
- Coverage data generated in `coverage/lcov.info`
- Excludes generated files: `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`

### HTML Report Generation (Unix/Linux/macOS)
```bash
# If lcov and genhtml are installed
genhtml coverage/lcov.info -o coverage/html
# View at coverage/html/index.html
```

### Windows HTML Report
```cmd
# Install lcov via winget or choco, then:
genhtml coverage\lcov.info -o coverage\html
```

## Analysis Configuration

### `analysis_options.yaml` Test Configuration

```yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.mocks.dart"
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    unused_import: warning
    unused_element: warning
    unused_local_variable: warning

linter:
  rules:
    avoid_print: false
    prefer_const_constructors: true
    prefer_final_locals: true
    public_member_api_docs: false
    lines_longer_than_80_chars: false
    avoid_redundant_argument_values: false
    test_types_in_equals: true
    tighten_type_of_initializing_formals: true
    use_string_buffers: true
    valid_regexps: true
```

### Key Settings
- **Strict mode**: Enabled for casts, inference, and raw types
- **Warnings relaxed**: Unused imports/elements/variables are warnings only
- **Test-specific rules**: Relaxed line length, no API docs requirement
- **Generated files excluded**: Prevents noise from build_runner output

## Common Test Patterns

### Grouping Tests
```dart
group('LoginScreen', () {
  testWidgets('tem campos de email e senha', ...);
  testWidgets('valida email correto', ...);
  testWidgets('mostra loading durante login', ...);
});
```

### Testing with Riverpod
```dart
await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));
// ProviderScope provides Riverpod context
```

### Testing Theme
```dart
final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
expect(materialApp.theme!.brightness, Brightness.dark);
expect(materialApp.theme!.useMaterial3, isTrue);
```

### Testing Navigation
```dart
await tester.pumpWidget(const MaterialApp(home: MainNavigation()));
await tester.pump();
expect(find.text('Início'), findsOneWidget);
expect(find.byIcon(Icons.home), findsOneWidget);
```

### Testing Text Input
```dart
await tester.enterText(find.widgetWithText(TextField, 'E-mail'), 'test@email.com');
await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'senha123');
expect(find.text('test@email.com'), findsOneWidget);
```

### Testing Button State
```dart
final buttonFinder = find.byType(ElevatedButton);
final button = tester.widget<ElevatedButton>(buttonFinder);
expect(button.enabled, isTrue);
```

### Testing Responsive Layout
```dart
tester.binding.window.physicalSizeTestValue = const Size(360, 640);
tester.binding.window.devicePixelRatioTestValue = 1.0;
addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
```

## Test Execution Examples

### Run All Tests
```bash
flutter test
```

### Run Specific Test Type
```bash
flutter test test/barberos_widget_test.dart
flutter test test/barberos_unit_test.dart
flutter test test/barberos_integration_test.dart
```

### Run with Coverage
```bash
flutter test --coverage
```

### Run with Verbose Output
```bash
flutter test -v
flutter test test/barberos_widget_test.dart -v --plain-name "App inicia na tela de login"
```

### Clean and Test
```bash
flutter clean && flutter test
```

## Future Testing Improvements

### Planned Enhancements
1. **Supabase Mocks**: Create mock SupabaseClient for provider testing
2. **More Provider Tests**: Test providers with mocked dependencies
3. **Navigation Tests**: Test go_router navigation flows
4. **Snapshot Tests**: Add golden tests for UI consistency
5. **Performance Tests**: Add benchmark tests for expensive operations

### Testing Best Practices
1. Keep tests independent - no shared state between tests
2. Use descriptive test names in Portuguese
3. Use `group()` to organize related tests
4. Use `setUp()` and `tearDown()` for resource management
5. Clean up test environment after each test
6. Follow existing naming conventions for mock data

## Troubleshooting

### Common Issues
1. **"No tests found"**: Verify tests are in `test/` directory with `test` or `testWidgets` prefix
2. **Slow tests**: Use `pump()` instead of `pumpAndSettle()` when possible
3. **Widget not found**: Use `await tester.pump()` to ensure rendering
4. **Import errors**: Run `flutter pub get` before testing

### Debug Tips
- Use `flutter test -v` for verbose output
- Use `await tester.pump()` to step through animations
- Use `print()` statements (allowed via `avoid_print: false`)
- Check `analysis_options.yaml` for exclusions if generated files cause issues