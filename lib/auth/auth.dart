import 'dart:convert';
import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'config.dart';

class CognitoServiceException implements Exception {
  final String message;
  CognitoServiceException(this.message);
}

class User {
  String username;
  bool userConfirmed;
  bool sessionValid;
  String? userSub;
  Map<String, dynamic> claims;
  final String idToken;
  final String accessToken;

  User(this.username, this.userConfirmed, this.sessionValid, this.userSub,
      this.claims, this.idToken, this.accessToken);
}

class CognitoManager {
  late final CognitoUserPool userPool;

  CognitoManager();

  Future<void> init() async {
    final config = await loadConfig();
    userPool = CognitoUserPool(config.userPoolID, config.clientID);
  }

  // Will need to add data validation for params such as address and birthdate
  Future<User> signUp(String role, String email, String postcode, String address, String birthdate, String picture, 
                      String given_name, String family_name, String password) async {
    final userAttributes = [
      AttributeArg(name: 'custom:role', value: role),
      AttributeArg(name: 'email', value: email),
      AttributeArg(name: 'custom:postcode', value: postcode),
      AttributeArg(name: 'custom:address', value: address),
      AttributeArg(name: 'updated_at', value: '${DateTime.now().millisecondsSinceEpoch ~/ 1000}'),
      AttributeArg(name: 'birthdate', value: birthdate),
      AttributeArg(name: 'picture', value: picture),
      AttributeArg(name: 'given_name', value: given_name),
      AttributeArg(name: 'family_name', value: family_name),
    ];

    try {
      final result = await userPool.signUp(email, password,
          userAttributes: userAttributes);
      return User(
          email, result.userConfirmed ?? false, false, result.userSub, {}, '', '');
    } catch (e) {
      throw CognitoServiceException(e.toString());
    }
  }

  Future<bool> confirmUser(String email, String confirmationCode) async {
    final cognitoUser = CognitoUser(email, userPool);
    try {
      return await cognitoUser.confirmRegistration(confirmationCode);
    } catch (e) {
      throw CognitoServiceException(e.toString());
    }
  }

  Future<User> signIn(String email, String password) async {
    final cognitoUser = CognitoUser(email, userPool);
    final authDetails = AuthenticationDetails(username: email, password: password);
    
    try {
      final session = await cognitoUser.authenticateUser(authDetails);
      
      if (session == null) {
        throw CognitoServiceException("session not found");
      }

      final idTokenString = session.idToken.getJwtToken() ?? '';
      final accessTokenString = session.accessToken.getJwtToken() ?? '';

      if (idTokenString.isEmpty || accessTokenString.isEmpty) {
        throw CognitoServiceException("Failed to get valid tokens");
      }

      var claims = <String, dynamic>{};
      claims.addAll(session.idToken.payload);
      claims.addAll(session.accessToken.payload);

      return User(
        email, 
        true, 
        session.isValid(),
        session.idToken.payload['sub'] ?? "", 
        claims,
        idTokenString,
        accessTokenString,
      );
    } catch (e) {
      throw CognitoServiceException(e.toString());
    }
  }
}