import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over flutter_secure_storage for the auth token(s).
abstract final class SecureStore {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'omnitune_access_token';
  static const _kRefresh = 'omnitune_refresh_token';

  static Future<String?> readToken() => _storage.read(key: _kToken);
  static Future<void> writeToken(String t) => _storage.write(key: _kToken, value: t);
  static Future<void> deleteToken() => _storage.delete(key: _kToken);

  static Future<String?> readRefresh() => _storage.read(key: _kRefresh);
  static Future<void> writeRefresh(String t) => _storage.write(key: _kRefresh, value: t);
  static Future<void> deleteRefresh() => _storage.delete(key: _kRefresh);
}
