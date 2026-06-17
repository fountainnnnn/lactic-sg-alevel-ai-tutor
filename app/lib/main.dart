import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/memory_store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabasePublishableKey, // ignore: deprecated_member_use
  );

  final prefs = await SharedPreferences.getInstance();
  final memory = MemoryStore(prefs);
  await memory.load();

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        memoryStoreProvider.overrideWithValue(memory),
      ],
      child: const JcaiApp(),
    ),
  );
}
