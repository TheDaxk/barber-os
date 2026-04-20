import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_os/features/auth/presentation/login_screen.dart';
import 'package:barber_os/core/presentation/main_navigation.dart';
import 'package:barber_os/core/theme/app_theme.dart';

const supabaseUrl = 'https://akqvqyiyhyuzrnvpvfxt.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFrcXZxeWl5aHl1enJudnB2Znh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNjE1NzMsImV4cCI6MjA4OTkzNzU3M30.6cgh-3c9BuuTRCxHeOi937YAYhNW8dDWy6jezBHGRJA';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: BarberOSApp(),
    ),
  );
}

class BarberOSApp extends StatelessWidget {
  const BarberOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _AuthGate(),
    );
  }
}

/// Widget que decide se o usuário vai para Login ou para o app principal
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Pequeno delay para garantir que o Supabase terminou de restaurar a sessão
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // Sessão válida → vai direto para o app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MainNavigation()),
      );
    } else {
      // Sem sessão → vai para login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tela de splash enquanto verifica a sessão
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cut_rounded, size: 64, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'BarberOS',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}