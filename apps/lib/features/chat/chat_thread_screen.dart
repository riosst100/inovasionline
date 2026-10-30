import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/skeleton.dart';
import 'chat_thread_info_screen.dart';

const _chatPollInterval = Duration(seconds: 5);

/// With the socket connected, poll only every Nth tick (30s) as a safety net.
const _liveSafetyPollEvery = 6;

/// A [HorizontalDragGestureRecognizer] that gives up as soon as the pointer's
/// movement is clearly more vertical than horizontal, so a swipe intended to
/// scroll the message list (even one that starts slightly diagonal) is not
/// stolen by the reply-swipe gesture and does not stall the scroll.
class _DirectionalHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  double _dx = 0;
  double _dy = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _dx = 0;
    _dy = 0;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _dx += event.delta.dx;
      _dy += event.delta.dy;

      // Bail out of the arena the moment vertical movement is at least as
      // large as horizontal, so the ancestor Scrollable can claim the drag
      // immediately instead of the list feeling like it "catches" briefly
      // before scrolling.
      if (_dy.abs() >= _dx.abs() && _dy.abs() > 3) {
        resolve(GestureDisposition.rejected);
        return;
      }
    }
    super.handleEvent(event);
  }

  // The default HorizontalDragGestureRecognizer accepts as soon as the
  // accumulated *horizontal* distance crosses the touch slop, regardless of
  // how much vertical movement also happened in the same batch of pointer
  // events — which is what let a mostly-vertical scroll gesture "steal" one
  // update from this recognizer before handleEvent's own check rejected it.
  // Requiring horizontal movement to also be clearly dominant here closes
  // that gap so the ancestor Scrollable wins immediately.
  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    return _dx.abs() > _dy.abs() &&
        super.hasSufficientGlobalDistanceToAccept(
          pointerDeviceKind,
          deviceTouchSlop,
        );
  }
}

/// Clamping physics (no bounce) with lower fling friction so a quick short
/// swipe carries the list much further, similar to WhatsApp/Telegram,
/// instead of stopping close to where the drag ended. A new touch on the
/// list still cancels the fling immediately (Flutter's default behavior),
/// matching WhatsApp's "tap to stop" feel.
class _FastFlingScrollPhysics extends ClampingScrollPhysics {
  const _FastFlingScrollPhysics({super.parent});

  static const double _flingFriction = 0.006;

  @override
  _FastFlingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _FastFlingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Tolerance tolerance = toleranceFor(position);

    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    if (velocity.abs() < tolerance.velocity) {
      return null;
    }
    if (velocity > 0.0 && position.pixels >= position.maxScrollExtent) {
      return null;
    }
    if (velocity < 0.0 && position.pixels <= position.minScrollExtent) {
      return null;
    }

    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: _flingFriction,
      tolerance: tolerance,
    );
  }
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.threadId,
    required this.title,
    required this.canPost,
    this.avatarUrl,
    this.avatarIcon,
    this.isDirectMessage = false,
  });

  final String threadId;
  final String title;
  final bool canPost;
  final String? avatarUrl;
  final IconData? avatarIcon;
  final bool isDirectMessage;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen>
    with WidgetsBindingObserver {
  VoidCallback? _unlisten;
  int _ticks = 0;
  final _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMoreOlder = true;
  int _nextPage = 2;
  String? _error;
  Timer? _pollTimer;
  Timer? _highlightTimer;
  ChatMessage? _replyTarget;
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
    _unlisten = ref
        .read(realtimeProvider)
        .listen('chat-thread.${widget.threadId}', 'chat.message', _poll);
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    ref.read(chatServiceProvider).markAsRead(widget.threadId);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_chatPollInterval, (_) {
      // New messages are pushed over the socket; while it is up, polling is only a safety net.
      if (ref.read(realtimeProvider).connected.value && ++_ticks % _liveSafetyPollEvery != 0) return;
      _poll();
    });
  }

  /// No point hitting the API every few seconds while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _poll();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlisten?.call();
    _pollTimer?.cancel();
    _highlightTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    var maxIndex = -1;
    for (final p in positions) {
      if (p.index > maxIndex) maxIndex = p.index;
    }
    if (maxIndex >= _messages.length - 5) _loadMoreOlder();
  }

  void _scrollToBottom() {
    if (_messages.isEmpty) return;
    _itemScrollController.jumpTo(index: 0);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(chatServiceProvider)
          .messages(widget.threadId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(result.data);
        _hasMoreOlder = result.meta.hasMore;
        _nextPage = 2;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreOlder() async {
    if (_loadingMore || !_hasMoreOlder || _loading) return;

    setState(() => _loadingMore = true);
    try {
      final result = await ref
          .read(chatServiceProvider)
          .messages(widget.threadId, page: _nextPage);
      if (!mounted) return;
      final olderMessages = result.data
          .where((m) => !_messages.any((existing) => existing.id == m.id))
          .toList();
      setState(() {
        _messages.addAll(olderMessages);
        _hasMoreOlder = result.meta.hasMore;
        _nextPage++;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _poll() async {
    try {
      final result = await ref
          .read(chatServiceProvider)
          .messages(widget.threadId);
      if (!mounted) return;
      final newMessages = result.data
          .where((m) => !_messages.any((existing) => existing.id == m.id))
          .toList();
      if (newMessages.isEmpty) return;
      setState(() => _messages.insertAll(0, newMessages));
    } catch (_) {
      // Silently ignore poll failures; next tick will retry.
    }
  }

  Future<void> _send() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;

    final currentUserId = ref.read(authProvider).user?.id;
    final replyTarget = _replyTarget;
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';

    final optimisticMessage = ChatMessage(
      id: localId,
      threadId: widget.threadId,
      body: body,
      isOfficial: false,
      senderId: currentUserId,
      replyTo: replyTarget != null
          ? ChatMessageReplyTo(
              id: replyTarget.id,
              body: replyTarget.body,
              senderId: replyTarget.senderId,
              senderName: replyTarget.senderName,
            )
          : null,
      createdAt: DateTime.now(),
      status: ChatMessageStatus.sending,
    );

    setState(() {
      _messages.insert(0, optimisticMessage);
      _messageController.clear();
      _replyTarget = null;
    });
    _scrollToBottom();

    try {
      final message = await ref
          .read(chatServiceProvider)
          .sendMessage(widget.threadId, body, replyToId: replyTarget?.id);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == localId);
        if (index != -1) _messages[index] = message;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == localId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              status: ChatMessageStatus.failed,
            );
          }
          _error = 'Gagal mengirim pesan.';
        });
      }
    }
  }

  void _startReply(ChatMessage message) {
    setState(() => _replyTarget = message);
  }

  void _cancelReply() {
    setState(() => _replyTarget = null);
  }

  Future<void> _scrollToMessage(String messageId) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    _highlightTimer?.cancel();
    setState(() => _highlightedMessageId = messageId);

    await _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      alignment: 0.4,
    );

    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  void _openInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadInfoScreen(
          threadId: widget.threadId,
          title: widget.title,
          avatarUrl: widget.avatarUrl,
          avatarIcon: widget.avatarIcon,
          isDirectMessage: widget.isDirectMessage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider.select((s) => s.user?.id));

    return Scaffold(
      backgroundColor: _threadBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openInfo,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.avatarUrl == null
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2DD4BF), AppColors.primary],
                          )
                        : null,
                    image: widget.avatarUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(widget.avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.avatarUrl == null
                      ? Icon(
                          widget.avatarIcon ?? Icons.person_rounded,
                          size: 20,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.isDirectMessage
                            ? 'Ketuk untuk info kontak'
                            : 'Ketuk untuk info grup',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _openInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Material(
              color: const Color(0xFFFEF2F2),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: Colors.red.shade700,
                      onPressed: () => setState(() => _error = null),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: _threadBackground,
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: _loading
                        ? const _ChatThreadSkeleton()
                        : _messages.isEmpty
                        ? _EmptyThread(canPost: widget.canPost)
                        : ScrollablePositionedList.builder(
                            reverse: true,
                            physics: const _FastFlingScrollPhysics(),
                            itemScrollController: _itemScrollController,
                            itemPositionsListener: _itemPositionsListener,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMine =
                                  message.senderId != null &&
                                  message.senderId == currentUserId;
                              // The list is reversed: index + 1 is the
                              // previous (older) message, index - 1 the next.
                              final older = index + 1 < _messages.length
                                  ? _messages[index + 1]
                                  : null;
                              final newer = index > 0
                                  ? _messages[index - 1]
                                  : null;
                              final startsDay =
                                  older == null || !_isSameDay(older, message);
                              final startsGroup =
                                  startsDay || !_isSameSender(older, message);
                              final endsGroup =
                                  newer == null ||
                                  !_isSameDay(newer, message) ||
                                  !_isSameSender(newer, message);

                              final bubble = _MessageBubble(
                                key: ValueKey(message.id),
                                message: message,
                                isMine: isMine,
                                currentUserId: currentUserId,
                                showSenderName:
                                    startsGroup && !widget.isDirectMessage,
                                isFirstInGroup: startsGroup,
                                isLastInGroup: endsGroup,
                                isHighlighted:
                                    message.id == _highlightedMessageId,
                                onReply: widget.canPost
                                    ? () => _startReply(message)
                                    : null,
                                onQuoteTap: message.replyTo != null
                                    ? () =>
                                          _scrollToMessage(message.replyTo!.id)
                                    : null,
                              );

                              if (!startsDay || message.createdAt == null) {
                                return bubble;
                              }
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _DateSeparator(
                                    label: formatChatDayLabel(
                                      message.createdAt!,
                                    ),
                                  ),
                                  bubble,
                                ],
                              );
                            },
                          ),
                  ),
                  _ScrollToBottomButton(
                    itemPositionsListener: _itemPositionsListener,
                    onPressed: _scrollToBottom,
                  ),
                  if (_loadingMore)
                    const Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.canPost)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_replyTarget != null)
                                _ReplyPreviewBar(
                                  message: _replyTarget!,
                                  currentUserId: currentUserId,
                                  onCancel: _cancelReply,
                                ),
                              TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 5,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(fontSize: 15),
                                decoration: const InputDecoration(
                                  hintText: 'Tulis pesan…',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF94A3B8),
                                  ),
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 13,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _messageController,
                        builder: (context, value, _) {
                          final canSend = value.text.trim().isNotEmpty;
                          return AnimatedScale(
                            scale: canSend ? 1 : 0.9,
                            duration: const Duration(milliseconds: 150),
                            child: Material(
                              shape: const CircleBorder(),
                              color: canSend
                                  ? AppColors.primary
                                  : const Color(0xFFCBD5E1),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: canSend ? _send : null,
                                child: const SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              color: Colors.white,
              child: const SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: AppColors.mutedForeground,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Hanya admin yang dapat mengirim pesan',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _threadBackground = Color(0xFFEEF2F6);

bool _isSameDay(ChatMessage a, ChatMessage b) {
  final aTime = a.createdAt?.toLocal();
  final bTime = b.createdAt?.toLocal();
  if (aTime == null || bTime == null) return true;
  return DateUtils.isSameDay(aTime, bTime);
}

bool _isSameSender(ChatMessage a, ChatMessage b) =>
    a.isOfficial == b.isOfficial && a.senderId == b.senderId;

/// Distinct, readable colours for sender names in group chats, picked by a
/// stable hash of the sender so each person keeps the same colour.
const _senderNameColors = [
  Color(0xFF0D9488),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFFEA580C),
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFCA8A04),
  Color(0xFF0891B2),
];

Color _senderNameColor(ChatMessage message) {
  if (message.isOfficial) return AppColors.secondary;
  final key = message.senderId ?? message.senderName ?? '';
  final hash = key.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff);
  return _senderNameColors[hash % _senderNameColors.length];
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread({required this.canPost});

  final bool canPost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                size: 36,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada pesan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              canPost
                  ? 'Mulai percakapan dengan mengirim pesan pertama.'
                  : 'Pengumuman akan muncul di sini.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _replySwipeThreshold = 24.0;
const _replySwipeMax = 48.0;

String _replySenderLabel(ChatMessageReplyTo replyTo, String? currentUserId) {
  if (replyTo.senderId != null && replyTo.senderId == currentUserId)
    return 'Anda';
  return replyTo.senderName ?? 'Pengguna';
}

const _replyPreviewMaxLines = 3;

/// Truncates to at most [_replyPreviewMaxLines] lines, appending an ellipsis
/// when hidden lines remain. [Text.maxLines] + [TextOverflow.ellipsis] alone
/// don't add "…" when the cut falls exactly on a newline boundary.
String _truncateReplyPreview(String body) {
  final lines = body.split('\n');
  if (lines.length <= _replyPreviewMaxLines) return body;

  final visible = lines.take(_replyPreviewMaxLines).toList();
  visible[visible.length - 1] = '${visible.last}…';
  return visible.join('\n');
}

/// Listens to [itemPositionsListener] on its own so the frequent position
/// updates that happen on every scroll frame only rebuild this small button
/// instead of triggering a `setState` on the whole chat screen.
class _ScrollToBottomButton extends StatefulWidget {
  const _ScrollToBottomButton({
    required this.itemPositionsListener,
    required this.onPressed,
  });

  final ItemPositionsListener itemPositionsListener;
  final VoidCallback onPressed;

  @override
  State<_ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<_ScrollToBottomButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    widget.itemPositionsListener.itemPositions.removeListener(
      _onPositionsChanged,
    );
    super.dispose();
  }

  void _onPositionsChanged() {
    final positions = widget.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final atBottom = positions.any(
      (p) => p.index == 0 && p.itemTrailingEdge > 0,
    );
    final shouldBeVisible = !atBottom;
    if (shouldBeVisible != _visible) {
      setState(() => _visible = shouldBeVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Positioned(
      right: 12,
      bottom: 12,
      child: FloatingActionButton.small(
        heroTag: 'scrollToBottom',
        onPressed: widget.onPressed,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        shape: const CircleBorder(),
        child: const Icon(Icons.keyboard_double_arrow_down),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.currentUserId,
    this.showSenderName = true,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.isHighlighted = false,
    this.onReply,
    this.onQuoteTap,
  });

  final ChatMessage message;
  final bool isMine;
  final String? currentUserId;

  /// Consecutive messages from the same sender form a group: only the first
  /// shows the sender's name, and only the last gets the pointed "tail"
  /// corner, like WhatsApp/Telegram.
  final bool showSenderName;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isHighlighted;
  final VoidCallback? onReply;
  final VoidCallback? onQuoteTap;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  double _dragExtent = 0;
  bool _dragging = false;
  bool _everDragged = false;

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.onReply == null) return;
    setState(() {
      _dragging = true;
      _everDragged = true;
      _dragExtent = (_dragExtent + details.delta.dx).clamp(0, _replySwipeMax);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.onReply == null) return;
    if (_dragExtent >= _replySwipeThreshold) widget.onReply!();
    setState(() {
      _dragging = false;
      _dragExtent = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMine = widget.isMine;
    final bubbleColor = message.isOfficial
        ? AppColors.secondary.withValues(alpha: 0.12)
        : isMine
        ? AppColors.primary
        : Colors.white;
    final textColor = isMine && !message.isOfficial
        ? Colors.white
        : AppColors.foreground;
    final replyIconOpacity = (_dragExtent / _replySwipeThreshold).clamp(
      0.0,
      1.0,
    );

    final bubbleMaxWidth = MediaQuery.sizeOf(context).width * 0.75;

    final senderNameWidget = isMine || !widget.showSenderName
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message.isOfficial
                        ? 'Inovasi Online'
                        : (message.senderName ?? 'Pengguna'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _senderNameColor(message),
                    ),
                  ),
                ),
                if (message.isOfficial) ...[
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.verified_rounded,
                    size: 13,
                    color: AppColors.secondary,
                  ),
                ],
              ],
            ),
          );

    const bigRadius = Radius.circular(18);
    const smallRadius = Radius.circular(5);
    final bubbleRadius = BorderRadius.only(
      topLeft: !isMine && !widget.isFirstInGroup ? smallRadius : bigRadius,
      topRight: isMine && !widget.isFirstInGroup ? smallRadius : bigRadius,
      bottomLeft: !isMine ? smallRadius : bigRadius,
      bottomRight: isMine ? smallRadius : bigRadius,
    );

    final replyQuote = message.replyTo == null
        ? null
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onQuoteTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      (isMine && !message.isOfficial
                              ? Colors.white
                              : AppColors.primary)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: isMine && !message.isOfficial
                          ? Colors.white
                          : AppColors.primary,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _replySenderLabel(message.replyTo!, widget.currentUserId),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isMine && !message.isOfficial
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: bubbleMaxWidth - 36,
                      ),
                      child: Text(
                        _truncateReplyPreview(message.replyTo!.body),
                        maxLines: _replyPreviewMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    final timeColor = isMine && !message.isOfficial
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.mutedForeground;

    final statusIcon = !isMine
        ? null
        : switch (message.status) {
            ChatMessageStatus.sending => Icons.access_time,
            ChatMessageStatus.sent => Icons.done,
            ChatMessageStatus.failed => Icons.error_outline,
          };

    final bodyWithTime = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: message.createdAt != null
          ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: message.body,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                  ),
                  const WidgetSpan(child: SizedBox(width: 10)),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.bottom,
                    child: Text(
                      formatChatBubbleTime(message.createdAt!),
                      style: TextStyle(fontSize: 10.5, color: timeColor),
                    ),
                  ),
                  if (statusIcon != null) ...[
                    const WidgetSpan(child: SizedBox(width: 3)),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.bottom,
                      child: Icon(
                        statusIcon,
                        size: 12,
                        color: message.status == ChatMessageStatus.failed
                            ? Colors.red.shade200
                            : timeColor,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : Text(
              message.body,
              style: TextStyle(color: textColor, fontSize: 14.5, height: 1.35),
            ),
    );

    return RawGestureDetector(
      gestures: {
        _DirectionalHorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _DirectionalHorizontalDragGestureRecognizer
            >(() => _DirectionalHorizontalDragGestureRecognizer(), (instance) {
              instance
                ..onUpdate = _onDragUpdate
                ..onEnd = _onDragEnd;
            }),
      },
      child: Stack(
        children: [
          if (replyIconOpacity > 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: replyIconOpacity,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.reply, color: AppColors.mutedForeground),
                  ),
                ),
              ),
            ),
          _HighlightableRow(
            isHighlighted: widget.isHighlighted,
            child: _DraggableBubbleOffset(
              dragExtent: _dragExtent,
              animateChanges: _everDragged,
              instant: _dragging,
              child: Align(
                alignment: isMine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: EdgeInsets.fromLTRB(
                    12,
                    widget.isFirstInGroup ? 6 : 1.5,
                    12,
                    widget.isLastInGroup ? 2 : 0,
                  ),
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                  constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                  decoration: BoxDecoration(
                    color: isMine && !message.isOfficial ? null : bubbleColor,
                    gradient: isMine && !message.isOfficial
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF14B8A6), AppColors.primary],
                          )
                        : null,
                    borderRadius: bubbleRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (senderNameWidget != null) senderNameWidget,
                      if (replyQuote != null)
                        IntrinsicWidth(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [replyQuote, bodyWithTime],
                          ),
                        )
                      else
                        bodyWithTime,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps [child] in a highlight-fade [Container] only while [isHighlighted]
/// is (or was just) true, so idle bubbles skip the implicit animation
/// controller [TweenAnimationBuilder] would otherwise keep alive for every
/// item in the list.
class _HighlightableRow extends StatefulWidget {
  const _HighlightableRow({required this.isHighlighted, required this.child});

  final bool isHighlighted;
  final Widget child;

  @override
  State<_HighlightableRow> createState() => _HighlightableRowState();
}

class _HighlightableRowState extends State<_HighlightableRow> {
  bool _everHighlighted = false;

  @override
  void didUpdateWidget(covariant _HighlightableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted) _everHighlighted = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_everHighlighted && !widget.isHighlighted) return widget.child;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end: widget.isHighlighted
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
      ),
      duration: const Duration(milliseconds: 250),
      builder: (context, color, child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 2),
        color: color,
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Applies the reply-swipe horizontal offset to [child]. Uses a plain
/// [Transform.translate] while the drag is live (cheap, no animation
/// controller) and only switches to [AnimatedContainer] to snap back once
/// the drag ends, instead of every bubble carrying its own implicit
/// animation controller at all times.
class _DraggableBubbleOffset extends StatelessWidget {
  const _DraggableBubbleOffset({
    required this.dragExtent,
    required this.animateChanges,
    required this.instant,
    required this.child,
  });

  final double dragExtent;

  /// True once this bubble has been dragged at least once. Until then there
  /// is nothing to animate, so we skip creating an [AnimatedContainer] (and
  /// its implicit animation controller) for every bubble in the list.
  final bool animateChanges;
  final bool instant;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animateChanges || instant) {
      return Transform.translate(offset: Offset(dragExtent, 0), child: child);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(dragExtent, 0, 0),
      child: child,
    );
  }
}

class _ReplyPreviewBar extends StatelessWidget {
  const _ReplyPreviewBar({
    required this.message,
    this.currentUserId,
    required this.onCancel,
  });

  final ChatMessage message;
  final String? currentUserId;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _senderLabel(),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  _truncateReplyPreview(message.body),
                  maxLines: _replyPreviewMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: AppColors.mutedForeground,
          ),
        ],
      ),
    );
  }

  String _senderLabel() {
    if (message.isOfficial) return 'Inovasi Online';
    if (message.senderId != null && message.senderId == currentUserId)
      return 'Anda';
    return message.senderName ?? 'Pengguna';
  }
}

class _ChatThreadSkeleton extends StatelessWidget {
  const _ChatThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Align(
        alignment: index.isEven ? Alignment.centerLeft : Alignment.centerRight,
        child: Skeleton(width: 180, height: 40, borderRadius: 14),
      ),
    );
  }
}
