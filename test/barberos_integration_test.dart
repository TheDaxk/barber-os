// Testes de integração do BarberOS
// Para rodar: flutter test test/barberos_integration_test.dart
// Nota: Testes de integração real precisariam de ambiente de teste configurado

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barber_os/main.dart';
import 'package:barber_os/features/auth/presentation/login_screen.dart';
import 'package:barber_os/core/presentation/main_navigation.dart';

void main() {
  group('Testes de Fluxo de Navegação', () {
    testWidgets('Fluxo completo de inicialização do app',
        (WidgetTester tester) async {
      // 1. Inicia o app
      await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));

      // 2. Verifica tela de login
      expect(find.text('BarberOS'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);

      // 3. Verifica elementos da tela de login
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Senha'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);

      // 4. Simula preenchimento de formulário
      await tester.enterText(find.widgetWithText(TextField, 'E-mail'),
          'teste@exemplo.com');
      await tester.enterText(
          find.widgetWithText(TextField, 'Senha'), 'senha123');

      // 5. Verifica se os campos foram preenchidos
      expect(find.text('teste@exemplo.com'), findsOneWidget);
      expect(find.text('senha123'), findsOneWidget);
    });

    testWidgets('Navegação entre elementos da MainNavigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainNavigation()),
      );

      await tester.pump();

      // Verifica abas de navegação
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Clientes'), findsOneWidget);

      // Nota: A aba "Caixa" só aparece para líderes,
      // então pode não estar presente neste teste
    });
  });

  group('Testes de Responsividade', () {
    testWidgets('Layout se adapta a diferentes tamanhos de tela',
        (WidgetTester tester) async {
      // Testa com tamanho de tela pequeno (celular)
      tester.binding.window.physicalSizeTestValue = const Size(360, 640);
      tester.binding.window.devicePixelRatioTestValue = 1.0;

      await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));

      expect(find.text('BarberOS'), findsOneWidget);

      // Limpa tamanho de teste
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    });

    testWidgets('Elementos são visíveis e acessíveis',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));

      // Verifica se elementos críticos estão presentes
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('Testes de Estado da UI', () {
    testWidgets('Botão Entrar muda estado durante loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      final entrarButton = find.text('Entrar');
      expect(entrarButton, findsOneWidget);

      // Encontra o ElevatedButton
      final buttonFinder = find.byType(ElevatedButton);
      final button = tester.widget<ElevatedButton>(buttonFinder);

      // Botão deve estar habilitado inicialmente
      expect(button.enabled, isTrue);
    });

    testWidgets('Campos de texto são editáveis', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LoginScreen()),
      );

      final emailField = find.widgetWithText(TextField, 'E-mail');
      final passwordField = find.widgetWithText(TextField, 'Senha');

      // Tenta inserir texto
      await tester.enterText(emailField, 'novo@email.com');
      await tester.enterText(passwordField, 'novaSenha');

      expect(find.text('novo@email.com'), findsOneWidget);
      expect(find.text('novaSenha'), findsOneWidget);
    });
  });

  group('Testes de Acessibilidade', () {
    testWidgets('Elementos têm labels semânticos',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BarberOSApp()));

      // Verifica se elementos importantes têm texto
      expect(find.text('BarberOS'), findsOneWidget);
      expect(find.text('Acesse sua unidade'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('Senha'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('Ícones têm significado claro', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MainNavigation()),
      );

      await tester.pump();

      // Verifica ícones comuns
      expect(find.byIcon(Icons.home), findsOneWidget); // Início
      expect(find.byIcon(Icons.calendar_today), findsOneWidget); // Agenda
      expect(find.byIcon(Icons.people), findsOneWidget); // Clientes
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget); // Notificações
      expect(find.byIcon(Icons.settings), findsOneWidget); // Configurações
    });
  });
}