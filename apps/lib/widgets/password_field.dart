import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.decoration,
    this.validator,
    this.autofillHints,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: _obscure ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
