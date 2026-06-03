import 'package:intl/intl.dart';

class Helper
{
  /// Now
  static String now({String format = 'sql', DateTime? time})
  {
    DateTime source = time ?? DateTime.now().toUtc();

    if (format == 'sql') {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(source);
    } else if (format == 'iso') {
      return source.toIso8601String();
    }

    return DateFormat('yyyy-MM-dd HH:mm:ss').format(source); 
  }
}