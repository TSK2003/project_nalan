import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/pos_data_service.dart';
import '../../../shared/providers/store_profile.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class StartupGateScreen extends ConsumerStatefulWidget {
  const StartupGateScreen({super.key});

  @override
  ConsumerState<StartupGateScreen> createState() => _StartupGateScreenState();
}

class _StartupGateScreenState extends ConsumerState<StartupGateScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(storeProfileProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(storeProfileProvider);
    if (profile.isLoaded && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.go(profile.isConfigured ? '/billing' : '/setup');
      });
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  final bool setupMode;

  const ProfileScreen({super.key, this.setupMode = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hotelNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _logoPathController = TextEditingController();
  int _selectedColorValue = themeColorOptions.first.toARGB32();
  bool _initialized = false;
  bool _isSaving = false;
  bool _isLoadingUpiAccounts = true;
  List<_UpiAccountData> _upiAccounts = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final profile = ref.read(storeProfileProvider);
    _hotelNameController.text = profile.hotelName;
    _taglineController.text = profile.tagline;
    _addressController.text = profile.address;
    _phoneController.text = profile.phone;
    _logoPathController.text = profile.logoPath;
    _selectedColorValue = profile.primaryColorValue;
    _initialized = true;
    _loadUpiAccounts();
  }

  @override
  void dispose() {
    _hotelNameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _logoPathController.dispose();
    super.dispose();
  }

  Future<void> _pickLogoImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    final pickedPath = result?.files.single.path;
    if (pickedPath == null || pickedPath.isEmpty) {
      return;
    }

    _logoPathController.text = pickedPath;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUpiAccounts() async {
    setState(() => _isLoadingUpiAccounts = true);
    try {
      final response = await PosDataService.instance.listUpiAccounts();
      final accounts =
          (response as List<dynamic>)
              .map(
                (item) =>
                    _UpiAccountData.fromJson(item as Map<String, dynamic>),
              )
              .toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _upiAccounts = accounts;
        _isLoadingUpiAccounts = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingUpiAccounts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load UPI accounts: ${_errorMessage(e, fallback: 'Unknown error')}',
          ),
        ),
      );
    }
  }

  Future<void> _showUpiAccountSheet([_UpiAccountData? account]) async {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController(text: account?.label ?? '');
    final upiIdController = TextEditingController(text: account?.upiId ?? '');
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
                await PosDataService.instance.saveUpiAccount(
                  id: account?.id,
                  label: labelController.text.trim(),
                  upiId: upiIdController.text.trim(),
                );

                if (!sheetContext.mounted) {
                  return;
                }
                Navigator.of(sheetContext).pop(true);
              } catch (e) {
                if (!sheetContext.mounted) {
                  return;
                }
                setSheetState(() => isSubmitting = false);
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      _errorMessage(e, fallback: 'Failed to save UPI account'),
                    ),
                  ),
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
                        account == null
                            ? 'Add UPI Account'
                            : 'Edit UPI Account',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: labelController,
                        label: 'Label',
                        prefixIcon: Icons.account_balance_wallet_outlined,
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Enter a label';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: upiIdController,
                        label: 'UPI ID',
                        prefixIcon: Icons.qr_code_2_outlined,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          final upiRegex = RegExp(r'^[\w.\-]+@[\w]+$');
                          if (!upiRegex.hasMatch(text)) {
                            return 'Enter a valid UPI ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
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
                                  : Text(
                                    account == null ? 'Add UPI' : 'Save UPI',
                                  ),
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

    labelController.dispose();
    upiIdController.dispose();

    if (didSave == true) {
      await _loadUpiAccounts();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            account == null
                ? 'UPI account added successfully'
                : 'UPI account updated',
          ),
        ),
      );
    }
  }

  Future<void> _setDefaultUpi(_UpiAccountData account) async {
    try {
      await PosDataService.instance.setDefaultUpiAccount(account.id);
      await _loadUpiAccounts();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${account.label} is now the default UPI')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(e, fallback: 'Failed to set default UPI')),
        ),
      );
    }
  }

  Future<void> _deleteUpi(_UpiAccountData account) async {
    try {
      await PosDataService.instance.deleteUpiAccount(account.id);
      await _loadUpiAccounts();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${account.label} removed')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _errorMessage(e, fallback: 'Failed to delete UPI account'),
          ),
        ),
      );
    }
  }

  String _errorMessage(Object error, {required String fallback}) {
    if (error is PosDataException && error.message.isNotEmpty) {
      return error.message;
    }
    return fallback;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final currentProfile = ref.read(storeProfileProvider);
    final nextProfile = currentProfile.copyWith(
      hotelName: _hotelNameController.text.trim(),
      tagline: _taglineController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      logoPath: _logoPathController.text.trim(),
      primaryColorValue: _selectedColorValue,
    );

    await ref.read(storeProfileProvider.notifier).saveProfile(nextProfile);
    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);
    if (widget.setupMode) {
      context.go('/billing');
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Store profile updated')));
  }

  Future<void> _resetLocalSetup() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Local App Setup'),
          content: const Text(
            'This clears the saved store profile, menu, bills, and UPI setup on this device and returns the app to first-time setup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    await ref.read(storeProfileProvider.notifier).clearProfile();
    await PosDataService.instance.clearLocalData();
    if (!mounted) {
      return;
    }
    context.go('/setup');
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(_selectedColorValue);

    return Scaffold(
      appBar:
          widget.setupMode ? null : AppBar(title: const Text('Store Profile')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.setupMode
                            ? 'Set Up Your Store'
                            : 'Brand and Store Settings',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.setupMode
                            ? 'Configure the store once, then start billing without a login screen.'
                            : 'Update the store identity so this app can be reused for another hotel or branch.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: [
                          SizedBox(
                            width: 320,
                            child: _ProfilePreviewCard(
                              hotelName:
                                  _hotelNameController.text.trim().isEmpty
                                      ? 'My Store POS'
                                      : _hotelNameController.text.trim(),
                              tagline: _taglineController.text.trim(),
                              address: _addressController.text.trim(),
                              phone: _phoneController.text.trim(),
                              logoPath: _logoPathController.text.trim(),
                              primaryColor: primaryColor,
                            ),
                          ),
                          SizedBox(
                            width: 460,
                            child: Column(
                              children: [
                                AppTextField(
                                  controller: _hotelNameController,
                                  label: 'Hotel / Store Name',
                                  prefixIcon: Icons.storefront_outlined,
                                  validator:
                                      (value) =>
                                          value == null || value.trim().isEmpty
                                              ? 'Store name is required'
                                              : null,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  controller: _taglineController,
                                  label: 'Tagline',
                                  prefixIcon: Icons.badge_outlined,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  controller: _addressController,
                                  label: 'Address',
                                  prefixIcon: Icons.location_on_outlined,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  controller: _phoneController,
                                  label: 'Phone',
                                  prefixIcon: Icons.call_outlined,
                                  keyboardType: TextInputType.phone,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  controller: _logoPathController,
                                  label: 'Logo URL or local file path',
                                  prefixIcon: Icons.image_outlined,
                                  suffixIcon: IconButton(
                                    tooltip: 'Choose image',
                                    onPressed: _pickLogoImage,
                                    icon: const Icon(
                                      Icons.upload_file_outlined,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _pickLogoImage,
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                                    label: const Text('Upload profile image'),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Theme Color',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children:
                                      themeColorOptions.map((color) {
                                        final colorValue = color.toARGB32();
                                        final isSelected =
                                            colorValue == _selectedColorValue;
                                        return InkWell(
                                          onTap:
                                              () => setState(
                                                () =>
                                                    _selectedColorValue =
                                                        colorValue,
                                              ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    isSelected
                                                        ? Colors.black
                                                        : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child:
                                                isSelected
                                                    ? const Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                    )
                                                    : null,
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text:
                            widget.setupMode
                                ? 'SAVE AND START'
                                : 'SAVE PROFILE',
                        onPressed: _saveProfile,
                        isLoading: _isSaving,
                        backgroundColor: primaryColor,
                      ),
                      if (!widget.setupMode) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _resetLocalSetup,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset local app setup'),
                        ),
                      ],
                      const SizedBox(height: 32),
                      _UpiAccountsSection(
                        accounts: _upiAccounts,
                        isLoading: _isLoadingUpiAccounts,
                        onAdd: () => _showUpiAccountSheet(),
                        onEdit: _showUpiAccountSheet,
                        onDelete: _deleteUpi,
                        onMakeDefault: _setDefaultUpi,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpiAccountData {
  final int id;
  final String upiId;
  final String label;
  final bool isDefault;

  const _UpiAccountData({
    required this.id,
    required this.upiId,
    required this.label,
    required this.isDefault,
  });

  factory _UpiAccountData.fromJson(Map<String, dynamic> json) {
    return _UpiAccountData(
      id: json['id'] as int,
      upiId: json['upi_id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      isDefault: json['is_default'] == true,
    );
  }
}

class _UpiAccountsSection extends StatelessWidget {
  final List<_UpiAccountData> accounts;
  final bool isLoading;
  final VoidCallback onAdd;
  final ValueChanged<_UpiAccountData> onEdit;
  final ValueChanged<_UpiAccountData> onDelete;
  final ValueChanged<_UpiAccountData> onMakeDefault;

  const _UpiAccountsSection({
    required this.accounts,
    required this.isLoading,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPI Accounts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage the UPI IDs used on the payment screen.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add UPI'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (accounts.isEmpty)
            const Text('No active UPI accounts found.')
          else
            Column(
              children:
                  accounts.map((account) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                account.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (account.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(account.upiId),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            if (!account.isDefault)
                              IconButton(
                                tooltip: 'Set default',
                                onPressed: () => onMakeDefault(account),
                                icon: const Icon(Icons.star_outline),
                              ),
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => onEdit(account),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => onDelete(account),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }
}

class _ProfilePreviewCard extends StatelessWidget {
  final String hotelName;
  final String tagline;
  final String address;
  final String phone;
  final String logoPath;
  final Color primaryColor;

  const _ProfilePreviewCard({
    required this.hotelName,
    required this.tagline,
    required this.address,
    required this.phone,
    required this.logoPath,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoreAvatar(hotelName: hotelName, logoPath: logoPath),
          const SizedBox(height: 20),
          Text(
            hotelName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              tagline,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
          ],
          if (address.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (address.isNotEmpty)
              Text(address, style: const TextStyle(color: Colors.white)),
            if (phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(phone, style: const TextStyle(color: Colors.white)),
              ),
          ],
        ],
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  final String hotelName;
  final String logoPath;

  const _StoreAvatar({required this.hotelName, required this.logoPath});

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? imageProvider;
    final trimmed = logoPath.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isNotEmpty) {
      if (uri != null && uri.hasScheme) {
        imageProvider = NetworkImage(trimmed);
      } else if (!kIsWeb && File(trimmed).existsSync()) {
        imageProvider = FileImage(File(trimmed));
      }
    }

    final initials =
        hotelName
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part.substring(0, 1))
            .join()
            .toUpperCase();

    return CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white.withValues(alpha: 0.2),
      backgroundImage: imageProvider,
      child:
          imageProvider == null
              ? Text(
                initials.isEmpty ? 'S' : initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              )
              : null,
    );
  }
}
