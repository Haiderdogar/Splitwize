/// Unallocated remainder while a split is being edited, or null when
/// the split type needs none (equal splits are always exact).
/// Returns percent points for percentage splits ("20" = 20% left) and
/// money for custom splits. Unparseable entries count as zero here;
/// submit-time validation still rejects them.
double? unallocatedRemainder({
  required String splitType,
  required Set<String> selected,
  required Map<String, String> percents,
  required Map<String, String> amounts,
  required double total,
}) {
  double parse(String? v) =>
      double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0;
  switch (splitType) {
    case 'percentage':
      var sum = 0.0;
      for (final uid in selected) {
        sum += parse(percents[uid]);
      }
      return 100 - sum;
    case 'custom':
      var sum = 0.0;
      for (final uid in selected) {
        sum += parse(amounts[uid]);
      }
      return total - sum;
    default:
      return null;
  }
}
