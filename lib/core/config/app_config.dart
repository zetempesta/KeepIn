import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const String _productionApiBaseUrl = String.fromEnvironment(
    'KEEPIN_API_BASE_URL',
    defaultValue: 'https://keepin.onrender.com',
  );

  static String get apiBaseUrl {
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://127.0.0.1:8000';
      }

      return _productionApiBaseUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }
}
