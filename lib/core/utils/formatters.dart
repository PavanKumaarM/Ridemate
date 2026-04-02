import 'package:intl/intl.dart';

class Formatters {

  static String formatDate(DateTime date) {

    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatTime(DateTime time) {

    return DateFormat('hh:mm a').format(time);
  }

  static String formatCurrency(double amount) {

    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    );

    return format.format(amount);
  }

}