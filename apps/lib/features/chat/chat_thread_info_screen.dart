import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/chat_thread.dart';
import '../../providers/core_providers.dart';
import '../../widgets/skeleton.dart';

class ChatThreadInfoScreen extends ConsumerStatefulWidget {
  const ChatThreadInfoScreen({
    super.key,
    required this.threadId,
    required this.title,
    this.avatarUrl,
    this.avatarIcon,
    this.isDirectMessage = false,
    this.isSeller = false,
  });

  final String threadId;
  final String title;
  final String? avatarUrl;
  final IconData? avatarIcon;
  final bool isDirectMessage;
  final bool isSeller;

  @override
  ConsumerState<ChatThreadInfoScreen> createState() => _ChatThreadInfoScreenState();
}

class _ChatThreadInfoScreenState extends ConsumerState<ChatThreadInfoScreen> {
  final _scrollController = ScrollController();
  final List<ChatParticipant> _participants = [];
  int? _participantCount;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadThreadInfo();
    if (!widget.isDirectMessage) {
      _loadParticipants();
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) return;
    if (_loadingMore || !_hasMore) return;
    _loadParticipants();
  }

  Future<void> _loadThreadInfo() async {
    try {
      final thread = await ref.read(chatServiceProvider).thread(widget.threadId);
      if (!mounted) return;
      setState(() => _participantCount = thread.participantCount);
    } catch (_) {
      // Keep whatever count was passed in initially; non-fatal.
    }
  }

  Future<void> _loadParticipants() async {
    setState(() => _page == 1 ? _loading = true : _loadingMore = true);
    try {
      final result = await ref.read(chatServiceProvider).participants(widget.threadId, page: _page);
      if (!mounted) return;
      setState(() {
        _participants.addAll(result.data);
        _hasMore = result.meta.hasMore;
        _page++;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info Percakapan')),
      body: ListView(
        controller: _scrollController,
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
                  child: widget.avatarUrl == null ? Icon(widget.avatarIcon ?? Icons.person_outline, size: 40) : null,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _typeLabel(),
                  style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13.5),
                ),
              ],
            ),
          ),
          if (!widget.isDirectMessage) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Anggota Grup',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.foreground),
              ),
            ),
            if (_loading)
              const _ParticipantListSkeleton()
            else if (_participants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Belum ada anggota.')),
              )
            else
              Column(
                children: [
                  for (final participant in _participants) _ParticipantTile(participant: participant),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  String _typeLabel() {
    if (widget.isDirectMessage) {
      final base = widget.isSeller ? 'Penjual' : 'Pengguna';
      return base;
    }

    final count = _participantCount;
    return count != null ? 'Grup • $count anggota' : 'Grup';
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});

  final ChatParticipant participant;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        backgroundImage: participant.avatarUrl != null ? NetworkImage(participant.avatarUrl!) : null,
        child: participant.avatarUrl == null ? const Icon(Icons.person_outline) : null,
      ),
      title: Text(participant.name),
      subtitle: participant.isSeller ? const Text('Penjual') : null,
    );
  }
}

class _ParticipantListSkeleton extends StatelessWidget {
  const _ParticipantListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: const [
                Skeleton(width: 40, height: 40, borderRadius: 20),
                SizedBox(width: 12),
                Expanded(child: Skeleton(height: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
