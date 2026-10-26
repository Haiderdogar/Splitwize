import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const BillSplitterApp());
}

class BillSplitterApp extends StatelessWidget {
  const BillSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Splitwize',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const BillSplitterPage(),
    );
  }
}

class BillSplitterPage extends StatefulWidget {
  const BillSplitterPage({super.key});

  @override
  State<BillSplitterPage> createState() => _BillSplitterPageState();
}

class _BillSplitterPageState extends State<BillSplitterPage> {
  final _billController = TextEditingController();
  double _tipPercent = 15;
  int _people = 2;
  bool _roundUp = false;

  @override
  void dispose() {
    _billController.dispose();
    super.dispose();
  }

  double get _billAmount {
    final parsed = double.tryParse(_billController.text.replaceAll(',', '.'));
    if (parsed == null || parsed < 0) return 0;
    return parsed;
  }

  double get _tipAmount => _billAmount * _tipPercent / 100;

  double get _total => _billAmount + _tipAmount;

  double get _perPerson {
    if (_people <= 0) return 0;
    var value = _total / _people;
    if (_roundUp) value = value.ceilToDouble();
    return value;
  }

  String _fmt(double value) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(value);
  }

  void _reset() {
    setState(() {
      _billController.clear();
      _tipPercent = 15;
      _people = 2;
      _roundUp = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Splitwize'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Result card
            Card(
              elevation: 2,
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Column(
                  children: [
                    Text(
                      'Each person pays',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fmt(_perPerson),
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _SummaryItem(
                          label: 'Bill',
                          value: _fmt(_billAmount),
                        ),
                        _SummaryItem(
                          label: 'Tip (${_tipPercent.toStringAsFixed(0)}%)',
                          value: _fmt(_tipAmount),
                        ),
                        _SummaryItem(
                          label: 'Total',
                          value: _fmt(_total),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Bill amount input
            TextField(
              controller: _billController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Bill amount',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Tip selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tip',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${_tipPercent.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [10, 15, 18, 20, 25].map((p) {
                final selected = _tipPercent == p.toDouble();
                return ChoiceChip(
                  label: Text('$p%'),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _tipPercent = p.toDouble()),
                );
              }).toList(),
            ),
            Slider(
              value: _tipPercent,
              min: 0,
              max: 30,
              divisions: 30,
              label: '${_tipPercent.toStringAsFixed(0)}%',
              onChanged: (v) => setState(() => _tipPercent = v),
            ),
            const SizedBox(height: 8),

            // People stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Split between',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _people > 1
                          ? () => setState(() => _people--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$_people',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _people < 20
                          ? () => setState(() => _people++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Round up toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Round up per person'),
              subtitle:
                  const Text('Round each share up to the nearest dollar'),
              value: _roundUp,
              onChanged: (v) => setState(() => _roundUp = v),
            ),
            const SizedBox(height: 24),

            // Reset button
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
