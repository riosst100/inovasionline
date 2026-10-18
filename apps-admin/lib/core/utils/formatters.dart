import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

String formatCurrency(num amount) => _currencyFormat.format(amount);

String formatDateTime(DateTime dateTime) => DateFormat('d MMM yyyy, HH.mm', 'id_ID').format(dateTime.toLocal());

String formatDate(DateTime dateTime) => DateFormat('EEEE, d MMM yyyy', 'id_ID').format(dateTime.toLocal());

/// JSON numbers may arrive as num or as decimal strings ("12000.00").
double parseNum(Object? value) => switch (value) {
  num n => n.toDouble(),
  String s => double.tryParse(s) ?? 0,
  _ => 0,
};
