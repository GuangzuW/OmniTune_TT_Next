import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/data/services/remote_api.dart';
import 'package:app/features/auth/auth_sheet.dart';
import 'package:app/features/player/equalizer_sheet.dart';
import 'package:app/state/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final authCtrl = ref.read(authControllerProvider.notifier);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppDimens.lg),
        children: [
          const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppDimens.lg),
          _Section(title: 'Account', children: [
            ListTile(
              leading: Icon(auth.loggedIn ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: auth.loggedIn ? AppColors.coral : AppColors.textTertiary),
              title: Text(auth.loggedIn ? 'Signed in' : 'Not signed in'),
              subtitle: Text(auth.loggedIn
                  ? 'Cloud playlists are syncing'
                  : 'Sign in to sync playlists across devices'),
              trailing: auth.loggedIn
                  ? TextButton(onPressed: authCtrl.logout, child: const Text('Log out'))
                  : FilledButton(
                      onPressed: () => AuthSheet.show(context), child: const Text('Log in')),
            ),
          ]),
          _Section(title: 'Audio', children: [
            ListTile(
              leading: const Icon(Icons.equalizer_rounded),
              title: const Text('Equalizer'),
              subtitle: const Text('10-band EQ with presets'),
              onTap: () => EqualizerSheet.show(context),
            ),
          ]),
          _Section(title: 'Backend', children: [
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Aggregator'),
              subtitle: Text(ApiClient.aggregatorUrl),
            ),
            ListTile(
              leading: const Icon(Icons.sync_rounded),
              title: const Text('User sync'),
              subtitle: Text(ApiClient.userSyncUrl),
            ),
          ]),
          _Section(title: 'About', children: const [
            ListTile(
              leading: Icon(Icons.graphic_eq_rounded, color: AppColors.coral),
              title: Text('OmniTune TT Next'),
              subtitle: Text('v1.0 · C++ core · Flutter · Go cloud'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppDimens.xs, AppDimens.lg, 0, AppDimens.sm),
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.sky, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
