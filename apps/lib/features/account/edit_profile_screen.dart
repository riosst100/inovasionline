import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _picker = ImagePicker();

  File? _croppedAvatar;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropAvatar() async {
    final picked = await showModalBottomSheet<XFile>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil Foto'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
                if (context.mounted) Navigator.of(context).pop(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
                if (context.mounted) Navigator.of(context).pop(file);
              },
            ),
          ],
        ),
      ),
    );

    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan Foto Profil',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Sesuaikan Foto Profil',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (cropped == null) return;
    setState(() => _croppedAvatar = File(cropped.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final success = await ref.read(authProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          avatar: _croppedAvatar,
        );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _submitting = false;
        _error = ref.read(authProvider).error ?? 'Gagal memperbarui profil.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: AppColors.destructive, fontSize: 13)),
              ),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: AppColors.surface,
                    backgroundImage: _croppedAvatar != null
                        ? FileImage(_croppedAvatar!)
                        : (user?.avatarUrl != null ? CachedNetworkImageProvider(user!.avatarUrl!) : null)
                            as ImageProvider?,
                    child: _croppedAvatar == null && user?.avatarUrl == null
                        ? const Icon(Icons.person_outline, size: 44, color: AppColors.mutedForeground)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: _pickAndCropAvatar,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                        ),
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor Telepon'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Nomor telepon wajib diisi' : null,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }
}
