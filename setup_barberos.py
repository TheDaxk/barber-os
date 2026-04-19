import os

# 1. Definindo a estrutura de pastas
pastas = [
    "lib/core/theme",
    "lib/core/router",
    "lib/core/database",
    "lib/core/supabase",
    "lib/core/utils",
    "lib/features/auth/presentation",
    "lib/features/dashboard/presentation",
    "lib/features/orders/presentation",
    "lib/features/barbers/presentation",
    "lib/features/reports/presentation",
]

# Criando as pastas
print("Criando estrutura de pastas...")
for pasta in pastas:
    os.makedirs(pasta, exist_ok=True)
    print(f"📁 Criada: {pasta}")

# 2. Código base para o main.dart
main_dart_codigo = """import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO: Substitua com suas credenciais do Supabase
const supabaseUrl = 'SUA_SUPABASE_URL';
const supabaseAnonKey = 'SUA_SUPABASE_ANON_KEY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    // Adicionando o ProviderScope para o Riverpod
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E1E1E), // Tom escuro base
          brightness: Brightness.dark, // Modo escuro nativo (Ideal para barbearias)
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('BarberOS - Inicializado com Sucesso!'),
        ),
      ),
    );
  }
}
"""

# Criando/Sobrescrevendo o main.dart
print("\\nGerando arquivo lib/main.dart...")
with open("lib/main.dart", "w", encoding="utf-8") as f:
    f.write(main_dart_codigo)

print("✅ Arquivo lib/main.dart criado com sucesso!")
print("🚀 Setup base concluído! Você já pode rodar 'flutter run'.")