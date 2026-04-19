// Testes de widget do BarberOS
// Para rodar: flutter test test/barberos_widget_test.dart

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

    testWidgets('Botão Entrar está presente', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      final entrarButton = find.text('Entrar');
      expect(entrarButton, findsOneWidget);
    });

    testWidgets('LoginScreen tem ícone de barbearia',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      expect(find.byIcon(Icons.cut_rounded), findsOneWidget);
    });
  });

  group('Testes de Navegação', () {
    testWidgets('MainNavigation mostra título BarberOS',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainNavigation()),
      );

      // Aguarda loading inicial
      await tester.pump();

      // Verifica título
      expect(find.text('BarberOS'), findsOneWidget);
    });

    testWidgets('MainNavigation tem ícone de notificações',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainNavigation()),
      );

      await tester.pump();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('MainNavigation tem ícone de configurações',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainNavigation()),
      );

      await tester.pump();

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('Testes de Tema', () {
    testWidgets('App usa tema escuro', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final theme = materialApp.theme;

      expect(theme, isNotNull);
      expect(theme!.brightness, Brightness.dark);
    });

    testWidgets('Tema usa Material 3', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final theme = materialApp.theme;

      expect(theme!.useMaterial3, isTrue);
    });
  });
}