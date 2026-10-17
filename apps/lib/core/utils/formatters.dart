import 'package:flutter/material.dart' show DateUtils;
import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);

String formatCurrency(num amount) => _currencyFormat.format(amount);

String formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';

  return DateFormat('d MMM yyyy', 'id_ID').format(dateTime);
}

String formatChatListTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final now = DateTime.now();

  final isToday =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  if (isToday) return DateFormat('HH.mm').format(local);

  return DateFormat('dd/MM/yyyy').format(local);
}

/// Time shown inside a chat bubble; the day is conveyed by the date separator.
String formatChatBubbleTime(DateTime dateTime) =>
    DateFormat('HH.mm').format(dateTime.toLocal());

/// Label for the date separator between chat messages of different days.
String formatChatDayLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  final today = DateUtils.dateOnly(DateTime.now());
  final day = DateUtils.dateOnly(local);
  final diff = today.difference(day).inDays;

  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  if (diff < 7) return DateFormat('EEEE', 'id_ID').format(local);
  if (local.year == today.year) {
    return DateFormat('d MMMM', 'id_ID').format(local);
  }
  return DateFormat('d MMMM yyyy', 'id_ID').format(local);
}
