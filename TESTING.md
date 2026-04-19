# Guia de Testes do BarberOS

Este documento descreve como executar e expandir os testes do projeto BarberOS.

## Estrutura de Testes

```
test/
├── widget_test.dart          # Teste original (template)
├── barberos_widget_test.dart # Testes de widget principais
├── barberos_unit_test.dart   # Testes unitários de lógica
├── barberos_integration_test.dart # Testes de integração
├── test_config.dart          # Configuração e helpers
└── TESTING.md                # Este guia
```

## Como Executar os Testes

### Executar todos os testes
```bash
flutter test
```

### Executar testes específicos
```bash
# Testes de widget
flutter test test/barberos_widget_test.dart

# Testes unitários
flutter test test/barberos_unit_test.dart

# Testes de integração
flutter test test/barberos_integration_test.dart
```

### Executar testes com cobertura
```bash
flutter test --coverage
```

### Gerar relatório de cobertura (após --coverage)
```bash
genhtml coverage/lcov.info -o coverage/html
```

## Tipos de Testes

### 1. Testes de Widget
Testam componentes de UI individualmente:
- Verificação de elementos visuais
- Interações do usuário (tap, scroll, etc.)
- Estados da UI (loading, error, success)

**Exemplo:**
```dart
testWidgets('Tela de login tem campos obrigatórios', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  expect(find.text('E-mail'), findsOneWidget);
  expect(find.text('Senha'), findsOneWidget);
});
```

### 2. Testes Unitários
Testam lógica de negócio isolada:
- Validações de formulário
- Transformações de dados
- Lógica de negócio pura

**Exemplo:**
```dart
test('Validação de email funciona corretamente', () {
  expect(isValidEmail('teste@exemplo.com'), isTrue);
  expect(isValidEmail('email-invalido'), isFalse);
});
```

### 3. Testes de Integração
Testam fluxos completos:
- Navegação entre telas
- Integração com providers
- Fluxos de usuário completos

**Exemplo:**
```dart
testWidgets('Fluxo completo de login e navegação', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));
  // ... preenche formulário, clica botão, verifica navegação
});
```

## Helpers de Teste

O arquivo `test_config.dart` contém helpers úteis:

### `TestData`
Dados mockados para testes:
- `TestData.regularUser`, `TestData.leaderUser`, `TestData.adminUser`
- `TestData.sampleServices`, `TestData.sampleBarbers`
- Credenciais de teste

### `TestConstants`
Constantes para configuração de testes:
- Timeouts, tamanhos de tela, durações

### Funções auxiliares
- `waitForWidget()`: Aguarda widget aparecer
- `safeTap()`: Tap seguro com verificação
- `createTestableWidget()`: Wrapper para testes

## Boas Práticas

### 1. Nomeação de Testes
```dart
// BOM
testWidgets('LoginScreen mostra erro quando email é inválido', ...)

// RUIM
testWidgets('Teste 1', ...)
```

### 2. Organização com `group`
```dart
group('LoginScreen', () {
  testWidgets('tem campos de email e senha', ...);
  testWidgets('valida email correto', ...);
  testWidgets('mostra loading durante login', ...);
});
```

### 3. Limpeza de Recursos
```dart
setUp(() {
  // Configuração antes de cada teste
});

tearDown(() {
  // Limpeza após cada teste
});
```

### 4. Testes Independentes
Cada teste deve ser independente e não depender do estado de outros testes.

## Testes Futuros a Implementar

### Testes com Mocks
```dart
// TODO: Implementar mocks para Supabase
test('userProfileProvider retorna dados do usuário', () async {
  // Precisa de mock do SupabaseClient
});
```

### Testes de Navegação Real
```dart
// TODO: Testar navegação real com go_router
testWidgets('Navegação para tela de agenda funciona', ...);
```

### Testes de Providers com Dependências
```dart
// TODO: Testar providers que dependem de serviços externos
test('servicesProvider filtra serviços inativos', ...);
```

## Troubleshooting

### Problemas Comuns

1. **"No tests found"**
   - Verifique se os testes estão no diretório `test/`
   - Verifique se as funções começam com `test` ou `testWidgets`

2. **Testes muito lentos**
   - Use `await tester.pumpAndSettle()` apenas quando necessário
   - Evite `sleep()` ou delays longos

3. **Widgets não encontrados**
   - Use `await tester.pump()` para renderizar widgets
   - Verifique se o widget está dentro da árvore correta

4. **Erros de dependências**
   - Execute `flutter pub get` antes de rodar testes
   - Verifique imports corretos

### Debugando Testes

```bash
# Executar testes com verbose
flutter test -v

# Executar teste específico com verbose
flutter test test/barberos_widget_test.dart -v --plain-name "App inicia na tela de login"
```

## Expansão de Testes

### Prioridades

1. **Alta Prioridade**
   - Testes de fluxo de autenticação
   - Testes de navegação principal
   - Testes de formulários críticos

2. **Média Prioridade**
   - Testes de providers com mocks
   - Testes de validação de dados
   - Testes de temas e estilos

3. **Baixa Prioridade**
   - Testes de edge cases
   - Testes de performance
   - Testes de acessibilidade avançados

### Adicionando Novos Testes

1. Identifique a funcionalidade a testar
2. Escolha o tipo de teste apropriado (widget/unit/integration)
3. Use dados mockados do `TestData` quando possível
4. Siga o padrão de nomeação existente
5. Execute os testes para garantir que passam

## Integração com CI/CD

Para integrar com pipelines de CI/CD:

```yaml
# Exemplo de configuração GitHub Actions
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
```

## Recursos Úteis

- [Documentação oficial de testes do Flutter](https://flutter.dev/docs/testing)
- [flutter_test package](https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html)
- [Riverpod testing](https://riverpod.dev/docs/essentials/testing)
- [Mockito para Dart](https://pub.dev/packages/mockito)