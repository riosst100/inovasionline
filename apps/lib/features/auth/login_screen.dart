import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/password_field.dart';
import '../home/welcome_message.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await ref
        .read(authProvider.notifier)
        .login(
          login: _loginController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    setState(() => _loading = false);

    if (success) {
      final name = ref.read(authProvider).user?.name;
      ref.read(pendingWelcomeProvider.notifier).state = WelcomeMessage(
        name: name,
        type: WelcomeType.login,
      );
      context.go('/');
    } else {
      setState(() => _error = ref.read(authProvider).error);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await ref.read(authProvider.notifier).loginWithGoogle();

      if (!mounted) return;

      if (success) {
        final name = ref.read(authProvider).user?.name;
        ref.read(pendingWelcomeProvider.notifier).state = WelcomeMessage(
          name: name,
          type: WelcomeType.login,
        );
        context.go('/');
      } else {
        final error = ref.read(authProvider).error;
        if (error != null) setState(() => _error = error);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal masuk dengan Google: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Image.asset('assets/images/logo_app.png', height: 80),
                  const SizedBox(height: 16),
                  Text(
                    'Masuk',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selamat datang kembali di Inovasi Online',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _loginController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Email atau Nomor HP',
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Email atau nomor HP wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Kata Sandi'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Kata sandi wajib diisi'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push('/account/forgot-password'),
                      child: const Text('Lupa kata sandi?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Masuk'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'atau',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _submitGoogle,
                    icon: Image.asset(
                      'assets/images/logo_google.webp',
                      height: 20,
                      width: 20,
                    ),
                    label: const Text('Masuk dengan Google'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Belum punya akun?'),
                      TextButton(
                        onPressed: () => context.push('/account/register'),
                        child: const Text('Daftar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
