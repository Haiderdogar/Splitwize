import 'package:currency_picker/currency_picker.dart';
import 'package:intl/intl.dart';

/// Display symbol for an ISO 4217 currency [code] (e.g. 'PKR' → '₨'),
/// falling back to the code itself when unknown.
String currencySymbol(String code) =>
    CurrencyService().findByCode(code)?.symbol ?? code;

/// Full display name for a currency [code], e.g.
/// 'Pakistani Rupee (PKR · ₨)'.
String currencyLabel(String code) {
  final c = CurrencyService().findByCode(code);
  if (c == null) return code;
  return '${c.name} ($code · ${c.symbol})';
}

/// Grouping locale for a currency: PKR and INR group digits
/// lakh-style (1,25,000), as readers in Pakistan and India expect.
/// Every other currency keeps the default (Western) grouping.
String? _groupingLocale(String code) =>
    (code == 'PKR' || code == 'INR') ? 'en_IN' : null;

/// Formats [value] in the given ISO currency (default USD) with the
/// currency's real symbol — ₨ for PKR, € for EUR, $ for USD…
String formatMoney(double value, [String currencyCode = 'USD']) =>
    NumberFormat.currency(
      locale: _groupingLocale(currencyCode),
      symbol: currencySymbol(currencyCode),
      decimalDigits: 2,
    ).format(value);

/// Number part only (no symbol), same grouping and decimals as
/// [formatMoney] — for widgets that style the symbol separately from
/// the digits (see [MoneyText]).
String formatMoneyNumber(double value, [String currencyCode = 'USD']) =>
    NumberFormat.currency(
      locale: _groupingLocale(currencyCode),
      symbol: '',
      decimalDigits: 2,
    ).format(value).trim();
