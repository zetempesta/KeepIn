import 'package:flutter/foundation.dart';

@immutable
class AuthSessionData {
  const AuthSessionData({
    required this.username,
    required this.token,
  });

  final String username;
  final String token;
}
