import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/address_picker.dart';

class CompleteAddressScreen extends ConsumerStatefulWidget {
  const CompleteAddressScreen({super.key});

  @override
  ConsumerState<CompleteAddressScreen> createState() => _CompleteAddressScreenState();
}

class _CompleteAddressScreenState extends ConsumerState<CompleteAddressScreen> {
  AddressSelection _address = const AddressSelection();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_address.isComplete) {
      setState(() => _error = 'Alamat wajib dipilih lengkap.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await ref.read(authProvider.notifier).updateAddress(
          provinceCode: _address.province!.code,
          cityCode: _address.city!.code,
          districtCode: _address.district!.code,
          villageCode: _address.village!.code,
        );

    if (!mounted) return;

    setState(() => _loading = false);

    if (success) {
      context.go('/');
    } else {
      setState(() => _error = ref.read(authProvider).error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lengkapi Alamat'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sebelum melanjutkan, lengkapi alamat Anda untuk mengakses fitur chat wilayah.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ),
                const SizedBox(height: 16),
              ],
              AddressPicker(onChanged: (address) => setState(() => _address = address)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
