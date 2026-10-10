import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat_message.dart';
import '../../models/chat_thread.dart';
import '../../providers/core_providers.dart';

final chatThreadsProvider = FutureProvider.autoDispose<List<ChatThread>>((ref) {
  return ref.watch(chatServiceProvider).threads();
});

final chatGlobalPreviewProvider = FutureProvider.autoDispose<(ChatThread, List<ChatMessage>)>((ref) {
  return ref.watch(chatServiceProvider).globalPreview();
});
