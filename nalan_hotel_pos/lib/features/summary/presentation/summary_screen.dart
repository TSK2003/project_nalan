import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/pos_data_service.dart';
import '../../../core/utils/formatters.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    try {
      final response = await PosDataService.instance.getSummary(
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = response;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialDate =
        isFrom
            ? (_fromDate ?? DateTime.now())
            : (_toDate ?? _fromDate ?? DateTime.now());
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _fromDate = pickedDate;
        if (_toDate != null && _toDate!.isBefore(pickedDate)) {
          _toDate = pickedDate;
        }
      } else {
        _toDate = pickedDate;
        if (_fromDate != null && _fromDate!.isAfter(pickedDate)) {
          _fromDate = pickedDate;
        }
      }
    });
  }

  Future<void> _applyDateRange() async {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both from and to dates')),
      );
      return;
    }

    if (_fromDate!.isAfter(_toDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date cannot be after to date')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await _fetchSummary();
  }

  Future<void> _resetToToday() async {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _isLoading = true;
    });
    await _fetchSummary();
  }

  int _metricGridCount(double width) {
    if (width >= 1080) {
      return 4;
    }
    if (width >= 640) {
      return 2;
    }
    return 1;
  }

  double _metricAspectRatio(double width, int crossAxisCount) {
    if (crossAxisCount == 1) {
      return width < 420 ? 2.8 : 3.2;
    }
    if (crossAxisCount == 2) {
      return width < 840 ? 1.55 : 1.8;
    }
    return 1.4;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final outerPadding = screenWidth < 600 ? 12.0 : 16.0;
    final isRangeMode = _fromDate != null && _toDate != null;
    final summaryLabel =
        isRangeMode && _summary != null
            ? 'Range: ${AppFormatters.date(DateTime.parse(_summary!['date_from']))} to ${AppFormatters.date(DateTime.parse(_summary!['date_to']))}'
            : _summary != null && _summary!['date'] != null
            ? 'Date: ${AppFormatters.date(DateTime.parse(_summary!['date']))}'
            : 'Date: Today';

    final metricCards = <Widget>[
      _summaryCard(
        'Total Sales',
        AppFormatters.currencyExact(
          double.parse(_summary?['total_sales'].toString() ?? '0'),
        ),
        Icons.payments,
        color: primaryColor,
      ),
      _summaryCard(
        'Total Bills',
        _summary?['total_bills'].toString() ?? '0',
        Icons.receipt,
        color: primaryColor,
      ),
      _summaryCard(
        'Cash',
        AppFormatters.currencyExact(
          double.parse(_summary?['cash_total'].toString() ?? '0'),
        ),
        Icons.money,
        color: Colors.green,
      ),
      _summaryCard(
        'UPI',
        AppFormatters.currencyExact(
          double.parse(_summary?['upi_total'].toString() ?? '0'),
        ),
        Icons.qr_code_2,
        color: Colors.blue,
      ),
    ];

    if (double.parse(_summary?['split_total'].toString() ?? '0') > 0) {
      metricCards.add(
        _summaryCard(
          'Split Payment Total',
          AppFormatters.currencyExact(
            double.parse(_summary!['split_total'].toString()),
          ),
          Icons.call_split_outlined,
          color: Colors.purple,
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Summary'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchSummary();
              },
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _summary == null
                ? const Center(child: Text('Failed to load summary'))
                : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final metricGridCount = _metricGridCount(
                          constraints.maxWidth,
                        );
                        final chartSize = (constraints.maxWidth *
                                (constraints.maxWidth < 700 ? 0.46 : 0.28))
                            .clamp(150.0, 250.0);

                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            outerPadding,
                            outerPadding,
                            outerPadding,
                            outerPadding + mediaQuery.padding.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date Filter',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      summaryLabel,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed:
                                              () => _pickDate(isFrom: true),
                                          icon: const Icon(
                                            Icons.date_range_outlined,
                                          ),
                                          label: Text(
                                            _fromDate == null
                                                ? 'From'
                                                : AppFormatters.date(
                                                  _fromDate!,
                                                ),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed:
                                              () => _pickDate(isFrom: false),
                                          icon: const Icon(
                                            Icons.event_outlined,
                                          ),
                                          label: Text(
                                            _toDate == null
                                                ? 'To'
                                                : AppFormatters.date(_toDate!),
                                          ),
                                        ),
                                        FilledButton(
                                          onPressed: _applyDateRange,
                                          child: const Text('Apply'),
                                        ),
                                        TextButton(
                                          onPressed: _resetToToday,
                                          child: const Text('Today'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: metricGridCount,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: _metricAspectRatio(
                                        constraints.maxWidth,
                                        metricGridCount,
                                      ),
                                    ),
                                itemCount: metricCards.length,
                                itemBuilder: (context, index) {
                                  return metricCards[index];
                                },
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Category Breakdown',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if ((_summary!['category_breakdown'] as Map)
                                  .isEmpty)
                                const Text('No sales yet for today.')
                              else ...[
                                Center(
                                  child: SizedBox(
                                    width: chartSize,
                                    height: chartSize,
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: chartSize * 0.14,
                                        sections:
                                            (_summary!['category_breakdown']
                                                    as Map)
                                                .entries
                                                .map((e) {
                                                  final color =
                                                      _getCategoryColor(e.key);
                                                  final pct =
                                                      double.tryParse(
                                                        e.value['percentage']
                                                            .toString(),
                                                      ) ??
                                                      0;
                                                  return PieChartSectionData(
                                                    color: color,
                                                    value: pct,
                                                    title: '$pct%',
                                                    radius: chartSize * 0.20,
                                                    titleStyle: TextStyle(
                                                      fontSize:
                                                          chartSize < 180
                                                              ? 10
                                                              : 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...(_summary!['category_breakdown'] as Map)
                                    .entries
                                    .map((e) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              color: _getCategoryColor(e.key),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                e.key,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              AppFormatters.currencyExact(
                                                double.parse(
                                                  e.value['total'].toString(),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final cardColor = color ?? Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: cardColor, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cardColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'TIFFIN':
        return Colors.orange;
      case 'LUNCH':
        return Colors.green;
      case 'DINNER':
        return Colors.indigo;
      case 'BEVERAGES':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
