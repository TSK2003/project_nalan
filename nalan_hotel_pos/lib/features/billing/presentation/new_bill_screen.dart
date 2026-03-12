import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/data/pos_data_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../menu/presentation/menu_screen.dart' show MenuItem;

class BillItem {
  final MenuItem menuRef;
  int quantity;

  BillItem({required this.menuRef, this.quantity = 1});

  double get total => menuRef.price * quantity;
}

class NewBillScreen extends ConsumerStatefulWidget {
  const NewBillScreen({super.key});

  @override
  ConsumerState<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends ConsumerState<NewBillScreen>
    with SingleTickerProviderStateMixin {
  static const _customCategory = 'OTHERS';
  static const _customItemName = 'Custom Item';

  late TabController _tabController;
  final _customAmountController = TextEditingController();
  final List<String> _categories = [
    'TIFFIN',
    'LUNCH',
    'DINNER',
    'BEVERAGES',
    _customCategory,
  ];
  List<MenuItem> _menuItems = [];
  final List<BillItem> _currentBill = [];
  bool _isLoadingMenu = true;
  bool _isCreatingBill = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    try {
      final data = await PosDataService.instance.getMenu(availableOnly: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _menuItems = data.map((json) => MenuItem.fromJson(json)).toList();
        _isLoadingMenu = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingMenu = false);
    }
  }

  List<MenuItem> _itemsForSelectedCategory() {
    final selectedCategory = _categories[_tabController.index];
    return _menuItems
        .where((item) => item.category == selectedCategory)
        .toList();
  }

  void _addOrIncrementItem(MenuItem item) {
    setState(() {
      final existing =
          _currentBill
              .where((billItem) => billItem.menuRef.id == item.id)
              .firstOrNull;
      if (existing != null) {
        existing.quantity++;
      } else {
        _currentBill.add(BillItem(menuRef: item));
      }
    });
  }

  void _addCustomAmount() {
    final parsedAmount = double.tryParse(_customAmountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    _addOrIncrementItem(
      MenuItem(
        id: -DateTime.now().microsecondsSinceEpoch,
        name: _customItemName,
        category: _customCategory,
        price: parsedAmount,
        isAvailable: true,
      ),
    );
    _customAmountController.clear();
  }

  Future<String?> _askPaymentMode() {
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.money),
                title: const Text('Cash'),
                subtitle: const Text('Open direct cash payment'),
                onTap: () => Navigator.of(sheetContext).pop('CASH'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('UPI'),
                subtitle: const Text('Open full UPI payment'),
                onTap: () => Navigator.of(sheetContext).pop('UPI'),
              ),
              ListTile(
                leading: const Icon(Icons.call_split),
                title: const Text('UPI + Cash'),
                subtitle: const Text(
                  'Enter cash first, then collect balance by UPI',
                ),
                onTap: () => Navigator.of(sheetContext).pop('SPLIT'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _decrementOrRemoveItem(BillItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        _currentBill.remove(item);
      }
    });
  }

  double get _billSubtotal =>
      _currentBill.fold(0, (sum, item) => sum + item.total);

  Future<void> _proceedToPayment() async {
    if (_currentBill.isEmpty) {
      return;
    }

    final paymentMode = await _askPaymentMode();
    if (!mounted) {
      return;
    }
    if (paymentMode == null) {
      return;
    }

    if (PosDataService.instance.isCloudMode &&
        _currentBill.any((item) => item.menuRef.id <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Custom Others items are available only in offline mode.',
          ),
        ),
      );
      return;
    }

    setState(() => _isCreatingBill = true);
    try {
      final itemsData =
          _currentBill
              .map(
                (item) => {
                  'menu_item_id': item.menuRef.id,
                  'name': item.menuRef.name,
                  'category': item.menuRef.category,
                  'price': item.menuRef.price,
                  'quantity': item.quantity,
                },
              )
              .toList();

      final bill = await PosDataService.instance.createBill(items: itemsData);
      final billId = bill['id'];

      if (!mounted) {
        return;
      }

      setState(() => _currentBill.clear());
      context.push('/payment/$billId?mode=$paymentMode');
    } on PosDataException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isCreatingBill = false);
      }
    }
  }

  Widget _buildMenuCard({
    required VoidCallback onTap,
    required String title,
    required String subtitle,
    required Color primaryColor,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        elevation: 1.5,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: primaryColor),
                )
              else
                const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountPanel(Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        elevation: 1.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_note, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Custom Amount',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Add an item under Others directly by amount.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                onSubmitted: (_) => _addCustomAmount(),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'ADD TO BILL',
                onPressed: _addCustomAmount,
                backgroundColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillLineItem(BillItem item, Color primaryColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 260;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child:
              compact
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.menuRef.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormatters.currencyExact(item.menuRef.price),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: primaryColor,
                            ),
                            onPressed: () => _decrementOrRemoveItem(item),
                          ),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${item.quantity}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: primaryColor,
                            ),
                            onPressed: () => _addOrIncrementItem(item.menuRef),
                          ),
                          const Spacer(),
                          Text(
                            AppFormatters.currencyExact(item.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.menuRef.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppFormatters.currencyExact(item.menuRef.price),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: primaryColor,
                        ),
                        onPressed: () => _decrementOrRemoveItem(item),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: primaryColor,
                        ),
                        onPressed: () => _addOrIncrementItem(item.menuRef),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 76,
                        child: Text(
                          AppFormatters.currencyExact(item.total),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final useSplitLayout = width >= 900;
    final isNarrowScreen = width < 320;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final selectedCategory = _categories[_tabController.index];
    final categoryItems = _itemsForSelectedCategory();

    final menuSection = Column(
      children: [
        Material(
          color: primaryColor,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            tabs: _categories.map((category) => Tab(text: category)).toList(),
          ),
        ),
        Expanded(
          child:
              _isLoadingMenu
                  ? const Center(child: CircularProgressIndicator())
                  : selectedCategory == _customCategory
                  ? _buildCustomAmountPanel(primaryColor)
                  : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          useSplitLayout ? 3 : (isNarrowScreen ? 1 : 2),
                      childAspectRatio: isNarrowScreen ? 1.2 : 1.45,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: categoryItems.length,
                    itemBuilder: (context, index) {
                      final item = categoryItems[index];
                      return _buildMenuCard(
                        onTap: () => _addOrIncrementItem(item),
                        title: item.name,
                        subtitle: AppFormatters.currencyExact(item.price),
                        primaryColor: primaryColor,
                      );
                    },
                  ),
        ),
      ],
    );

    final billSection = Container(
      color: Colors.white,
      width: useSplitLayout ? 350 : double.infinity,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Icon(Icons.receipt_long),
                SizedBox(width: 8),
                Text(
                  'Current Bill',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _currentBill.isEmpty
                    ? const Center(
                      child: Text(
                        'No items added',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _currentBill.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder:
                          (context, index) => _buildBillLineItem(
                            _currentBill[index],
                            primaryColor,
                          ),
                    ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppFormatters.currencyExact(_billSubtotal),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'PROCEED TO PAYMENT',
                  onPressed: _currentBill.isEmpty ? () {} : _proceedToPayment,
                  isLoading: _isCreatingBill,
                  backgroundColor:
                      _currentBill.isEmpty ? Colors.grey : primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Bill'),
        actions: [
          if (_currentBill.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                setState(() => _currentBill.clear());
              },
              tooltip: 'Clear Bill',
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: useSplitLayout ? 1000 : 560),
          child:
              useSplitLayout
                  ? Row(children: [Expanded(child: menuSection), billSection])
                  : Column(
                    children: [
                      Expanded(flex: 5, child: menuSection),
                      Expanded(flex: 6, child: billSection),
                    ],
                  ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
