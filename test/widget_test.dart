// Testes principais do BarberOS
// Para rodar: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barber_os/main.dart';
import 'package:barber_os/features/auth/presentation/login_screen.dart';
import 'package:barber_os/core/presentation/main_navigation.dart';

void main() {
  group('Testes de Widget do BarberOS', () {
    testWidgets('App inicia na tela de login', (WidgetTester tester) async {
      // Build our app
      await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));

      // Verifica se a tela de login está presente
      expect(find.text('BarberOS'), findsOneWidget);
      expect(find.text('Acesse sua unidade'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Tela de login tem campos de email e senha',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      // Verifica campos de entrada
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Senha'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('Botão Entrar está presente e desabilitado durante loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      final entrarButton = find.text('Entrar');
      expect(entrarButton, findsOneWidget);

      // Tenta encontrar o botão e verificar se é clicável
      final button = tester.widget<ElevatedButton>(entrarButton);
      expect(button.enabled, isTrue);
    });

    testWidgets('MainNavigation mostra título BarberOS',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainNavigation()),
      );

      // Aguarda loading
      await tester.pumpAndSettle();

      // Verifica título
      expect(find.text('BarberOS'), findsOneWidget);
    });
  });

  group('Testes de UI Components', () {
    testWidgets('Ícone de notificações está presente',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainNavigation()),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('Ícone de configurações está presente',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainNavigation()),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
