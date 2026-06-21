import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_dimens.dart';

/// Centered loading spinner.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.coral));
}

/// Friendly empty state with an icon, message and optional action.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyView({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.navy),
            const SizedBox(height: AppDimens.md),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textTertiary)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDimens.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry affordance.
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.coral),
            const SizedBox(height: AppDimens.md),
            Text('Something went wrong',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppDimens.xs),
            Text('$error',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimens.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading/error/empty handling.
extension AsyncViewX<T> on AsyncValue<T> {
  Widget view(
    Widget Function(T data) onData, {
    VoidCallback? onRetry,
  }) {
    return when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry),
      data: onData,
    );
  }
}
