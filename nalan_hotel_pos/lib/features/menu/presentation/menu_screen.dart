import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/data/pos_data_service.dart';
import '../../../core/utils/formatters.dart';

class MenuItem {
  final int id;
  final String name;
  final String category;
  final double price;
  bool isAvailable;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.isAvailable,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      price: double.parse(json['price'].toString()),
      isAvailable: json['is_available'],
    );
  }
}

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = ['TIFFIN', 'LUNCH', 'DINNER', 'BEVERAGES'];
  List<MenuItem> _items = [];
  bool _isLoading = true;

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
      final data = await PosDataService.instance.getMenu();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = data.map((json) => MenuItem.fromJson(json)).toList();
        _isLoading = false;
      });
    } on PosDataException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load menu: ${e.message}')),
      );
    }
  }

  Future<void> _toggleAvailability(MenuItem item) async {
    final originalState = item.isAvailable;
    setState(() => item.isAvailable = !originalState);

    try {
      await PosDataService.instance.toggleMenuAvailability(item.id);
    } catch (e) {
      if (mounted) {
        setState(() => item.isAvailable = originalState);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update availability')),
        );
      }
    }
  }

  Future<void> _deleteMenuItem(MenuItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Menu Item'),
          content: Text('Delete "${item.name}" from ${item.category}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await PosDataService.instance.deleteMenuItem(item.id);
      await _fetchMenu();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${item.name}" deleted successfully')),
      );
    } on PosDataException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showItemBottomSheet([MenuItem? item]) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item?.name ?? '');
    final priceController = TextEditingController(
      text: item != null ? item.price.toStringAsFixed(2) : '',
    );
    var selectedCategory = item?.category ?? _categories[_tabController.index];
    var isAvailable = item?.isAvailable ?? true;
    var isSubmitting = false;

    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              final formState = formKey.currentState;
              if (formState == null || !formState.validate() || isSubmitting) {
                return;
              }

              setSheetState(() => isSubmitting = true);

              try {
                await PosDataService.instance.saveMenuItem(
                  id: item?.id,
                  name: nameController.text.trim(),
                  category: selectedCategory,
                  price: double.parse(priceController.text.trim()),
                  isAvailable: isAvailable,
                );

                if (!sheetContext.mounted) {
                  return;
                }
                Navigator.of(sheetContext).pop(true);
              } on PosDataException catch (e) {
                if (!context.mounted) {
                  return;
                }
                setSheetState(() => isSubmitting = false);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.message)));
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                setSheetState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to save menu item')),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item == null ? 'Add Menu Item' : 'Edit Menu Item',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Item Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter item name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _categories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setSheetState(() => selectedCategory = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: 'Rs. ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final price = double.tryParse(value?.trim() ?? '');
                          if (price == null || price <= 0) {
                            return 'Enter a valid price';
                          }
                          return null;
                        },
                      ),
                      if (item != null) ...[
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: isAvailable,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                          title: const Text('Available'),
                          onChanged:
                              (value) =>
                                  setSheetState(() => isAvailable = value),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isSubmitting ? null : submit,
                          child:
                              isSubmitting
                                  ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text(item == null ? 'Add Item' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    priceController.dispose();

    if (didSave == true) {
      await _fetchMenu();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item == null ? 'Menu item added successfully' : 'Menu item updated',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showItemBottomSheet(),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetchMenu,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      _items
                          .where(
                            (i) =>
                                i.category == _categories[_tabController.index],
                          )
                          .length,
                  itemBuilder: (context, index) {
                    final categoryItems =
                        _items
                            .where(
                              (i) =>
                                  i.category ==
                                  _categories[_tabController.index],
                            )
                            .toList();
                    final item = categoryItems[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _showItemBottomSheet(item),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                item.isAvailable
                                    ? AppColors.textDark
                                    : AppColors.textLight,
                            decoration:
                                item.isAvailable
                                    ? null
                                    : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          AppFormatters.currencyExact(item.price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        trailing: SizedBox(
                          width: 126,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: item.isAvailable,
                                activeThumbColor: primaryColor,
                                onChanged: (_) => _toggleAvailability(item),
                              ),
                              IconButton(
                                tooltip: 'Delete item',
                                onPressed: () => _deleteMenuItem(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
