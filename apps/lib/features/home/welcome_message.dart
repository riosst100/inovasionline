import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WelcomeType { register, login, logout }

class WelcomeMessage {
  const WelcomeMessage({this.name, this.type = WelcomeType.register});

  final String? name;
  final WelcomeType type;

  String get text {
    final greeting = name != null && name!.isNotEmpty ? ', $name' : '';
    return switch (type) {
      WelcomeType.register => 'Pendaftaran berhasil! Selamat datang$greeting 🎉',
      WelcomeType.login => 'Berhasil masuk. Selamat datang kembali$greeting!',
      WelcomeType.logout => 'Berhasil keluar. Sampai jumpa lagi$greeting!',
    };
  }
}

/// Set right before navigating to home after a successful login/register.
/// HomeScreen consumes and clears it via ref.listen (survives shell-branch
/// state preservation, unlike a route `extra` + initState).
final pendingWelcomeProvider = StateProvider<WelcomeMessage?>((ref) => null);
