import 'package:app_links/app_links.dart';
import 'oauth_service.dart';

class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();
  final OAuthService _oauthService = OAuthService();
  bool _isInitialized = false;

  Future<void> initDeepLinks() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // Get initial link (works for both HTTPS and custom schemes)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('DEBUG: Initial deep link received: $initialLink');
        _handleIncomingLink(initialLink.toString());
      }

      // Listen for future links (works for both HTTPS and custom schemes)
      _appLinks.uriLinkStream.listen((Uri uri) {
        print('DEBUG: Deep link received: $uri');
        _handleIncomingLink(uri.toString());
      }, onError: (err) {
        print('ERROR: Error receiving link: $err');
      });

      print('DEBUG: Deep link handler initialized');
    } catch (e) {
      print('ERROR: Failed to initialize deep links: $e');
    }
  }

  void _handleIncomingLink(String link) {
    try {
      final uri = Uri.parse(link);
      final code = uri.queryParameters['code'];

      if (code != null && code.isNotEmpty) {
        print('DEBUG: Auth code extracted from deep link: ${code.substring(0, 20)}...');
        _oauthService.addAuthCode(code);
      } else {
        final error = uri.queryParameters['error'];
        if (error != null) {
          print('ERROR: Auth error from deep link: $error');
          print('ERROR: Description: ${uri.queryParameters['error_description']}');
        } else {
          print('WARN: No auth code found in deep link: $link');
        }
      }
    } catch (e) {
      print('ERROR: Error handling deep link: $e');
    }
  }
}