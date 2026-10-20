import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../config/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/utils/formatters.dart';
import '../../models/cod_verification.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';

const _stepLabels = {
  'come_closer': 'Dekatkan wajah',
  'turn_right': 'Tengok kanan',
  'turn_left': 'Tengok kiri',
  'nod': 'Mengangguk',
  'blink': 'Kedip mata',
  'color_check': 'Cek warna',
};

/// Face recordings customers submitted before their first COD order.
class CodVerificationListScreen extends ConsumerStatefulWidget {
  const CodVerificationListScreen({super.key});

  @override
  ConsumerState<CodVerificationListScreen> createState() => _CodVerificationListScreenState();
}

class _CodVerificationListScreenState extends ConsumerState<CodVerificationListScreen> {
  final _listKey = GlobalKey<PagedListState<CodVerification>>();
  String _search = '';
  String? _status;

  void _restart() => _listKey.currentState?.refresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi COD')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchField(
              hint: 'Cari nama, email, atau no. HP',
              onChanged: (value) {
                _search = value;
                _restart();
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final entry in const {null: 'Semua', 'verified': 'Terverifikasi', 'revoked': 'Dicabut'}.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _status == entry.key,
                      onSelected: (_) {
                        setState(() => _status = entry.key);
                        _restart();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedList<CodVerification>(
              key: _listKey,
              emptyIcon: Icons.face_retouching_off_outlined,
              emptyText: 'Belum ada verifikasi COD.',
              fetch: (page) =>
                  ref.read(codVerificationServiceProvider).list(page: page, status: _status, search: _search),
              itemBuilder: (context, item) => _VerificationTile(
                item: item,
                onTap: () async {
                  final updated = await Navigator.of(
                    context,
                  ).push<CodVerification>(MaterialPageRoute(builder: (_) => CodVerificationDetailScreen(item: item)));
                  if (updated != null) _listKey.currentState?.replaceWhere((e) => e.id == updated.id, updated);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationTile extends StatelessWidget {
  const _VerificationTile({required this.item, required this.onTap});

  final CodVerification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.play_arrow_rounded)),
        title: Text(item.userName ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [?item.userContact, if (item.createdAt != null) formatDateTime(item.createdAt!)].join('\n'),
        ),
        isThreeLine: item.userContact != null,
        trailing: StatusBadge(
          label: item.isRevoked ? 'Dicabut' : 'Terverifikasi',
          color: item.isRevoked ? AppColors.destructive : AppColors.success,
        ),
      ),
    );
  }
}

class CodVerificationDetailScreen extends ConsumerStatefulWidget {
  const CodVerificationDetailScreen({super.key, required this.item});

  final CodVerification item;

  @override
  ConsumerState<CodVerificationDetailScreen> createState() => _CodVerificationDetailScreenState();
}

class _CodVerificationDetailScreenState extends ConsumerState<CodVerificationDetailScreen> {
  late CodVerification _item = widget.item;
  late final VideoPlayerController _video = VideoPlayerController.networkUrl(Uri.parse(_item.videoUrl));
  Object? _videoError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _video
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object e) {
          if (mounted) setState(() => _videoError = e);
        });
    _video.setLooping(true);
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _revoke() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cabut verifikasi'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Alasan, mis. wajah tidak sesuai'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Cabut'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      _snack('Alasan pencabutan wajib diisi.');
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await ref.read(codVerificationServiceProvider).revoke(_item.id, reason);
      if (!mounted) return;
      setState(() => _item = updated);
      _snack('Verifikasi dicabut. Customer harus mengulang.');
    } catch (e) {
      if (mounted) _snack(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_item);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_item.userName ?? 'Verifikasi COD')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _player(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_item.userContact ?? '', style: const TextStyle(color: AppColors.mutedForeground)),
                StatusBadge(
                  label: _item.isRevoked ? 'Dicabut' : 'Terverifikasi',
                  color: _item.isRevoked ? AppColors.destructive : AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_item.createdAt != null) _row('Direkam', formatDateTime(_item.createdAt!)),
            _row('Perangkat', _item.device ?? '-'),
            _row('IP', _item.ipAddress ?? '-'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final step in _item.steps) Chip(label: Text('✓ ${_stepLabels[step] ?? step}')),
              ],
            ),
            const SizedBox(height: 20),
            if (_item.isRevoked)
              Card(
                color: AppColors.destructive.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Dicabut${_item.revokedAt != null ? ' ${formatDateTime(_item.revokedAt!)}' : ''}\n${_item.revokedReason ?? ''}',
                  ),
                ),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
                onPressed: _busy ? null : _revoke,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.gpp_bad_outlined),
                label: const Text('Cabut Verifikasi'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.mutedForeground)),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Widget _player() {
    if (_videoError != null) {
      return const AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(color: Colors.black, child: Center(child: Text('Video tidak dapat diputar', style: TextStyle(color: Colors.white70)))),
      );
    }
    if (!_video.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 3 / 4,
        child: ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator())),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ColoredBox(
            color: Colors.black,
            child: AspectRatio(aspectRatio: _video.value.aspectRatio, child: VideoPlayer(_video)),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _video,
            builder: (context, value, _) => Row(
              children: [
                IconButton(
                  color: Colors.white,
                  icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  onPressed: () => value.isPlaying ? _video.pause() : _video.play(),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _video,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white38),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
