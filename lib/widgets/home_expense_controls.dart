import 'package:flutter/material.dart';

enum ExpenseFilter { all, open, settled }

class ExpenseHomeHeading extends StatelessWidget {
  const ExpenseHomeHeading({
    super.key,
    required this.billCount,
    required this.searching,
    required this.onSearch,
  });

  final int billCount;
  final bool searching;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Expenses', style: theme.textTheme.headlineLarge),
              ),
              const SizedBox(height: 4),
              Text(
                billCount == 0
                    ? 'Good times. Clear splits.'
                    : '$billCount shared ${billCount == 1 ? 'expense' : 'expenses'}, all in one place.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.outlined(
          tooltip: searching ? 'Close search' : 'Search expenses',
          onPressed: onSearch,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerLowest,
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            minimumSize: const Size(48, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: Icon(searching ? Icons.close_rounded : Icons.search_rounded),
        ),
      ]),
    );
  }
}

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

class ExpenseListHeading extends StatelessWidget {
  const ExpenseListHeading({
    super.key,
    required this.count,
    required this.filtered,
    required this.oldestFirst,
    required this.onSort,
  });

  final int count;
  final bool filtered;
  final bool oldestFirst;
  final ValueChanged<bool> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Semantics(
          header: true,
          child: Text(
            filtered
                ? '$count ${count == 1 ? 'result' : 'results'}'
                : 'Recent activity',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        PopupMenuButton<bool>(
          tooltip: 'Sort expenses',
          initialValue: oldestFirst,
          onSelected: onSort,
          itemBuilder: (_) => const [
            PopupMenuItem(value: false, child: Text('Newest first')),
            PopupMenuItem(value: true, child: Text('Oldest first')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.swap_vert_rounded,
                  size: 17, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(oldestFirst ? 'Oldest first' : 'Newest first',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ]),
          ),
        ),
      ],
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
