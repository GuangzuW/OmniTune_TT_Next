import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits true when the device has network connectivity. While unknown
/// (loading), callers should assume online to avoid false offline banners.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
        (results) => results.isNotEmpty && !results.contains(ConnectivityResult.none),
      );
});
