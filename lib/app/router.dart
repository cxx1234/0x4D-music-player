import 'package:flutter/material.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const SizedBox.shrink(),
      settings: settings,
    );
  }
}
