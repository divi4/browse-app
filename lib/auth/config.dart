import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  final String userPoolID;
  final String clientID;
  final String region;
  final String apiEndpoint;
  final String cognitoDomain;
  final String redirectUri;
  final String logoutRedirectUri;

  AppConfig({
    required this.userPoolID,
    required this.clientID,
    required this.region,
    required this.apiEndpoint,
    required this.cognitoDomain,
    required this.redirectUri,
    required this.logoutRedirectUri,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      userPoolID: json['userPoolID'] ?? '',
      clientID: json['clientID'] ?? '',
      region: json['region'] ?? 'ap-southeast-2',
      apiEndpoint: json['apiEndpoint'] ?? '',
      cognitoDomain: json['cognitoDomain'] ?? '',
      redirectUri: json['redirectUri'] ?? '',
      logoutRedirectUri: json['logoutRedirectUri'] ?? '', 
    );
  }
}

Future<AppConfig> loadConfig() async {
  try {
    final String configString = await rootBundle.loadString('assets/config.json');
    final Map<String, dynamic> configJson = json.decode(configString);
    return AppConfig.fromJson(configJson);
  } catch (e) {
    print('Error loading config: $e');
    rethrow;
  }
}