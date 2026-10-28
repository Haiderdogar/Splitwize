import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/money.dart';

/// An amount rendered the way the app's money hierarchy wants it: a
/// small muted currency symbol beside a bold, tabular-figure amount,
/// so columns of money align and scan at a glance. Screen readers get
/// the full "symbol amount" string as one label.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    super.key,
    this.currencyCode = 'USD',
    this.style,
    this.symbolStyle,
    this.textAlign,
    this.color,
  });

  final double value;
  final String currencyCode;

  /// Style for the digits; bold weight and tabular figures are always
  /// applied on top. Defaults to the theme's titleMedium.
  final TextStyle? style;

  /// Style for the symbol; defaults to a small muted style.
  final TextStyle? symbolStyle;
  final TextAlign? textAlign;

  /// Overrides the amount color (e.g. owed green / owe amber); the
  /// symbol then renders in the same color at reduced opacity.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = (style ?? theme.textTheme.titleMedium)?.copyWith(
      fontWeight: FontWeight.bold,
      fontFeatures: [const ui.FontFeature.tabularFigures()],
      color: color,
    );
    final symStyle = symbolStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: color?.withValues(alpha: 0.75) ??
              theme.colorScheme.onSurfaceVariant,
        );
    return Semantics(
      label: formatMoney(value, currencyCode),
      child: ExcludeSemantics(
        child: RichText(
          textAlign: textAlign ?? TextAlign.start,
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: '${currencySymbol(currencyCode)} ',
                style: symStyle,
              ),
              TextSpan(
                text: formatMoneyNumber(value, currencyCode),
                style: amountStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
