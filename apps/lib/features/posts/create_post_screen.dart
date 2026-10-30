import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import 'post_providers.dart';
import 'product_tag_picker_sheet.dart';

const _maxVideoDurationSeconds = 60;
const _maxVideoSizeBytes = 50 * 1024 * 1024;

/// Raw camera video can be far bigger than what we upload; it is compressed before the size check.
const _maxRawVideoSizeBytes = 300 * 1024 * 1024;

class _PickedVideo {
  _PickedVideo({required this.file, required this.thumbnail, required this.durationSeconds});

  final File file;
  final File? thumbnail;
  final int durationSeconds;
}

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _bodyController = TextEditingController();
  final _picker = ImagePicker();
  final List<File> _media = [];
  final List<Product> _taggedProducts = [];
  _PickedVideo? _video;
  VideoPlayerController? _videoController;
  bool _preparingVideo = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _bodyController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600, maxHeight: 1600, limit: 10 - _media.length);
    if (picked.isEmpty || !mounted) return;
    setState(() => _media.addAll(picked.map((x) => File(x.path))));
  }

  void _removeMedia(int index) {
    setState(() => _media.removeAt(index));
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 90));
    if (picked == null) return;

    var file = File(picked.path);
    final rawSize = await file.length();
    if (!mounted) return;
    if (rawSize > _maxRawVideoSizeBytes) {
      setState(() => _error = 'Ukuran video terlalu besar.');
      return;
    }

    setState(() {
      _preparingVideo = true;
      _error = null;
    });

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      final durationSeconds = controller.value.duration.inSeconds;

      if (durationSeconds > _maxVideoDurationSeconds) {
        controller.dispose();
        setState(() {
          _preparingVideo = false;
          _error = 'Durasi video maksimal $_maxVideoDurationSeconds detik.';
        });
        return;
      }

      file = await _compress(file);
      if (await file.length() > _maxVideoSizeBytes) {
        controller.dispose();
        if (mounted) {
          setState(() {
            _preparingVideo = false;
            _error = 'Ukuran video maksimal 50MB.';
          });
        }
        return;
      }

      final thumbnailPath = '${Directory.systemTemp.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      final thumbnailOk = await FcNativeVideoThumbnail().saveThumbnailToFile(
        srcFile: file.path,
        destFile: thumbnailPath,
        width: 512,
        height: 512,
        format: 'jpeg',
        quality: 75,
      );

      if (!mounted) return;
      setState(() {
        _videoController?.dispose();
        _videoController = controller;
        _video = _PickedVideo(
          file: file,
          thumbnail: thumbnailOk ? File(thumbnailPath) : null,
          durationSeconds: durationSeconds,
        );
        _preparingVideo = false;
      });
    } catch (_) {
      controller.dispose();
      if (mounted) {
        setState(() {
          _preparingVideo = false;
          _error = 'Gagal memproses video.';
        });
      }
    }
  }

  /// Re-encodes to ~540p so a minute of phone video is a few MB instead of 100+. Falls back to the
  /// original when compression fails or doesn't help.
  Future<File> _compress(File original) async {
    try {
      final info = await VideoCompress.compressVideo(
        original.path,
        quality: VideoQuality.Res960x540Quality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final compressed = info?.file;
      if (compressed != null && await compressed.length() < await original.length()) {
        return compressed;
      }
    } catch (_) {}
    return original;
  }

  void _removeVideo() {
    setState(() {
      _videoController?.dispose();
      _videoController = null;
      _video = null;
    });
  }

  Future<void> _pickProducts() async {
    final selected = await showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductTagPickerSheet(initiallySelected: _taggedProducts),
    );
    if (selected != null && mounted) setState(() => _taggedProducts.replaceRange(0, _taggedProducts.length, selected));
  }

  bool get _canSubmit =>
      (_bodyController.text.trim().isNotEmpty || _media.isNotEmpty || _video != null) && !_submitting && !_preparingVideo;

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(feedProvider.notifier).createPost(
            body: _bodyController.text.trim().isEmpty ? null : _bodyController.text.trim(),
            media: _media,
            productIds: _taggedProducts.map((p) => p.id).toList(),
            video: _video?.file,
            videoThumbnail: _video?.thumbnail,
            videoDurationSeconds: _video?.durationSeconds,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() {
        _submitting = false;
        _error = 'Gagal membuat postingan.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = _media.isNotEmpty || _video != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Postingan'),
        actions: [
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Posting'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.destructive, fontSize: 13)),
            ),
          TextField(
            controller: _bodyController,
            maxLines: 6,
            minLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Apa yang ingin Anda bagikan?',
              border: InputBorder.none,
            ),
          ),
          if (_media.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _media.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_media[index], width: 90, height: 90, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => _removeMedia(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_video != null) ...[
            const SizedBox(height: 12),
            _VideoPreview(
              controller: _videoController,
              durationSeconds: _video!.durationSeconds,
              onRemove: _removeVideo,
            ),
          ],
          if (_preparingVideo) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Memproses video...', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
              ],
            ),
          ],
          if (_taggedProducts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final product in _taggedProducts)
                  Chip(
                    label: Text(product.name, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _taggedProducts.remove(product)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined, color: AppColors.primary),
            title: const Text('Tambah Foto'),
            trailing: _media.isNotEmpty ? Text('${_media.length}/10') : null,
            onTap: (_media.length >= 10 || _video != null) ? null : _pickImages,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.videocam_outlined, color: AppColors.accent),
            title: const Text('Tambah Video'),
            subtitle: const Text('Maks 60 detik, 50MB', style: TextStyle(fontSize: 11.5)),
            onTap: (hasMedia || _preparingVideo) ? null : _pickVideo,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sell_outlined, color: AppColors.secondary),
            title: const Text('Tandai Produk'),
            trailing: _taggedProducts.isNotEmpty ? Text('${_taggedProducts.length}') : null,
            onTap: _pickProducts,
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.controller, required this.durationSeconds, required this.onRemove});

  final VideoPlayerController? controller;
  final int durationSeconds;
  final VoidCallback onRemove;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final ready = controller != null && controller.value.isInitialized;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: ready ? controller.value.aspectRatio : 16 / 9,
            child: ready
                ? VideoPlayer(controller)
                : Container(color: AppColors.surface),
          ),
          if (ready)
            InkWell(
              onTap: () => setState(() {
                controller.value.isPlaying ? controller.pause() : controller.play();
              }),
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  color: Colors.black26,
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: widget.onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text(
                '${widget.durationSeconds ~/ 60}:${(widget.durationSeconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
