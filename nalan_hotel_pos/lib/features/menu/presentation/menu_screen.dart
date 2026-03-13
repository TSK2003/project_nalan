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

  List<MenuItem> _categoryItems() {
    final selectedCategory = _categories[_tabController.index];
    return _items.where((item) => item.category == selectedCategory).toList();
  }

  int _gridCount(double width) {
    if (width >= 1100) {
      return 4;
    }
    if (width >= 760) {
      return 3;
    }
    if (width >= 320) {
      return 2;
    }
    return 1;
  }

  double _gridAspectRatio(double width, int crossAxisCount) {
    if (crossAxisCount == 1) {
      return width < 360 ? 1.35 : 1.5;
    }
    if (crossAxisCount == 2) {
      return width < 420 ? 1.12 : 1.2;
    }
    return width >= 1000 ? 1.08 : 1.0;
  }

  Future<void> _toggleAvailability(MenuItem item) async {
    final originalState = item.isAvailable;
    setState(() => item.isAvailable = !originalState);

    try {
      await PosDataService.instance.toggleMenuAvailability(item.id);
    } catch (_) {
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
        return SafeArea(
          child: AlertDialog(
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
          ),
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
      useSafeArea: true,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);

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

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  mediaQuery.viewInsets.bottom + mediaQuery.padding.bottom + 16,
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
                                      width: 18,
                                      height: 18,
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

  Widget _buildMenuItemCard(MenuItem item, Color primaryColor) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showItemBottomSheet(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
                  ),
                  IconButton(
                    tooltip: 'Delete item',
                    onPressed: () => _deleteMenuItem(item),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                AppFormatters.currencyExact(item.price),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            item.isAvailable
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: item.isAvailable,
                    activeThumbColor: primaryColor,
                    onChanged: (_) => _toggleAvailability(item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final categoryItems = _categoryItems();
    final outerPadding = screenWidth < 600 ? 12.0 : 16.0;

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Menu Management'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: false,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            labelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            labelPadding: EdgeInsets.zero,
            tabs:
                _categories
                    .map(
                      (category) => Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            category,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                    .toList(),
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
                : LayoutBuilder(
                  builder: (context, constraints) {
                    if (categoryItems.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _fetchMenu,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(outerPadding),
                          children: const [
                            SizedBox(height: 160),
                            Center(
                              child: Text('No items in this category yet.'),
                            ),
                          ],
                        ),
                      );
                    }

                    final contentWidth = constraints.maxWidth;
                    final crossAxisCount = _gridCount(contentWidth);

                    return RefreshIndicator(
                      onRefresh: _fetchMenu,
                      child: GridView.builder(
                        padding: EdgeInsets.all(outerPadding),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: _gridAspectRatio(
                            contentWidth,
                            crossAxisCount,
                          ),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: categoryItems.length,
                        itemBuilder: (context, index) {
                          return _buildMenuItemCard(
                            categoryItems[index],
                            primaryColor,
                          );
                        },
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
