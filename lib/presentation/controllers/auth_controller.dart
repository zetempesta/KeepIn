import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/services/database_service.dart';
import 'notes_controller.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthViewState>(AuthController.new);

@immutable
class AuthViewState {
  const AuthViewState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  AuthViewState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthViewState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends Notifier<AuthViewState> {
  @override
  AuthViewState build() => const AuthViewState();

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await ref.read(authApiServiceProvider).login(
            username: username.trim(),
            password: password,
          );
      ref.read(authSessionProvider.notifier).state = session;
      ref.invalidate(notesControllerProvider);
      ref.invalidate(labelsCatalogProvider);
      ref.read(selectedLabelProvider.notifier).state = null;
      ref.read(notesSearchQueryProvider.notifier).state = '';
      ref.read(labelsSearchQueryProvider.notifier).state = '';
      state = const AuthViewState();
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _toFriendlyAuthError(error),
      );
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await ref.read(authApiServiceProvider).register(
            username: username.trim(),
            password: password,
          );
      ref.read(authSessionProvider.notifier).state = session;
      ref.invalidate(notesControllerProvider);
      ref.invalidate(labelsCatalogProvider);
      ref.read(selectedLabelProvider.notifier).state = null;
      ref.read(notesSearchQueryProvider.notifier).state = '';
      ref.read(labelsSearchQueryProvider.notifier).state = '';
      state = const AuthViewState();
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _toFriendlyAuthError(error, isRegistration: true),
      );
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }

    state = state.copyWith(clearError: true);
  }

  void logout() {
    ref.read(authSessionProvider.notifier).state = null;
    ref.invalidate(notesControllerProvider);
    ref.invalidate(labelsCatalogProvider);
    ref.read(selectedLabelProvider.notifier).state = null;
    ref.read(notesSearchQueryProvider.notifier).state = '';
    ref.read(labelsSearchQueryProvider.notifier).state = '';
    state = const AuthViewState();
  }
}

String _toFriendlyAuthError(
  Object error, {
  bool isRegistration = false,
}) {
  if (error is NotesApiException) {
    if (error.message.contains('Backend request failed (401)')) {
      return 'Usuario ou senha incorretos. Verifique seus dados e tente novamente.';
    }

    if (error.message.contains('Backend request failed (409)')) {
      return 'Esse nome de usuario ja esta em uso. Escolha outro.';
    }

    final message = error.message;
    final separatorIndex = message.indexOf('):');
    final cleaned = separatorIndex >= 0
        ? message.substring(separatorIndex + 2).trim()
        : message.trim();
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }

  return isRegistration
      ? 'Nao foi possivel criar sua conta agora. Tente novamente em instantes.'
      : 'Nao foi possivel entrar agora. Tente novamente em instantes.';
}
