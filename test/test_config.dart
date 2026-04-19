// Configuração de testes do BarberOS
// Este arquivo contém configurações e helpers para testes

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configura o ambiente de testes
void setupTestEnvironment() {
  // Configurações globais de testes podem ser adicionadas aqui
  TestWidgetsFlutterBinding.ensureInitialized();
}

/// Cria um MaterialApp wrapper para testes de widgets
Widget createTestableWidget(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

/// Cria um ProviderScope wrapper para testes com Riverpod
Widget createTestableWidgetWithProviders(Widget child) {
  return MaterialApp(
    home: child,
  );
}

/// Helpers para testes comuns

/// Aguarda até que um widget específico apareça
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final endTime = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  throw Exception('Widget não encontrado: $finder');
}

/// Simula um tap seguro (verifica se o widget existe)
Future<void> safeTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.tap(finder);
    await tester.pump();
  } else {
    throw Exception('Não foi possível tocar no widget: $finder');
  }
}

/// Verifica se um texto está presente com formatação específica
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
    description: 'Text "$text"${style != null ? ' com estilo específico' : ''}',
  );
}

/// Mock data para testes
class TestData {
  static const validEmail = 'teste@barberos.com';
  static const validPassword = 'senha123';
  static const invalidEmail = 'email-invalido';
  static const shortPassword = '123';

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
        'unit_id': 'unit-001',
        'role': 'barber',
        'category': 'Barbeiro Líder',
      };

  static Map<String, dynamic> get adminUser => {
        'id': 'user-789',
        'email': 'admin@exemplo.com',
        'name': 'Admin Sistema',
        'unit_id': 'unit-001',
        'role': 'admin',
        'category': 'Gestor',
      };

  static List<Map<String, dynamic>> get sampleServices => [
        {
          'id': 'service-1',
          'name': 'Corte de Cabelo',
          'price': 35.00,
          'duration': 30,
          'is_active': true,
        },
        {
          'id': 'service-2',
          'name': 'Barba',
          'price': 25.00,
          'duration': 20,
          'is_active': true,
        },
        {
          'id': 'service-3',
          'name': 'Corte + Barba',
          'price': 50.00,
          'duration': 45,
          'is_active': true,
        },
      ];

  static List<Map<String, dynamic>> get sampleBarbers => [
        {
          'id': 'barber-1',
          'user_id': 'user-123',
          'category': 'barber',
          'is_active': true,
          'users': {'name': 'João Silva'},
        },
        {
          'id': 'barber-2',
          'user_id': 'user-456',
          'category': 'Barbeiro Líder',
          'is_active': true,
          'users': {'name': 'Maria Santos'},
        },
      ];
}

/// Constantes de teste
class TestConstants {
  static const testTimeout = Duration(seconds: 30);
  static const pumpDuration = Duration(milliseconds: 100);
  static const smallScreenSize = Size(360, 640);
  static const mediumScreenSize = Size(768, 1024);
  static const largeScreenSize = Size(1920, 1080);
}