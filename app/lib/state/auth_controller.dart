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
    final access = await SecureStore.readToken();
    final refresh = await SecureStore.readRefresh();
    if ((access == null || access.isEmpty) && (refresh == null || refresh.isEmpty)) {
      return;
    }
    final api = ref.read(apiClientProvider);
    api.setTokens(access: access, refresh: refresh);
    // Access tokens are short-lived; mint a fresh one from the refresh token.
    if (refresh != null && refresh.isNotEmpty) {
      final ok = await api.refresh();
      if (ok && api.accessToken != null) {
        await SecureStore.writeToken(api.accessToken!);
      }
    }
    state = state.copyWith(loggedIn: api.isLoggedIn);
  }

  Future<bool> login(String username, String password) =>
      _run(() => ref.read(apiClientProvider).login(username, password));

  Future<bool> register(String username, String password) =>
      _run(() => ref.read(apiClientProvider).register(username, password));

  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await action();
      final api = ref.read(apiClientProvider);
      if (api.accessToken != null) await SecureStore.writeToken(api.accessToken!);
      if (api.refreshToken != null) await SecureStore.writeRefresh(api.refreshToken!);
      state = state.copyWith(busy: false, loggedIn: true);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(apiClientProvider).logout();
    await SecureStore.deleteToken();
    await SecureStore.deleteRefresh();
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
