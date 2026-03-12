import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/data/pos_data_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final int billId;

  const PaymentScreen({super.key, required this.billId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  Map<String, dynamic>? _bill;
  bool _isLoading = true;
  String _paymentMode = 'CASH';
  bool _isProcessing = false;

  final _cashController = TextEditingController();
  double _cashChange = 0;

  String? _upiQrString;
  Timer? _pollingTimer;
  List<dynamic> _upiAccounts = [];
  int? _selectedUpiAccountId;
  bool _isLoadingUpiAccounts = true;

  @override
  void initState() {
    super.initState();
    _fetchBill();
    _fetchUpiAccounts();
  }

  Future<void> _fetchBill() async {
    try {
      final bill = await PosDataService.instance.getBill(widget.billId);
      final totalAmount = double.parse(bill['total_amount'].toString());
      if (!mounted) {
        return;
      }

      setState(() {
        _bill = bill;
        _isLoading = false;
        _cashController.text = totalAmount.toStringAsFixed(2);
        _cashChange = 0;
        if (bill['status'] == 'PENDING_PAYMENT' &&
            bill['payment_mode'] == 'UPI') {
          _paymentMode = 'UPI';
        }
      });

      if (bill['status'] == 'PENDING_PAYMENT' &&
          bill['payment_mode'] == 'UPI') {
        await _restorePendingUpiPayment();
      }
    } catch (e) {
      if (mounted) {
        context.pop();
      }
    }
  }

  Future<void> _restorePendingUpiPayment() async {
    try {
      final response = await PosDataService.instance.paymentStatus(
        widget.billId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _upiQrString = response['upi_qr_string'] as String?;
      });
      if (_upiQrString != null) {
        _startPolling();
      }
    } catch (_) {
      // Ignore restore failures and let the user regenerate the QR.
    }
  }

  Future<void> _fetchUpiAccounts() async {
    try {
      final accounts = await PosDataService.instance.listUpiAccounts();
      if (!mounted) {
        return;
      }

      setState(() {
        _upiAccounts = accounts;
        if (_upiAccounts.isNotEmpty) {
          final defaultAccount = _upiAccounts.firstWhere(
            (account) => account['is_default'] == true,
            orElse: () => _upiAccounts.first,
          );
          _selectedUpiAccountId = defaultAccount['id'] as int;
        }
        _isLoadingUpiAccounts = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUpiAccounts = false);
      }
    }
  }

  void _calculateChange(String value) {
    final cash = double.tryParse(value) ?? 0;
    final total = double.parse(_bill!['total_amount'].toString());

    setState(() {
      _cashChange = cash > total ? cash - total : 0;
    });
  }

  Future<void> _confirmCashPayment() async {
    final cash = double.tryParse(_cashController.text) ?? 0;
    final total = double.parse(_bill!['total_amount'].toString());

    if (cash < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash received is less than total')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await PosDataService.instance.confirmCashPayment(
        widget.billId,
        cashReceived: cash,
      );

      if (mounted) {
        context.go('/receipt/${widget.billId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment failed')));
      }
    }
  }

  Future<void> _initiateUpiPayment() async {
    if (_selectedUpiAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active UPI account available')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final response = await PosDataService.instance.initiateUpiPayment(
        widget.billId,
        upiAccountId: _selectedUpiAccountId!,
      );

      setState(() {
        _upiQrString = response['upi_qr_string'] as String?;
        _isProcessing = false;
      });
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate UPI QR')),
        );
      }
    }
  }

  Future<void> _simulateWebhookSuccess(double total) async {
    await PosDataService.instance.simulateUpiWebhookSuccess(widget.billId);
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final response = await PosDataService.instance.paymentStatus(
          widget.billId,
        );
        final paymentStatus = response['status'];
        if (paymentStatus == 'PAID' && mounted) {
          timer.cancel();
          context.go('/receipt/${widget.billId}');
        }
      } catch (_) {
        // Ignore transient polling failures while the user stays on the screen.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = double.parse(_bill!['total_amount'].toString());
    final isWideLayout = MediaQuery.of(context).size.width >= 900;
    final paymentDetails = _buildPaymentDetails(
      total,
      primaryColor: primaryColor,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body:
          isWideLayout
              ? Row(
                children: [
                  Expanded(child: _buildModeSelector()),
                  Expanded(flex: 2, child: paymentDetails),
                ],
              )
              : Column(
                children: [
                  SizedBox(height: 96, child: _buildModeSelector()),
                  Expanded(child: paymentDetails),
                ],
              ),
    );
  }

  Widget _buildModeSelector() {
    final selector = Container(
      color: Colors.grey.shade100,
      child: _buildSelectorChildren(),
    );

    return MediaQuery.of(context).size.width >= 900
        ? selector
        : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: selector,
        );
  }

  Widget _buildSelectorChildren() {
    final isWideLayout = MediaQuery.of(context).size.width >= 900;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Flex(
      direction: isWideLayout ? Axis.vertical : Axis.horizontal,
      children: [
        _modeTile(
          'CASH',
          Icons.money,
          isWideLayout: isWideLayout,
          primaryColor: primaryColor,
        ),
        _modeTile(
          'UPI',
          Icons.qr_code_2,
          isWideLayout: isWideLayout,
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildPaymentDetails(double total, {required Color primaryColor}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Total Amount',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
          Text(
            AppFormatters.currencyExact(total),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          if (_paymentMode == 'CASH') ...[
            TextFormField(
              controller: _cashController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cash Received (₹)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              onChanged: _calculateChange,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Change to return:',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    AppFormatters.currencyExact(_cashChange),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            AppButton(
              text: 'CONFIRM CASH PAYMENT',
              onPressed: _confirmCashPayment,
              isLoading: _isProcessing,
            ),
          ] else ...[
            if (_isLoadingUpiAccounts) ...[
              const CircularProgressIndicator(),
            ] else if (_upiAccounts.isEmpty) ...[
              const Text(
                'No active UPI accounts found. Add one in Store Profile before collecting UPI payments.',
                textAlign: TextAlign.center,
              ),
            ] else ...[
              DropdownButtonFormField<int>(
                initialValue: _selectedUpiAccountId,
                decoration: const InputDecoration(
                  labelText: 'UPI Account',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items:
                    _upiAccounts.map<DropdownMenuItem<int>>((account) {
                      return DropdownMenuItem<int>(
                        value: account['id'] as int,
                        child: Text(
                          '${account['label']} (${account['upi_id']})'
                          '${account['is_default'] == true ? ' • Default' : ''}',
                        ),
                      );
                    }).toList(),
                onChanged:
                    _isProcessing
                        ? null
                        : (value) {
                          setState(() => _selectedUpiAccountId = value);
                        },
              ),
              const SizedBox(height: 24),
              if (_upiQrString == null) ...[
                AppButton(
                  text: 'GENERATE UPI QR',
                  onPressed: _initiateUpiPayment,
                  isLoading: _isProcessing,
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _upiQrString!,
                    version: QrVersions.auto,
                    size: 250,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Waiting for customer to scan and pay...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _simulateWebhookSuccess(total),
                  child: const Text('Simulate Webhook Success (Phase 1 Only)'),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _modeTile(
    String mode,
    IconData icon, {
    required bool isWideLayout,
    required Color primaryColor,
  }) {
    final isSelected = _paymentMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _paymentMode = mode;
          _upiQrString = null;
          _isProcessing = false;
        });
        _pollingTimer?.cancel();
      },
      child: Container(
        width: isWideLayout ? double.infinity : 180,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border:
              isWideLayout
                  ? Border(
                    left: BorderSide(
                      color: isSelected ? primaryColor : Colors.transparent,
                      width: 4,
                    ),
                  )
                  : Border(
                    bottom: BorderSide(
                      color: isSelected ? primaryColor : Colors.transparent,
                      width: 4,
                    ),
                  ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? primaryColor : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              mode,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cashController.dispose();
    super.dispose();
  }
}
