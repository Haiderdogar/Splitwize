import 'package:currency_picker/currency_picker.dart';
import 'package:intl/intl.dart';

/// Display symbol for an ISO 4217 currency [code] (e.g. 'PKR' → 'Rs'),
/// falling back to the code itself when unknown.
String currencySymbol(String code) =>
    CurrencyService().findByCode(code)?.symbol ?? code;

/// Full display name for a currency [code], e.g.
/// 'Pakistani Rupee (PKR · Rs)'.
String currencyLabel(String code) {
  final c = CurrencyService().findByCode(code);
  if (c == null) return code;
  return '${c.name} ($code · ${c.symbol})';
}

/// Formats [value] in the given ISO currency (default USD) with the
/// currency's real symbol — Rs for PKR, € for EUR, $ for USD…
String formatMoney(double value, [String currencyCode = 'USD']) =>
    NumberFormat.currency(
            symbol: currencySymbol(currencyCode), decimalDigits: 2)
        .format(value);
