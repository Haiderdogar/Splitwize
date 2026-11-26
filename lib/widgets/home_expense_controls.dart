import 'package:flutter/material.dart';

/// The order here is the order of the chips: unsettled first, since that is
/// what people open the app to see.
enum ExpenseFilter { open, settled, all }

class ExpenseFilterBar extends StatelessWidget {
  const ExpenseFilterBar({
    super.key,
    required this.total,
    required this.settled,
    required this.selected,
    required this.onSelected,
  });

  final int total;
  final int settled;
  final ExpenseFilter selected;
  final ValueChanged<ExpenseFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final option in ExpenseFilter.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(switch (option) {
                ExpenseFilter.all => 'All ($total)',
                ExpenseFilter.open => 'Unsettled (${total - settled})',
                ExpenseFilter.settled => 'Settled ($settled)',
              }),
              showCheckmark: false,
              selected: selected == option,
              onSelected: (_) => onSelected(option),
              selectedColor: scheme.primaryContainer,
              backgroundColor: scheme.surfaceContainerLowest,
              labelStyle: TextStyle(
                color: selected == option
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected == option
                    ? scheme.primaryContainer
                    : scheme.outlineVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              shape: const StadiumBorder(),
            ),
          ),
      ]),
    );
  }
}

class ExpenseDateHeading extends StatelessWidget {
  const ExpenseDateHeading({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(children: [
        Semantics(
          header: true,
          child: Text(label,
              style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
      ]),
    );
  }
}
