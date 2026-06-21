import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_dimens.dart';
import 'package:app/state/connectivity.dart';

/// A thin bar shown only when the device is known to be offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).value ?? true;
    if (online) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFF6B2016),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 16, color: Colors.white),
            SizedBox(width: AppDimens.sm),
            Text('You are offline — streaming and sync are unavailable',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
