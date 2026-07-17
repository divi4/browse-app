// login_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'oauth_service.dart';
import 'deep_link_handler.dart';
import 'auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final OAuthService _oauthService = OAuthService();
  final DeepLinkHandler _deepLinkHandler = DeepLinkHandler();
  bool _isLoading = false;
  bool _useWebView = false;
  String? _loginUrl;
  String _error = '';
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _oauthService.init();
    await _deepLinkHandler.initDeepLinks();

    _oauthService.authCodeStream.listen((code) async {
      setState(() => _isLoading = true);

      try {
        final user = await _oauthService.exchangeCodeForTokens(code);
        print('DEBUG: Login successful: ${user.username}');
        print('DEBUG: given_name: ${user.claims['given_name']}');
        print('DEBUG: custom:role: ${user.claims['custom:role']}');

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/request-board',
            arguments: {
              'user': user
            },
          );}
      } catch (e) {
        print('ERROR: Login failed: $e');
        setState(() {
          _error = 'Login failed: $e';
          _isLoading = false;
          _useWebView = false;
        });
      }
    });

    try {
      final isAuth = await _oauthService.isAuthenticated();
      if (isAuth) {
        final user = await _oauthService.getStoredUser();
        if (user != null && mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/request-board',
            arguments: {
              'user': user
            },
          );
        }
      }
    } catch (e) {
      print('ERROR: Error checking auth: $e');
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final loginUrl = _oauthService.getLoginUrlAndSaveVerifier();

      try {
        await _oauthService.launchLoginWithUrl(loginUrl);
      } catch (e) {
        setState(() {
          _useWebView = true;
          _loginUrl = loginUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('ERROR: Failed to launch login: $e');
      setState(() {
        _error = 'Failed to launch login: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useWebView && _loginUrl != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sign In'),
          backgroundColor: const Color.fromRGBO(46, 165, 107, 1),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _useWebView = false;
                  _loginUrl = null;
                  _error = '';
                });
              },
            ),
          ],
        ),
        body: WebViewWidget(
          controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(
              NavigationDelegate(
                onNavigationRequest: (NavigationRequest request) {
                  print('DEBUG: WebView navigating to: ${request.url}');
                  if (request.url.startsWith('browseapp://callback')) {
                    final uri = Uri.parse(request.url);
                    final code = uri.queryParameters['code'];
                    if (code != null && code.isNotEmpty) {
                      print('DEBUG: Auth code captured in WebView: $code');
                      setState(() {
                        _useWebView = false;
                        _loginUrl = null;
                      });
                      _oauthService.addAuthCode(code);
                    }
                    return NavigationDecision.prevent;
                  }
                  if (request.url.contains('amazoncognito.com')) {
                    return NavigationDecision.navigate;
                  }
                  return NavigationDecision.navigate;
                },
                onPageFinished: (String url) {
                  print('DEBUG: WebView page finished: $url');
                },
                onWebResourceError: (WebResourceError error) {
                  print('ERROR: WebView error: ${error.description}');
                  setState(() {
                    _error = 'WebView error: ${error.description}';
                  });
                },
              ),
            )
            ..loadRequest(Uri.parse(_loginUrl!)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: const Color.fromRGBO(46, 165, 107, 1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.nature_people,
              size: 80,
              color: Color.fromRGBO(46, 165, 107, 1),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Browse App',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            if (_error.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error,
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
              onPressed: _login,
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Cognito'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color.fromRGBO(46, 165, 107, 1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}