import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/data/pos_data_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/providers/store_profile.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  final int billId;
  const ReceiptScreen({super.key, required this.billId});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  Map<String, dynamic>? _bill;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBill();
  }

  Future<void> _fetchBill() async {
    try {
      final response = await PosDataService.instance.getBill(widget.billId);
      if (!mounted) {
        return;
      }
      setState(() {
        _bill = response;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) context.pop();
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final profile = ref.read(storeProfileProvider);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  profile.hotelName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (profile.tagline.isNotEmpty)
                pw.Center(child: pw.Text(profile.tagline)),
              if (profile.address.isNotEmpty)
                pw.Center(child: pw.Text(profile.address)),
              if (profile.phone.isNotEmpty)
                pw.Center(child: pw.Text('Phone: ${profile.phone}')),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Text('Bill No: ${_bill!['bill_number']}'),
              pw.Text(
                'Date: ${AppFormatters.dateTime(DateTime.parse(_bill!['created_at']))}',
              ),
              pw.Text('Cashier: ${_bill!['cashier_name'] ?? 'System'}'),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Item')),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text('Qty', textAlign: pw.TextAlign.center),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text('Amt', textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.Divider(),
              ...(_bill!['items'] as List).map(
                (item) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        item['item_name']?.toString() ?? item['name'].toString(),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        item['quantity'].toString(),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        (item['line_total'] ?? item['total']).toString(),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:'),
                  pw.Text((_bill!['subtotal'] ?? _bill!['subtotal_amount']).toString()),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Discount:'),
                  pw.Text('-${_bill!['discount_amount']}'),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    _bill!['total_amount'].toString(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Divider(),
              pw.Text('PAYMENT DETAILS'),
              pw.Text('Mode: ${_bill!['payment_mode']}'),
              if (_bill!['upi_id_used'] != null)
                pw.Text('Paid to: ${_bill!['upi_id_used']}'),
              pw.Text('Status: ${_bill!['status']}'),
              pw.Divider(),
              pw.Center(child: pw.Text('Thank you! Visit Again!')),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/billing'),
        ),
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format),
        initialPageFormat: PdfPageFormat.roll80,
        pdfFileName: '${_bill!['bill_number']}.pdf',
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
