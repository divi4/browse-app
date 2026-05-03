import 'package:url_launcher/url_launcher.dart';

class Donate {
  // Replace with actual PayPal URL when ready
  static const String paypalUrl = "https://www.google.com/";

  static Future<void> openPayPal() async {
    final uri = Uri.parse(paypalUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch PayPal");
    }
  }
}