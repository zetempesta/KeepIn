import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session.dart';
import '../config/app_config.dart';
import '../../data/repositories/notes_repository_impl.dart';
import '../../data/services/database_service.dart';
import '../../domain/repositories/notes_repository.dart';

final authSessionProvider = StateProvider<AuthSessionData?>((ref) => null);

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  final service = AuthApiService(
    baseUrl: AppConfig.apiBaseUrl,
  );

  ref.onDispose(service.dispose);
  return service;
});

final notesApiServiceProvider = Provider<NotesApiService>((ref) {
  final authToken =
      ref.watch(authSessionProvider.select((value) => value?.token));
  final service = NotesApiService(
    baseUrl: AppConfig.apiBaseUrl,
    authToken: authToken,
  );

  ref.onDispose(service.dispose);
  return service;
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepositoryImpl(ref.watch(notesApiServiceProvider));
});
