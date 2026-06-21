import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/memory_store.dart';
import 'data/purchases_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phone-first study app: lock to portrait. The screens (fixed-height
  // illustrations, onboarding steps, bottom sheets) are designed for portrait
  // and overflow in landscape; locking avoids that whole class of layout bugs.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabasePublishableKey, // ignore: deprecated_member_use
  );

  final prefs = await SharedPreferences.getInstance();
  final memory = MemoryStore(prefs);
  await memory.load(); // empty for anonymous users (memory is sign-in only)

  // Configure RevenueCat WITHOUT blocking the first frame — it's a network call,
  // and awaiting it just makes the system splash linger. Fire it async; the app
  // runs free-tier until it lands (the customer-info listener updates state).
  final purchases = PurchasesService();
  final session = Supabase.instance.client.auth.currentSession;
  unawaited(purchases.configure(appUserId: session?.user.id).catchError(
      (Object e) => debugPrint('RevenueCat configure failed: $e')));
  // Keep RevenueCat identity AND the memory store in lock-step with Supabase
  // auth: a signed-in user loads their saved memory; signing out reverts to the
  // anonymous, no-memory state so each anonymous session starts fresh.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final user = data.session?.user;
    if (user != null) {
      purchases.login(user.id);
      memory.load();
    } else {
      purchases.logout();
      memory.clear();
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        memoryStoreProvider.overrideWithValue(memory),
        purchasesServiceProvider.overrideWithValue(purchases),
      ],
      child: const LacticApp(),
    ),
  );
}
