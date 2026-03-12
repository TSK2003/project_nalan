import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/data/pos_data_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/app_text_field.dart';

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
      final bills = await PosDataService.instance.listBills(query: _searchQuery);
      if (!mounted) {
        return;
      }
      setState(() {
        _bills = bills;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  bool _isPayableStatus(String status) {
    return status == 'DRAFT' || status == 'PENDING_PAYMENT';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
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
            padding: const EdgeInsets.all(16.0),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _bills.length,
                        itemBuilder: (context, index) {
                          final bill = _bills[index];
                          final isPayable = _isPayableStatus(
                            bill['status'] as String? ?? '',
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap:
                                  () => context.push(
                                    isPayable
                                        ? '/payment/${bill['id']}'
                                        : '/receipt/${bill['id']}',
                                  ),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    bill['bill_number'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  StatusBadge(status: bill['status']),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormatters.dateTime(
                                      DateTime.parse(bill['created_at']),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Items: ${bill['item_count']} | Mode: ${bill['payment_mode'] ?? 'N/A'}'
                                    '${bill['upi_id_used'] != null ? ' (${bill['upi_id_used']})' : ''}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                AppFormatters.currencyExact(
                                  double.parse(bill['total_amount'].toString()),
                                ),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
