import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/password_field.dart';
import '../home/welcome_message.dart';

enum _RegisterStep { profile, account }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  _RegisterStep _step = _RegisterStep.profile;
  String? _gender;
  DateTime? _dateOfBirth;
  int? _dobDay;
  int? _dobMonth;
  int? _dobYear;

  bool _loading = false;
  String? _error;

  bool _otpSent = false;
  bool _phoneVerified = false;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _resendCooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  void _updateDateOfBirth() {
    if (_dobDay == null || _dobMonth == null || _dobYear == null) {
      setState(() => _dateOfBirth = null);
      return;
    }

    final daysInMonth = DateTime(_dobYear!, _dobMonth! + 1, 0).day;
    final day = _dobDay!.clamp(1, daysInMonth);
    setState(() => _dateOfBirth = DateTime(_dobYear!, _dobMonth!, day));
  }

  void _continueFromProfile() {
    if (!_profileFormKey.currentState!.validate()) return;
    if (_gender == null) {
      setState(() => _error = 'Jenis kelamin wajib dipilih.');
      return;
    }
    if (_dateOfBirth == null) {
      setState(() => _error = 'Tanggal lahir wajib diisi.');
      return;
    }
    setState(() {
      _error = null;
      _step = _RegisterStep.account;
    });
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();

    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Nomor telepon wajib diisi.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await ref
        .read(authProvider.notifier)
        .sendPhoneOtp(_phoneController.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      setState(() => _otpSent = true);
      _startCooldown();
    } else {
      setState(
        () => _error =
            ref.read(authProvider).error ?? 'Gagal mengirim kode verifikasi.',
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().length != 6) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await ref
        .read(authProvider.notifier)
        .verifyPhoneOtp(
          phone: _phoneController.text.trim(),
          code: _otpController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      setState(() => _phoneVerified = true);
    } else {
      setState(
        () => _error =
            ref.read(authProvider).error ??
            'Kode verifikasi salah atau kedaluwarsa.',
      );
    }
  }

  Future<void> _submit() async {
    if (!_accountFormKey.currentState!.validate()) return;

    if (!_phoneVerified) {
      setState(() => _error = 'Verifikasi nomor telepon terlebih dahulu.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await ref
        .read(authProvider.notifier)
        .register(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          gender: _gender!,
          dateOfBirth: DateFormat('yyyy-MM-dd').format(_dateOfBirth!),
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmController.text,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      final name = ref.read(authProvider).user?.name;
      ref.read(pendingWelcomeProvider.notifier).state = WelcomeMessage(
        name: name,
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

    final success = await ref.read(authProvider.notifier).loginWithGoogle();

    if (!mounted) return;

    setState(() => _loading = false);

    if (success) {
      final name = ref.read(authProvider).user?.name;
      ref.read(pendingWelcomeProvider.notifier).state = WelcomeMessage(
        name: name,
      );
      context.go('/');
    } else {
      final error = ref.read(authProvider).error;
      if (error != null) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar'),
        leading: _step == _RegisterStep.profile
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _error = null;
                  _step = _RegisterStep.profile;
                }),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepIndicator(step: _step),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
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
              switch (_step) {
                _RegisterStep.profile => _buildProfileStep(),
                _RegisterStep.account => _buildAccountStep(),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStep() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Nama wajib diisi' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Laki-laki')),
              DropdownMenuItem(value: 'female', child: Text('Perempuan')),
            ],
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tanggal Lahir',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _PickerField<int>(
                  label: 'Tanggal',
                  value: _dobDay,
                  display: (d) => '$d',
                  options: [for (var d = 1; d <= 31; d++) d],
                  onChanged: (value) {
                    setState(() => _dobDay = value);
                    _updateDateOfBirth();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PickerField<int>(
                  label: 'Bulan',
                  value: _dobMonth,
                  display: (m) =>
                      DateFormat('MMMM', 'id_ID').format(DateTime(2000, m)),
                  options: [for (var m = 1; m <= 12; m++) m],
                  onChanged: (value) {
                    setState(() => _dobMonth = value);
                    _updateDateOfBirth();
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PickerField<int>(
                  label: 'Tahun',
                  value: _dobYear,
                  display: (y) => '$y',
                  options: [
                    for (
                      var y = DateTime.now().year - 10;
                      y >= DateTime.now().year - 100;
                      y--
                    )
                      y,
                  ],
                  onChanged: (value) {
                    setState(() => _dobYear = value);
                    _updateDateOfBirth();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _continueFromProfile,
            child: const Text('Lanjut'),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('atau', style: TextStyle(color: Colors.grey)),
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
            label: const Text('Daftar dengan Google'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStep() {
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_otpSent,
            decoration: InputDecoration(
              labelText: 'Nomor Telepon (WhatsApp)',
              suffixIcon: _phoneVerified
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Nomor telepon wajib diisi'
                : null,
          ),
          const SizedBox(height: 16),
          if (!_phoneVerified) ...[
            if (!_otpSent)
              ElevatedButton(
                onPressed: _loading ? null : _sendOtp,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kirim Kode Verifikasi'),
              )
            else ...[
              Text(
                'Kami telah mengirim kode verifikasi 6 digit ke WhatsApp Anda.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Kode Verifikasi',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _verifyOtp,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verifikasi'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _resendCooldown > 0 || _loading ? null : _sendOtp,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Kirim ulang kode dalam ${_resendCooldown}s'
                        : 'Kirim ulang kode',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ] else ...[
            const Text(
              'Nomor telepon terverifikasi.',
              style: TextStyle(color: Colors.green),
            ),
            const SizedBox(height: 16),
          ],
          PasswordField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Kata Sandi',
              helperText:
                  'Minimal 8 karakter, kombinasi huruf besar, kecil, dan angka',
              helperMaxLines: 2,
            ),
            validator: (value) {
              if (value == null || value.length < 8)
                return 'Kata sandi minimal 8 karakter';
              if (!RegExp(r'[A-Z]').hasMatch(value))
                return 'Kata sandi harus mengandung huruf besar';
              if (!RegExp(r'[a-z]').hasMatch(value))
                return 'Kata sandi harus mengandung huruf kecil';
              if (!RegExp(r'[0-9]').hasMatch(value))
                return 'Kata sandi harus mengandung angka';
              return null;
            },
          ),
          const SizedBox(height: 16),
          PasswordField(
            controller: _passwordConfirmController,
            decoration: const InputDecoration(
              labelText: 'Konfirmasi Kata Sandi',
            ),
            validator: (value) => value != _passwordController.text
                ? 'Konfirmasi kata sandi tidak cocok'
                : null,
          ),
          const SizedBox(height: 24),
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
                : const Text('Daftar'),
          ),
        ],
      ),
    );
  }
}

class _PickerField<T> extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T) display;
  final ValueChanged<T> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected = option == value;
                    return ListTile(
                      title: Text(display(option)),
                      trailing: selected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      selected: selected,
                      onTap: () => Navigator.of(context).pop(option),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPicker(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 12,
          ),
        ),
        child: Text(
          value == null ? '' : display(value as T),
          style: const TextStyle(fontSize: 13, color: Colors.black),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final _RegisterStep step;

  static const _labels = ['Profil', 'Akun'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _RegisterStep.values.indexOf(step);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Divider(
                color: i ~/ 2 < currentIndex
                    ? Colors.blue
                    : Colors.grey.shade300,
                thickness: 2,
              ),
            ),
          );
        }
        final index = i ~/ 2;
        final done = index < currentIndex;
        final active = index == currentIndex;
        return Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: (done || active)
                  ? Colors.blue
                  : Colors.grey.shade300,
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              _labels[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: (done || active) ? Colors.blue : Colors.grey.shade500,
              ),
            ),
          ],
        );
      }),
    );
  }
}
