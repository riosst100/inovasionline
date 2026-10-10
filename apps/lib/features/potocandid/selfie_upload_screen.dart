import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import 'potocandid_providers.dart';

class SelfieUploadScreen extends ConsumerStatefulWidget {
  const SelfieUploadScreen({super.key});

  @override
  ConsumerState<SelfieUploadScreen> createState() => _SelfieUploadScreenState();
}

class _SelfieUploadScreenState extends ConsumerState<SelfieUploadScreen> {
  final _picker = ImagePicker();
  File? _croppedSelfie;

  Future<void> _pickAndCropSelfie() async {
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
          toolbarTitle: 'Sesuaikan Selfie',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Sesuaikan Selfie',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (cropped == null) return;
    setState(() => _croppedSelfie = File(cropped.path));
  }

  Future<void> _submit() async {
    if (_croppedSelfie == null) return;
    await ref.read(potoCandidProvider.notifier).uploadSelfie(_croppedSelfie!);

    if (!mounted) return;
    final status = ref.read(potoCandidProvider).selfieUploadStatus;
    if (status == SelfieUploadStatus.success) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(potoCandidProvider);
    final uploading = state.selfieUploadStatus == SelfieUploadStatus.uploading;

    return Scaffold(
      appBar: AppBar(title: const Text('Unggah Selfie')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'Unggah foto wajahmu sekali saja, dan kami akan carikan foto-fotomu di setiap acara secara otomatis.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickAndCropSelfie,
                child: CircleAvatar(
                  radius: 90,
                  backgroundColor: AppColors.surface,
                  backgroundImage: _croppedSelfie != null ? FileImage(_croppedSelfie!) : null,
                  child: _croppedSelfie == null
                      ? const Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.mutedForeground)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _pickAndCropSelfie,
                child: Text(_croppedSelfie == null ? 'Pilih Foto' : 'Ganti Foto'),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 8),
                Text(state.error!, style: const TextStyle(color: AppColors.destructive), textAlign: TextAlign.center),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _croppedSelfie == null || uploading ? null : _submit,
                  child: uploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Unggah'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
