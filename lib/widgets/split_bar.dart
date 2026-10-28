import 'package:flutter/material.dart';

/// One segment of a [SplitBar]: a share of a total, drawn in a stable
/// hue. [label] is informational only — the bar itself is visual; the
/// rows around it carry names and amounts.
class SplitSegment {
  const SplitSegment({
    this.label = '',
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Stable hues for split participants, by position (wraps past 8).
const splitHues = <Color>[
  Colors.teal,
  Colors.orange,
  Colors.purple,
  Colors.blue,
  Colors.pink,
  Colors.amber,
  Colors.cyan,
  Colors.lime,
];

/// The app's signature motif: a segmented bar visualising how one
/// total splits between people, each share's width its proportion.
/// Used on bill detail (above the share list) and as a live preview
/// while editing a split. Purely visual — screen readers get one
/// summary label instead of a row of colored boxes.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.segments, this.height = 12});

  final List<SplitSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold(0.0, (sum, s) => sum + s.value);
    final visible = segments.where((s) => s.value > 0).toList();
    if (total <= 0 || visible.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Split between ${visible.length} people',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final s in visible)
                Expanded(
                  // Proportional flex, rounded so shares add to 1000.
                  flex: (s.value / total * 1000).round().clamp(1, 1000),
                  child: Container(color: s.color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
