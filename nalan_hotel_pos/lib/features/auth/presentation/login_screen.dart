import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/data/pos_data_service.dart';
import '../../../shared/providers/auth_state.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

enum _AuthMode { signIn, register }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _loginMobileController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerMobileController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _didBootstrap = false;
  bool _hasRegisteredUsers = false;
  String? _errorMessage;
  _AuthMode _mode = _AuthMode.signIn;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _loginMobileController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerMobileController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await ref.read(authProvider.notifier).checkAuth();
    if (!mounted) {
      return;
    }
    if (ref.read(authProvider).isAuthenticated) {
      context.go('/billing');
      return;
    }

    final hasRegisteredUsers =
        await PosDataService.instance.hasRegisteredUsers();
    if (!mounted) {
      return;
    }

    setState(() {
      _didBootstrap = true;
      _hasRegisteredUsers = hasRegisteredUsers;
      _mode = hasRegisteredUsers ? _AuthMode.signIn : _AuthMode.register;
      _isLoading = false;
    });
  }

  String? _mobileValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Mobile number is required';
    }
    if (text.length < 10) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Password is required';
    }
    if (text.length < 4) {
      return 'Password must be at least 4 characters';
    }
    return null;
  }

  void _setMode(_AuthMode mode) {
    if (mode == _AuthMode.signIn && !_hasRegisteredUsers) {
      setState(() {
        _errorMessage = 'Create the first user account before signing in';
      });
      return;
    }

    setState(() {
      _mode = mode;
      _errorMessage = null;
    });
  }

  Future<void> _login() async {
    final formState = _loginFormKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mobileNumber = _loginMobileController.text.trim();
      final data = await PosDataService.instance.login(
        username: mobileNumber,
        password: _loginPasswordController.text.trim(),
      );
      await ref
          .read(authProvider.notifier)
          .login(
            data['token'] as String,
            data['refresh_token'] as String,
            data['cashier_name'] as String,
            data['user_id'] as int,
          );

      if (!mounted) {
        return;
      }
      context.go('/billing');
    } on PosDataException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Login failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _register() async {
    final formState = _registerFormKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    var didRegisterUser = false;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final mobileNumber = _registerMobileController.text.trim();
      final password = _registerPasswordController.text.trim();
      await PosDataService.instance.registerUser(
        mobileNumber: mobileNumber,
        password: password,
        fullName: _registerNameController.text.trim(),
      );
      didRegisterUser = true;

      final data = await PosDataService.instance.login(
        username: mobileNumber,
        password: password,
      );
      await ref
          .read(authProvider.notifier)
          .login(
            data['token'] as String,
            data['refresh_token'] as String,
            data['cashier_name'] as String,
            data['user_id'] as int,
          );

      if (!mounted) {
        return;
      }
      context.go('/billing');
    } on PosDataException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Registration failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (didRegisterUser) {
            _hasRegisteredUsers = true;
          }
        });
      }
    }
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: AppColors.error),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('sign-in-form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _loginMobileController,
            label: 'Mobile Number',
            prefixIcon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            validator: _mobileValidator,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _loginPasswordController,
            label: 'Password',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            validator: _passwordValidator,
          ),
          const SizedBox(height: 24),
          AppButton(text: 'Sign In', onPressed: _login, isLoading: _isLoading),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('register-form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _registerNameController,
            label: 'Cashier Name (optional)',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _registerMobileController,
            label: 'New Mobile Number',
            prefixIcon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            validator: _mobileValidator,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _registerPasswordController,
            label: 'New Password',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            validator: _passwordValidator,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            prefixIcon: Icons.verified_user_outlined,
            obscureText: true,
            validator: (value) {
              final error = _passwordValidator(value);
              if (error != null) {
                return error;
              }
              if (value!.trim() != _registerPasswordController.text.trim()) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          AppButton(
            text: 'Create Account',
            onPressed: _register,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isRegisterMode = _mode == _AuthMode.register;

    if (!_didBootstrap) {
      return const SafeArea(
        child: Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + mediaQuery.padding.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth < 520 ? screenWidth : 460,
              ),
              child: Card(
                elevation: 5,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth < 480 ? 24 : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Nalan Hotel POS',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          isRegisterMode
                              ? 'Create a cashier account to unlock the app.'
                              : 'Sign in with your registered mobile number and password.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (!_hasRegisteredUsers) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No user account has been created yet. Register the first cashier to start billing.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_AuthMode>(
                          segments: const [
                            ButtonSegment<_AuthMode>(
                              value: _AuthMode.signIn,
                              label: Text('Sign In'),
                              icon: Icon(Icons.login),
                            ),
                            ButtonSegment<_AuthMode>(
                              value: _AuthMode.register,
                              label: Text('Register'),
                              icon: Icon(Icons.person_add_alt_1),
                            ),
                          ],
                          selected: {_mode},
                          showSelectedIcon: false,
                          onSelectionChanged:
                              (selection) => _setMode(selection.first),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildErrorBanner(),
                      if (_errorMessage != null) const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child:
                            isRegisterMode
                                ? _buildRegisterForm()
                                : _buildLoginForm(),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed:
                              () => _setMode(
                                isRegisterMode
                                    ? _AuthMode.signIn
                                    : _AuthMode.register,
                              ),
                          child: Text(
                            isRegisterMode
                                ? 'Already have an account? Sign in'
                                : 'New cashier? Register a new account',
                          ),
                        ),
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
