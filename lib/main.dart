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
      home: const LoginScreen(),
    );
  }
}