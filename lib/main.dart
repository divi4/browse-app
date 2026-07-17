import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/login_screen.dart';
import 'gatherer-view/requests.dart';
import 'caretaker-view/order.dart';

import 'landowner-view/overview.dart';
import 'landowner-view/landowner_registration.dart';

import 'education/browse_list.dart';

import 'personal/profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
runApp(
    MaterialApp(
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/request-board': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return GathererRoute(user: args['user']);
        },
        '/caretaker': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return CaretakerRoute(user: args['user']);
        },
        '/landowner': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return LandownerRoute(
            user: args['user'],
            browseFilter: args['browseFilter'],
            uploadSuccess: args['uploadSuccess'] ?? false,
            );
        },
        '/landowner-registration': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return LandownerRegistration(user: args['user']);
        },
        '/education': (context) {
          return BrowseListPage();
        },
        '/profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ProfileRoute(user: args['user']);
        },
      },
    ),
  );
}