import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/pos_data_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/status_badge.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<dynamic> _bills = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBills();
  }

  Future<void> _fetchBills() async {
    setState(() => _isLoading = true);
    try {
      final bills = await PosDataService.instance.listBills(
        query: _searchQuery,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bills = bills;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  bool _isPayableStatus(String status) {
    return status == 'DRAFT' || status == 'PENDING_PAYMENT';
  }

  String _paymentSummary(dynamic bill) {
    final mode = (bill['payment_mode'] as String?)?.toUpperCase();
    if (mode == 'SPLIT') {
      final cash =
          double.tryParse(bill['cash_received']?.toString() ?? '') ?? 0;
      final upi = double.tryParse(bill['upi_amount']?.toString() ?? '') ?? 0;
      return 'Mode: Cash ${AppFormatters.currencyExact(cash)} + UPI ${AppFormatters.currencyExact(upi)}';
    }

    return 'Mode: ${mode ?? 'N/A'}'
        '${bill['upi_id_used'] != null ? ' (${bill['upi_id_used']})' : ''}';
  }

  Future<String?> _askPaymentMode() {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SafeArea(
          child: AlertDialog(
            title: const Text('Select Payment Method'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.money),
                    title: const Text('Cash'),
                    subtitle: const Text('Open direct cash payment'),
                    onTap: () => Navigator.of(dialogContext).pop('CASH'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.qr_code_2),
                    title: const Text('UPI'),
                    subtitle: const Text('Open full UPI payment'),
                    onTap: () => Navigator.of(dialogContext).pop('UPI'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.call_split),
                    title: const Text('UPI + Cash'),
                    subtitle: const Text(
                      'Enter cash first, then collect balance by UPI',
                    ),
                    onTap: () => Navigator.of(dialogContext).pop('SPLIT'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBill(dynamic bill) async {
    final isPayable = _isPayableStatus(bill['status'] as String? ?? '');
    if (!isPayable) {
      context.push('/receipt/${bill['id']}');
      return;
    }

    final paymentMode = await _askPaymentMode();
    if (!mounted || paymentMode == null) {
      return;
    }

    context.push('/payment/${bill['id']}?mode=$paymentMode');
  }

  Widget _buildBillCard(dynamic bill, Color primaryColor) {
    final amountText = Text(
      AppFormatters.currencyExact(
        double.parse(bill['total_amount'].toString()),
      ),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openBill(bill),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 440;

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            bill['bill_number'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: bill['status']),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppFormatters.dateTime(
                        DateTime.parse(bill['created_at']),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Items: ${bill['item_count']} | ${_paymentSummary(bill)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: amountText),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                bill['bill_number'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: bill['status']),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppFormatters.dateTime(
                            DateTime.parse(bill['created_at']),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Items: ${bill['item_count']} | ${_paymentSummary(bill)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  amountText,
                ],
              );
            },
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Bill History'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _searchController.clear();
                _searchQuery = '';
                _fetchBills();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppTextField(
                controller: _searchController,
                label: 'Search by Bill Number or Amount',
                prefixIcon: Icons.search,
                onChanged: (val) {
                  _searchQuery = val;
                  if (_searchQuery.length > 2 || _searchQuery.isEmpty) {
                    _fetchBills();
                  }
                },
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _bills.isEmpty
                      ? const Center(child: Text('No bills found.'))
                      : RefreshIndicator(
                        onRefresh: _fetchBills,
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16 + mediaQuery.padding.bottom,
                          ),
                          itemCount: _bills.length,
                          itemBuilder: (context, index) {
                            return _buildBillCard(_bills[index], primaryColor);
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
