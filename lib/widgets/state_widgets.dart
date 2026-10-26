import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shared async-state UI: shimmer skeletons for loading, an error view
/// with retry, and a guard helper for fire-and-forget actions.
///
/// The shimmer colors come from the ambient [ColorScheme], so the
/// placeholders look right in both light and dark themes. Only the
/// shape of a skeleton matters (its own color is replaced by the
/// shimmer gradient), hence the plain white boxes below.

Widget _shimmerWrap(BuildContext context, Widget child) {
  final scheme = Theme.of(context).colorScheme;
  return Shimmer.fromColors(
    baseColor: scheme.surfaceContainerHighest,
    highlightColor: scheme.surfaceContainerLow,
    child: child,
  );
}

/// A single placeholder block.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// One skeleton row: round avatar + two text lines (+ trailing block).
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({this.trailing = true});

  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 150, height: 13),
              SizedBox(height: 8),
              ShimmerBox(width: 210, height: 11),
            ],
          ),
        ),
        if (trailing) ...[
          const SizedBox(width: 12),
          const ShimmerBox(width: 52, height: 16),
        ],
      ],
    );
  }
}

/// A standalone shimmer block (its own [Shimmer] wrapper) — handy as
/// an image placeholder.
class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 0,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      context,
      ShimmerBox(width: width, height: height, radius: radius),
    );
  }
}

/// Skeleton for card-style lists (bills, balances, friends, groups,
/// notifications): [count] card silhouettes with a row inside each.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 4, this.padding});

  final int count;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      context,
      ListView.separated(
        padding: padding ?? const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const _SkeletonRow(),
        ),
      ),
    );
  }
}

/// Skeleton rows without cards, for sections embedded in a scrolling
/// page (group members, invitees, friend requests…).
class ShimmerRows extends StatelessWidget {
  const ShimmerRows({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            const _SkeletonRow(trailing: false),
          ],
        ],
      ),
    );
  }
}

/// Skeleton for detail screens: a summary card silhouette followed by
/// a section title and rows.
class ShimmerDetail extends StatelessWidget {
  const ShimmerDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      context,
      ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 20),
          const ShimmerBox(width: 110, height: 16),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const _SkeletonRow(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Friendly error state for a failed load, with an optional Retry.
/// Use the [LoadError.compact] variant inside page sections.
class LoadError extends StatelessWidget {
  const LoadError({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  const LoadError.compact({
    super.key,
    required this.message,
    this.onRetry,
  }) : compact = true;

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: scheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Runs a fire-and-forget repository action (accept/decline invite,
/// cancel request, sign out…) and surfaces any failure as a SnackBar
/// instead of an unhandled async error.
Future<void> runGuarded(
  BuildContext context,
  Future<void> Function() action, {
  required String errorLabel,
}) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errorLabel: $e')),
      );
    }
  }
}
