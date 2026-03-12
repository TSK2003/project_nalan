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
  final String? initialPaymentMode;

  const PaymentScreen({
    super.key,
    required this.billId,
    this.initialPaymentMode,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  Map<String, dynamic>? _bill;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isLoadingUpiAccounts = true;
  String _paymentMode = 'CASH';
  String? _upiQrString;
  Timer? _pollingTimer;
  List<dynamic> _upiAccounts = [];
  int? _selectedUpiAccountId;
  final _splitCashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBill();
    _fetchUpiAccounts();
  }

  String _normalizedInitialMode() {
    final raw = widget.initialPaymentMode?.trim().toUpperCase();
    if (raw == 'CASH' || raw == 'UPI' || raw == 'SPLIT') {
      return raw!;
    }
    return 'CASH';
  }

  double _billTotal() {
    return double.parse(_bill!['total_amount'].toString());
  }

  double _parseAmount(Object? value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _splitCashInput() {
    return double.tryParse(_splitCashController.text.trim()) ?? 0;
  }

  double _remainingUpiAmount(double total) {
    final persistedUpiAmount = _parseAmount(_bill?['upi_amount']);
    if (_paymentMode == 'SPLIT' &&
        _upiQrString != null &&
        persistedUpiAmount > 0) {
      return persistedUpiAmount;
    }

    final remaining = total - _splitCashInput();
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _fetchBill() async {
    try {
      final bill = await PosDataService.instance.getBill(widget.billId);
      if (!mounted) {
        return;
      }

      final restoredMode = (bill['payment_mode'] as String?)?.toUpperCase();
      final requestedMode = _normalizedInitialMode();
      final hasExplicitRequestedMode =
          widget.initialPaymentMode != null &&
          widget.initialPaymentMode!.trim().isNotEmpty;
      final hasPendingDigitalFlow =
          bill['status'] == 'PENDING_PAYMENT' &&
          (restoredMode == 'UPI' || restoredMode == 'SPLIT');
      final shouldRestorePendingFlow =
          hasPendingDigitalFlow &&
          (!hasExplicitRequestedMode || requestedMode == restoredMode);

      setState(() {
        _bill = bill;
        _isLoading = false;
        _paymentMode = shouldRestorePendingFlow ? restoredMode! : requestedMode;

        final cashReceived = _parseAmount(bill['cash_received']);
        if (_paymentMode == 'SPLIT' && cashReceived > 0) {
          _splitCashController.text = cashReceived.toStringAsFixed(2);
        }
      });

      if (shouldRestorePendingFlow) {
        await _restorePendingUpiPayment();
      }
    } catch (_) {
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
        _bill = {...?_bill, ...response};

        final cashReceived = _parseAmount(response['cash_received']);
        if (_paymentMode == 'SPLIT' && cashReceived > 0) {
          _splitCashController.text = cashReceived.toStringAsFixed(2);
        }
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
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingUpiAccounts = false);
      }
    }
  }

  Future<void> _confirmCashPayment() async {
    final total = _billTotal();

    setState(() => _isProcessing = true);
    try {
      await PosDataService.instance.confirmCashPayment(
        widget.billId,
        cashReceived: total,
      );

      if (mounted) {
        context.go('/receipt/${widget.billId}');
      }
    } catch (_) {
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

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentMode = 'UPI';
        _upiQrString = response['upi_qr_string'] as String?;
        _bill = {...?_bill, ...response, 'payment_mode': 'UPI'};
        _isProcessing = false;
      });
      _startPolling();
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate UPI QR')),
        );
      }
    }
  }

  Future<void> _initiateSplitPayment() async {
    final total = _billTotal();
    final cashAmount = _splitCashInput();

    if (_selectedUpiAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active UPI account available')),
      );
      return;
    }
    if (cashAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the cash amount first')),
      );
      return;
    }
    if (cashAmount >= total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cash amount must be less than the total bill'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final response = await PosDataService.instance.initiateSplitPayment(
        widget.billId,
        cashAmount: cashAmount,
        upiAccountId: _selectedUpiAccountId!,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentMode = 'SPLIT';
        _upiQrString = response['upi_qr_string'] as String?;
        _bill = {
          ...?_bill,
          ...response,
          'cash_received': cashAmount,
          'payment_mode': 'SPLIT',
        };
        _splitCashController.text = cashAmount.toStringAsFixed(2);
        _isProcessing = false;
      });
      _startPolling();
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start split payment')),
        );
      }
    }
  }

  Future<void> _simulateWebhookSuccess() async {
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
          return;
        }

        if (mounted) {
          setState(() {
            _upiQrString = response['upi_qr_string'] as String?;
            _bill = {...?_bill, ...response};
          });
        }
      } catch (_) {
        // Ignore transient polling failures while the user stays on the screen.
      }
    });
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _buildUpiAccountField() {
    if (_isLoadingUpiAccounts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_upiAccounts.isEmpty) {
      return const Text(
        'No active UPI accounts found. Add one in Store Profile before collecting UPI payments.',
        textAlign: TextAlign.center,
      );
    }

    return DropdownButtonFormField<int>(
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
    );
  }

  Widget _buildQrPanel({
    required double amount,
    required Color primaryColor,
    required String heading,
    String? note,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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
            size: 210,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          heading,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'UPI Amount: ${AppFormatters.currencyExact(amount)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: primaryColor,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            note,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: _simulateWebhookSuccess,
          child: const Text('Simulate Webhook Success (Phase 1 Only)'),
        ),
      ],
    );
  }

  Widget _buildCashDetails(double total, {required Color primaryColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionCard(
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_outlined),
                  SizedBox(width: 8),
                  Text(
                    'Cash Payment',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                AppFormatters.currencyExact(total),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cash amount is fixed to the bill total.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          text: 'CONFIRM CASH PAYMENT',
          onPressed: _confirmCashPayment,
          isLoading: _isProcessing,
        ),
      ],
    );
  }

  Widget _buildUpiDetails(double total, {required Color primaryColor}) {
    if (_upiQrString != null) {
      return _buildQrPanel(
        amount: total,
        primaryColor: primaryColor,
        heading: 'Waiting for customer to scan and pay...',
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildUpiAccountField(),
        const SizedBox(height: 18),
        AppButton(
          text: 'GENERATE UPI QR',
          onPressed: _upiAccounts.isEmpty ? () {} : _initiateUpiPayment,
          isLoading: _isProcessing,
        ),
      ],
    );
  }

  Widget _buildSplitDetails(double total, {required Color primaryColor}) {
    final upiAmount = _remainingUpiAmount(total);
    final cashAmount =
        _upiQrString != null
            ? _parseAmount(_bill?['cash_received'])
            : _splitCashInput();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _splitCashController,
          readOnly: _upiQrString != null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cash Amount (₹)',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cash Portion',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    AppFormatters.currencyExact(cashAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'UPI Portion',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    AppFormatters.currencyExact(upiAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_upiQrString == null) ...[
          _buildUpiAccountField(),
          const SizedBox(height: 18),
          AppButton(
            text: 'CONTINUE TO UPI QR',
            onPressed: _upiAccounts.isEmpty ? () {} : _initiateSplitPayment,
            isLoading: _isProcessing,
          ),
        ] else ...[
          const SizedBox(height: 12),
          _buildQrPanel(
            amount: upiAmount,
            primaryColor: primaryColor,
            heading:
                'Collect cash first, then ask the customer to pay the remaining UPI amount.',
            note: 'Cash collected: ${AppFormatters.currencyExact(cashAmount)}',
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentDetails(double total, {required Color primaryColor}) {
    late final Widget content;
    if (_paymentMode == 'CASH') {
      content = _buildCashDetails(total, primaryColor: primaryColor);
    } else if (_paymentMode == 'UPI') {
      content = _buildUpiDetails(total, primaryColor: primaryColor);
    } else {
      content = _buildSplitDetails(total, primaryColor: primaryColor);
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppFormatters.currencyExact(total),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  content,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = _billTotal();
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _buildPaymentDetails(total, primaryColor: primaryColor),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _splitCashController.dispose();
    super.dispose();
  }
}
