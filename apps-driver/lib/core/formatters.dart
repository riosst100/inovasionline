import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

String formatCurrency(num amount) => _currency.format(amount);

String formatTime(DateTime dateTime) => DateFormat('d MMM, HH.mm', 'id_ID').format(dateTime.toLocal());

/// JSON numbers may arrive as num or as decimal strings ("12000.00").
double parseNum(Object? value) => switch (value) {
  num n => n.toDouble(),
  String s => double.tryParse(s) ?? 0,
  _ => 0,
};
