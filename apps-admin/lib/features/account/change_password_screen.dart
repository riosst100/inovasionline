import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../../widgets/common.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authServiceProvider)
          .changePassword(currentPassword: _current.text, newPassword: _new.text, confirmation: _confirm.text);
      if (!mounted) return;
      showMessage(context, 'Kata sandi berhasil diubah.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    prefixIcon: const Icon(Icons.lock_outline),
    suffixIcon: IconButton(
      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => setState(() => _obscure = !_obscure),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Kata Sandi')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                decoration: _decoration('Kata sandi saat ini'),
                validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _new,
                obscureText: _obscure,
                decoration: _decoration('Kata sandi baru'),
                validator: (v) => (v == null || v.length < 8) ? 'Minimal 8 karakter.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: _decoration('Ulangi kata sandi baru'),
                validator: (v) => v != _new.text ? 'Kata sandi tidak sama.' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
