import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  final _supabase = Supabase.instance.client;

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira seu e-mail'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.resetPasswordForEmail(email);

      setState(() {
        _emailSent = true;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro inesperado. Tente novamente.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Recuperar Senha',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),

            // Ícone
            const Icon(
              Icons.lock_reset,
              size: 80,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 24),

            // Título
            const Text(
              'Esqueceu sua senha?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Descrição
            Text(
              _emailSent
                  ? 'Verifique sua caixa de entrada. Enviamos um link para redefinir sua senha.'
                  : 'Digite seu e-mail cadastrado. Você receberá um link para redefinir sua senha.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 48),

            if (!_emailSent) ...[
              // Campo de email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 24),

              // Botão enviar
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendResetEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Enviar Link de Recuperação',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ] else ...[
              // Confirmação de email enviado
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'E-mail enviado!',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verifique sua caixa de entrada em ${_emailController.text}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Voltar ao login
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Voltar ao Login',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
