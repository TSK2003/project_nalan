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
  late TabController _tabController;
  final List<String> _categories = ['TIFFIN', 'LUNCH', 'DINNER', 'BEVERAGES'];
  List<MenuItem> _menuItems = [];
  final List<BillItem> _currentBill = [];
  bool _isLoadingMenu = true;
  bool _isCreatingBill = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
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
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingMenu = false);
    }
  }

  void _addOrIncrementItem(MenuItem item) {
    setState(() {
      final existing =
          _currentBill.where((b) => b.menuRef.id == item.id).firstOrNull;
      if (existing != null) {
        existing.quantity++;
      } else {
        _currentBill.add(BillItem(menuRef: item));
      }
    });
  }

  void _decrementOrRemoveItem(BillItem bItem) {
    setState(() {
      if (bItem.quantity > 1) {
        bItem.quantity--;
      } else {
        _currentBill.remove(bItem);
      }
    });
  }

  double get _billSubtotal =>
      _currentBill.fold(0, (sum, item) => sum + item.total);

  Future<void> _proceedToPayment() async {
    if (_currentBill.isEmpty) return;

    setState(() => _isCreatingBill = true);
    try {
      final itemsData =
          _currentBill
              .map(
                (b) => {
                  'menu_item_id': b.menuRef.id,
                  'name': b.menuRef.name,
                  'category': b.menuRef.category,
                  'price': b.menuRef.price,
                  'quantity': b.quantity,
                },
              )
              .toList();

      final bill = await PosDataService.instance.createBill(
        items: itemsData,
      );

      final billId = bill['id'];
      if (mounted) {
        setState(() => _currentBill.clear());
        context.push('/payment/$billId');
      }
    } on PosDataException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isCreatingBill = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final primaryColor = Theme.of(context).colorScheme.primary;

    Widget menuSection = Column(
      children: [
        Material(
          color: primaryColor,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: _categories.map((c) => Tab(text: c)).toList(),
          ),
        ),
        Expanded(
          child:
              _isLoadingMenu
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isTablet ? 3 : 2,
                      childAspectRatio: 1.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount:
                        _menuItems
                            .where(
                              (i) =>
                                  i.category ==
                                  _categories[_tabController.index],
                            )
                            .length,
                    itemBuilder: (context, index) {
                      final catItems =
                          _menuItems
                              .where(
                                (i) =>
                                    i.category ==
                                    _categories[_tabController.index],
                              )
                              .toList();
                      final item = catItems[index];
                      return InkWell(
                        onTap: () => _addOrIncrementItem(item),
                        borderRadius: BorderRadius.circular(12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  AppFormatters.currencyExact(item.price),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: primaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );

    Widget billSection = Container(
      color: Colors.white,
      width: isTablet ? 350 : double.infinity,
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
                    : ListView.builder(
                      itemCount: _currentBill.length,
                      itemBuilder: (context, index) {
                        final bItem = _currentBill[index];
                        return ListTile(
                          title: Text(
                            bItem.menuRef.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            AppFormatters.currencyExact(bItem.menuRef.price),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: primaryColor,
                                ),
                                onPressed: () => _decrementOrRemoveItem(bItem),
                              ),
                              Text(
                                '${bItem.quantity}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  color: primaryColor,
                                ),
                                onPressed:
                                    () => _addOrIncrementItem(bItem.menuRef),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  AppFormatters.currencyExact(bItem.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
      body:
          isTablet
              ? Row(children: [Expanded(child: menuSection), billSection])
              : Column(
                children: [
                  Expanded(flex: 3, child: menuSection),
                  Expanded(flex: 2, child: billSection),
                ],
              ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
