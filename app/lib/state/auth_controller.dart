import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/data/services/secure_storage.dart';
import 'package:app/state/providers.dart';

class AuthState {
  final bool loggedIn;
  final bool busy;
  final String? error;
  const AuthState({this.loggedIn = false, this.busy = false, this.error});

  AuthState copyWith({bool? loggedIn, bool? busy, String? error}) =>
      AuthState(loggedIn: loggedIn ?? this.loggedIn, busy: busy ?? this.busy, error: error);
}

/// Auth state + actions. Persists the JWT via secure storage so the session
/// survives restarts (auto-login on launch).
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState();
  }

  Future<void> _restore() async {
    final token = await SecureStore.readToken();
    if (token != null && token.isNotEmpty) {
      ref.read(apiClientProvider).token = token;
      state = state.copyWith(loggedIn: true);
    }
  }

  Future<bool> login(String username, String password) =>
      _run(() => ref.read(apiClientProvider).login(username, password));

  Future<bool> register(String username, String password) =>
      _run(() => ref.read(apiClientProvider).register(username, password));

  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await action();
      final token = ref.read(apiClientProvider).token;
      if (token != null) await SecureStore.writeToken(token);
      state = state.copyWith(busy: false, loggedIn: true);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      return false;
    }
  }

  Future<void> logout() async {
    ref.read(apiClientProvider).logout();
    await SecureStore.deleteToken();
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
