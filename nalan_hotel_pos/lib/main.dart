import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/providers/auth_state.dart';
import 'shared/providers/store_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(storeProfileProvider.notifier).loadProfile();
  await container.read(authProvider.notifier).checkAuth();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NalanHotelApp(),
    ),
  );
}
