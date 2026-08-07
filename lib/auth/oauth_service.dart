import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'config.dart';
import 'auth.dart';  // Only for User class

class OAuthService {
  static const String _tokenKey = 'oauth_tokens';
  static const String _codeVerifierKey = 'code_verifier';
  static const String _redirectUri = 'browseapp://callback';

  late final AppConfig _config;

  String? _codeVerifier;
  String? _codeChallenge;
  String? _currentLoginUrl;
  String? _currentCodeVerifier;

  final StreamController<String> _authCodeController = StreamController<String>.broadcast();

  static final OAuthService _instance = OAuthService._internal();
  factory OAuthService() => _instance;
  OAuthService._internal();

  // ===== INITIALIZATION =====

  Future<void> init() async {
    print('DEBUG: === OAUTH SERVICE INITIALIZATION ===');
    _config = await loadConfig();
    print('DEBUG: Config loaded successfully');
    print('DEBUG:   - cognitoDomain: ${_config.cognitoDomain}');
    print('DEBUG:   - redirectUri: $_redirectUri');
    print('DEBUG:   - clientID: ${_config.clientID}');
  }

  // ===== PKCE GENERATION =====

  void _generatePKCE() {
    print('DEBUG: === GENERATING PKCE ===');
    final random = Random.secure();
    const length = 64;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    _codeVerifier = String.fromCharCodes(
        List.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );

    final bytes = utf8.encode(_codeVerifier!);
    final digest = sha256.convert(bytes);
    _codeChallenge = base64Url.encode(digest.bytes)
        .replaceAll('=', '');

    print('DEBUG: PKCE generated');
    print('DEBUG:   - Code Verifier length: ${_codeVerifier!.length}');
    print('DEBUG:   - Code Verifier: ${_codeVerifier!.substring(0, 20)}...');
    print('DEBUG:   - Code Challenge: ${_codeChallenge!.substring(0, 20)}...');
  }

  // ===== LOGIN URL GENERATION =====

  String getLoginUrlAndSaveVerifier() {
    print('DEBUG: === GENERATING LOGIN URL ===');
    _generatePKCE();

    _currentCodeVerifier = _codeVerifier;

    final uri = Uri.parse('${_config.cognitoDomain}/login')
        .replace(queryParameters: {
      'client_id': _config.clientID,
      'response_type': 'code',
      'scope': 'email openid phone aws.cognito.signin.user.admin',
      'redirect_uri': _redirectUri,
      'code_challenge': _codeChallenge!,
      'code_challenge_method': 'S256',
    });

    _currentLoginUrl = uri.toString();
    print('DEBUG: Login URL: $_currentLoginUrl');

    _saveCodeVerifier(_currentCodeVerifier!);

    return _currentLoginUrl!;
  }

  // ===== LAUNCH LOGIN =====

  Future<void> launchLoginWithUrl(String loginUrl) async {
    print('DEBUG: === LAUNCHING LOGIN ===');

    try {
      final uri = Uri.parse(loginUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        print('DEBUG: Login launched successfully');
      } else {
        print('ERROR: Could not launch login URL');
        throw Exception('Could not launch login URL');
      }
    } catch (e) {
      print('ERROR: Failed to launch login: $e');
      rethrow;
    }
  }

  // ===== FETCH USER ATTRIBUTES VIA API =====

  Future<Map<String, dynamic>> fetchUserAttributes(String accessToken) async {
    print('DEBUG: === FETCHING USER ATTRIBUTES VIA API ===');

    try {
      final response = await http.post(
        Uri.parse('https://cognito-idp.${_config.region}.amazonaws.com/'),
        headers: {
          'Content-Type': 'application/x-amz-json-1.1',
          'X-Amz-Target': 'AWSCognitoIdentityProviderService.GetUser',
        },
        body: jsonEncode({'AccessToken': accessToken}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('ERROR: GetUser API call timed out');
          return http.Response('{"error": "timeout"}', 408);
        },
      );

      print('DEBUG: GetUser response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('DEBUG: User attributes fetched successfully');

        final claims = <String, dynamic>{};

        if (data.containsKey('UserAttributes')) {
          final attributes = data['UserAttributes'] as List;
          for (var attr in attributes) {
            final name = attr['Name']?.toString() ?? '';
            final value = attr['Value']?.toString() ?? '';
            if (name.isNotEmpty) {
              claims[name] = value;
              print('DEBUG:   - $name: $value');
            }
          }
          print('DEBUG: Retrieved ${attributes.length} attributes');
        }

        if (data.containsKey('Username')) {
          claims['cognito:username'] = data['Username'];
        }

        return claims;
      } else {
        print('ERROR: GetUser failed: ${response.statusCode}');
        print('ERROR: Response: ${response.body}');
        return {};
      }
    } catch (e) {
      print('ERROR: Failed to fetch user attributes: $e');
      return {};
    }
  }

  // ===== TOKEN EXCHANGE =====

  Future<User> exchangeCodeForTokens(String code) async {
    print('DEBUG: === EXCHANGING CODE FOR TOKENS ===');
    print('DEBUG: Auth code: ${code.substring(0, 20)}...');

    _codeVerifier = await _getCodeVerifier();
    if (_codeVerifier == null) {
      throw Exception('Code verifier not found. Please login again.');
    }

    try {
      final body = {
        'grant_type': 'authorization_code',
        'client_id': _config.clientID,
        'code': code,
        'code_verifier': _codeVerifier!,
        'redirect_uri': _redirectUri,
      };

      final response = await http.post(
        Uri.parse('${_config.cognitoDomain}/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        print('ERROR: Token exchange failed: ${response.statusCode}');
        print('ERROR: Response: ${response.body}');
        throw Exception('Failed to exchange code: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      print('DEBUG: Token exchange successful!');

      final idToken = data['id_token'] as String;
      final accessToken = data['access_token'] as String;

      // Decode ID token for basic claims
      final idTokenParts = idToken.split('.');
      String normalized = idTokenParts[1];
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final idPayload = json.decode(utf8.decode(base64Url.decode(normalized)));

      print('DEBUG: ID Token decoded');
      print('DEBUG: ID Token payload keys: ${idPayload.keys.join(', ')}');

      // Build claims from ID token
      var claims = <String, dynamic>{};
      claims.addAll(idPayload);

      // ===== FETCH ADDITIONAL ATTRIBUTES VIA API =====
      print('DEBUG: Fetching additional user attributes...');
      try {
        final additionalClaims = await fetchUserAttributes(accessToken);
        claims.addAll(additionalClaims);
        print('DEBUG: Added ${additionalClaims.length} attributes from API');
      } catch (e) {
        print('WARNING: Could not fetch additional attributes: $e');
      }

      // Extract username
      final username = claims['cognito:name']?.toString() ??
          claims['email']?.toString() ??
          claims['cognito:username']?.toString() ??
          '';

      print('DEBUG: Final claims:');
      print('DEBUG:   - username: $username');
      print('DEBUG:   - given_name: ${claims['given_name']}');
      print('DEBUG:   - family_name: ${claims['family_name']}');
      print('DEBUG:   - custom:role: ${claims['custom:role']}');
      print('DEBUG:   - custom:suburb: ${claims['custom:suburb']}');
      print('DEBUG:   - Total claims: ${claims.length}');

      // Create User
      final user = User(
        username,
        claims['email_verified'] == true,
        true,
        claims['sub']?.toString() ?? '',
        claims,
        idToken,
        accessToken,
      );

      // Save tokens
      await _saveTokens({
        'id_token': idToken,
        'access_token': accessToken,
        'refresh_token': data['refresh_token'],
        'expires_in': data['expires_in'],
        'token_type': data['token_type'],
        'username': user.username,
        'user_sub': user.userSub,
        'claims': claims,
      });

      await _clearCodeVerifier();

      print('DEBUG: User created successfully');
      print('DEBUG:   - Username: ${user.username}');
      print('DEBUG:   - Claims count: ${user.claims.length}');

      return user;
    } catch (e) {
      print('ERROR: Error exchanging code: $e');
      rethrow;
    }
  }

  // ===== GET STORED USER =====

  Future<User?> getStoredUser() async {
    print('DEBUG: === GETTING STORED USER ===');

    final tokens = await _getTokens();
    if (tokens == null) {
      print('DEBUG: No stored tokens found');
      return null;
    }

    try {
      final idToken = tokens['id_token'] as String;
      final accessToken = tokens['access_token'] as String;

      Map<String, dynamic> claims;

      if (tokens.containsKey('claims') && tokens['claims'] is Map) {
        claims = tokens['claims'] as Map<String, dynamic>;
        print('DEBUG: Using stored claims with ${claims.length} attributes');
      } else {
        final parts = idToken.split('.');
        String normalized = parts[1];
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        claims = json.decode(utf8.decode(base64Url.decode(normalized)));
        print('DEBUG: Decoded ${claims.length} claims from ID token');
      }

      final username = claims['cognito:name']?.toString() ??
          claims['email']?.toString() ??
          claims['cognito:username']?.toString() ??
          tokens['username'] ??
          '';

      return User(
        username,
        claims['email_verified'] == true,
        true,
        claims['sub']?.toString() ?? tokens['user_sub'] ?? '',
        claims,
        idToken,
        accessToken,
      );
    } catch (e) {
      print('ERROR: Error getting stored user: $e');
      return null;
    }
  }

  // ===== TOKEN REFRESH =====

  Future<User> refreshTokens(User user) async {
    print('DEBUG: === REFRESHING TOKENS ===');

    try {
      final storedTokens = await _getTokens();
      if (storedTokens == null || !storedTokens.containsKey('refresh_token')) {
        throw Exception('No refresh token available');
      }

      final response = await http.post(
        Uri.parse('${_config.cognitoDomain}/oauth2/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'client_id': _config.clientID,
          'refresh_token': storedTokens['refresh_token'],
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to refresh tokens: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      print('DEBUG: Token refresh successful');

      final newIdToken = data['id_token'] as String;
      final newAccessToken = data['access_token'] as String;

      // Preserve claims
      Map<String, dynamic> claims;
      if (storedTokens.containsKey('claims') && storedTokens['claims'] is Map) {
        claims = storedTokens['claims'] as Map<String, dynamic>;
        print('DEBUG: Preserved existing claims');
      } else {
        final parts = newIdToken.split('.');
        String normalized = parts[1];
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        claims = json.decode(utf8.decode(base64Url.decode(normalized)));
      }

      final username = claims['cognito:name']?.toString() ??
          claims['email']?.toString() ??
          claims['cognito:username']?.toString() ??
          user.username;

      final refreshedUser = User(
        username,
        claims['email_verified'] == true,
        true,
        claims['sub']?.toString() ?? user.userSub,
        claims,
        newIdToken,
        newAccessToken,
      );

      storedTokens['id_token'] = newIdToken;
      storedTokens['access_token'] = newAccessToken;
      storedTokens['claims'] = claims;
      if (data.containsKey('refresh_token')) {
        storedTokens['refresh_token'] = data['refresh_token'];
      }
      await _saveTokens(storedTokens);

      return refreshedUser;
    } catch (e) {
      print('ERROR: Error refreshing tokens: $e');
      rethrow;
    }
  }

  // ===== AUTHENTICATION CHECK =====

  Future<bool> isAuthenticated() async {
    print('DEBUG: === CHECKING AUTHENTICATION ===');

    try {
      final tokens = await _getTokens();
      if (tokens == null) {
        print('DEBUG: No tokens found');
        return false;
      }

      final accessToken = tokens['access_token'] as String;
      final parts = accessToken.split('.');
      if (parts.length != 3) return false;

      String normalized = parts[1];
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final payload = json.decode(utf8.decode(base64Url.decode(normalized)));

      final expiry = payload['exp'] as int?;
      if (expiry == null) return false;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry * 1000);
      final isExpired = DateTime.now().isAfter(expiryDate);

      if (isExpired) {
        print('DEBUG: Token expired, attempting refresh...');
        final user = await getStoredUser();
        if (user != null) {
          try {
            await refreshTokens(user);
            print('DEBUG: Token refresh successful');
            return true;
          } catch (e) {
            print('DEBUG: Token refresh failed: $e');
            return false;
          }
        }
        return false;
      }

      print('DEBUG: Token is valid');
      return true;
    } catch (e) {
      print('ERROR: Error checking authentication: $e');
      return false;
    }
  }

  // ===== STORAGE =====

  Future<void> _saveCodeVerifier(String verifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeVerifierKey, verifier);
  }

  Future<String?> _getCodeVerifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_codeVerifierKey);
  }

  Future<void> _clearCodeVerifier() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_codeVerifierKey);
  }

  Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, json.encode(tokens));
    print('DEBUG: Tokens saved with ${(tokens['claims'] as Map).length} claims');
  }

  Future<Map<String, dynamic>?> _getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenJson = prefs.getString(_tokenKey);
    if (tokenJson == null) return null;
    return json.decode(tokenJson);
  }

  // ===== LOGOUT =====

  Future<void> logout() async {
    print('DEBUG: === LOGGING OUT ===');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await _clearCodeVerifier();
    _codeVerifier = null;
    _codeChallenge = null;
    _currentLoginUrl = null;
    _currentCodeVerifier = null;
    print('DEBUG: Logout complete');
  }

  // ===== DEEP LINK =====

  void addAuthCode(String code) {
    print('DEBUG: Adding auth code to stream: ${code.substring(0, 20)}...');
    _authCodeController.add(code);
  }

  Stream<String> get authCodeStream => _authCodeController.stream;

  void dispose() {
    _authCodeController.close();
  }
}