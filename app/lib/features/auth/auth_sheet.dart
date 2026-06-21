import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';
import 'package:app/state/auth_controller.dart';

class AuthSheet extends ConsumerStatefulWidget {
  const AuthSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusLg)),
        ),
        builder: (_) => const AuthSheet(),
      );

  @override
  ConsumerState<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends ConsumerState<AuthSheet> {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit(bool register) async {
    final auth = ref.read(authControllerProvider.notifier);
    final ok = register
        ? await auth.register(_user.text.trim(), _pass.text)
        : await auth.login(_user.text.trim(), _pass.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.xl,
        right: AppDimens.xl,
        top: AppDimens.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Cloud account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppDimens.lg),
          TextField(controller: _user, decoration: const InputDecoration(hintText: 'Username')),
          const SizedBox(height: AppDimens.md),
          TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password')),
          if (state.error != null) ...[
            const SizedBox(height: AppDimens.sm),
            Text(state.error!, style: const TextStyle(color: AppColors.coral, fontSize: 12)),
          ],
          const SizedBox(height: AppDimens.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.busy ? null : () => _submit(true),
                  child: const Text('Register'),
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: FilledButton(
                  onPressed: state.busy ? null : () => _submit(false),
                  child: state.busy
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Log in'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
