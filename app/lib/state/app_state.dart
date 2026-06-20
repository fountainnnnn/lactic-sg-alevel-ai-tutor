import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:typed_data';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../data/chat_service.dart';
import '../data/conversation_store.dart';
import '../data/memory_store.dart';
import '../data/purchases_service.dart';
import '../data/upload_service.dart';
import '../features/premium/plans.dart';

/// Overridden in main() once async init is done.
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());
final memoryStoreProvider = Provider<MemoryStore>((_) => throw UnimplementedError());

final chatServiceProvider = Provider<ChatService>((_) => ChatService());
final uploadServiceProvider = Provider<UploadService>((_) => UploadService());

/// A photo the user has attached to the next chat turn. `path` is null while the
/// upload is in flight; once set it's passed to the chat call as `image_path`.
class PendingImage {
  final Uint8List bytes; // for the inline preview
  final String? path; // storage path; null until upload completes
  const PendingImage({required this.bytes, this.path});
  bool get uploading => path == null;
}

final pendingImageProvider = StateProvider<PendingImage?>((_) => null);

/// Subject tags the student picks during onboarding (e.g. "H2 Chemistry"). Held
/// here (not in memory_store) because memory is sign-in-only — anonymous users
/// build no memory, but the demo step still needs to know their picks to show
/// subject-matched sample questions.
final onboardingSubjectsProvider = StateProvider<List<String>>((_) => const []);
final conversationStoreProvider =
    Provider<ConversationStore>((ref) => ConversationStore(ref.watch(prefsProvider)));
final streakStoreProvider = Provider<StreakStore>((ref) => StreakStore(ref.watch(prefsProvider)));

/// Stable per-install id (for anonymous rate limiting on the backend).
final deviceIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(prefsProvider);
  var id = prefs.getString('device_id');
  if (id == null) {
    final r = Random();
    id = 'd_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join()}';
    prefs.setString('device_id', id);
  }
  return id;
});

final onboardingDoneProvider = StateProvider<bool>((ref) {
  return ref.watch(prefsProvider).getBool('onboarding_done') ?? false;
});

/// Wraps the RevenueCat SDK. Overridden in main() with the configured instance.
final purchasesServiceProvider = Provider<PurchasesService>((_) => PurchasesService());

/// Holds the latest RevenueCat CustomerInfo. The SDK pushes updates (purchase,
/// renewal, expiry, dashboard promo grant) into here, so entitlement-derived
/// providers below react live without a manual refresh.
class PurchasesController extends StateNotifier<CustomerInfo?> {
  final PurchasesService _service;
  PurchasesController(this._service) : super(null) {
    try {
      Purchases.addCustomerInfoUpdateListener(_onUpdate);
    } catch (_) {/* SDK not configured (e.g. tests) — providers stay false */}
    _service.customerInfo().then((info) {
      if (info != null && mounted) state = info;
    });
  }

  void _onUpdate(CustomerInfo info) {
    if (mounted) state = info;
  }

  Future<void> refresh() async {
    final info = await _service.customerInfo();
    if (info != null && mounted) state = info;
  }

  @override
  void dispose() {
    try {
      Purchases.removeCustomerInfoUpdateListener(_onUpdate);
    } catch (_) {}
    super.dispose();
  }
}

final customerInfoProvider =
    StateNotifierProvider<PurchasesController, CustomerInfo?>(
        (ref) => PurchasesController(ref.watch(purchasesServiceProvider)));

/// Active paid tier rank from RevenueCat entitlements (0 = free/none, 1 = Lite,
/// 2 = Plus, 3 = Max). Server-verified; entitlements are stacked.
final tierRankProvider = Provider<int>((ref) {
  final info = ref.watch(customerInfoProvider);
  final ents = info?.entitlements.active.keys.toSet() ?? <String>{};
  return Subscriptions.rankOf(ents);
});

/// Any paid tier (Lite or above). Used for "is subscribed" checks (restore) and
/// the advisory flag sent to the backend. NOTE: Lite is paid but stays on the
/// free model — use [hasSmarterModelProvider] for the model-choice gate.
final premiumProvider = Provider<bool>((ref) => ref.watch(tierRankProvider) >= 1);

/// Tiers that get the model toggle — Standard (Gemini) / Reasoning (DeepSeek
/// thinking), Plus+. Free and Lite run DeepSeek only, no toggle.
final hasSmarterModelProvider =
    Provider<bool>((ref) => ref.watch(tierRankProvider) >= Subscriptions.rankSmarterModel);

/// Today's daily-allowance usage as a percentage (0–100), from the backend.
/// We deliberately surface a PERCENTAGE, never a raw message/token count — a
/// number to grind against is distracting while studying. Null when signed out
/// or on error (the UI just hides the indicator). Invalidate after a turn to
/// refresh: `ref.invalidate(usageProvider)`.
final usageProvider = FutureProvider<int?>((ref) async {
  ref.watch(customerInfoProvider); // re-fetch when the tier (and so the cap) changes
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  if (token == null) return null;
  try {
    final resp = await http.post(
      Uri.parse(Config.usageEndpoint),
      headers: {
        'Authorization': 'Bearer $token',
        'apikey': Config.supabasePublishableKey,
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final pct = (jsonDecode(resp.body) as Map<String, dynamic>)['pct'];
    return pct is num ? pct.round().clamp(0, 100) : null;
  } catch (_) {
    return null;
  }
});

/// Per-feature gates by minimum tier rank.
final canPhotoProvider =
    Provider<bool>((ref) => ref.watch(tierRankProvider) >= Subscriptions.rankPhoto);
final canMarksCoachProvider =
    Provider<bool>((ref) => ref.watch(tierRankProvider) >= Subscriptions.rankMarksCoach);
final canDrillingProvider =
    Provider<bool>((ref) => ref.watch(tierRankProvider) >= Subscriptions.rankDrilling);

class Settings {
  final ThemeMode themeMode;
  final String answerStyle; // 'coach' | 'direct'
  final String modelPref; // 'standard' (Gemini) | 'reasoning' (DeepSeek thinking). Plus+ only.
  const Settings({
    this.themeMode = ThemeMode.system,
    this.answerStyle = 'direct',
    this.modelPref = 'standard',
  });

  Settings copyWith({ThemeMode? themeMode, String? answerStyle, String? modelPref}) => Settings(
        themeMode: themeMode ?? this.themeMode,
        answerStyle: answerStyle ?? this.answerStyle,
        modelPref: modelPref ?? this.modelPref,
      );
}

class SettingsNotifier extends StateNotifier<Settings> {
  final SharedPreferences _prefs;
  SettingsNotifier(this._prefs)
      : super(Settings(
          themeMode: _modeFrom(_prefs.getString('theme_mode')),
          answerStyle: _prefs.getString('answer_style') ?? 'direct',
          modelPref: _prefs.getString('model_pref') ?? 'standard',
        ));

  static ThemeMode _modeFrom(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light, // default to light when unset
      };

  void setThemeMode(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    _prefs.setString('theme_mode', m.name);
  }

  void setAnswerStyle(String s) {
    state = state.copyWith(answerStyle: s);
    _prefs.setString('answer_style', s);
  }

  void setModelPref(String s) {
    state = state.copyWith(modelPref: s);
    _prefs.setString('model_pref', s);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>((ref) {
  return SettingsNotifier(ref.watch(prefsProvider));
});
