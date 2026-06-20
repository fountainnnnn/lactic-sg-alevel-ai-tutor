import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../core/config.dart';

/// Thin wrapper over the RevenueCat SDK. Everything purchase-related goes through
/// here so the rest of the app never imports the SDK directly. Configuration
/// happens once at startup (see main.dart); all other calls no-op until then.
class PurchasesService {
  bool _configured = false;
  bool get isConfigured => _configured;

  /// Call once at startup, before any paywall/entitlement read. [appUserId] links
  /// the RevenueCat customer to the Supabase user so the server-side webhook can
  /// attribute the purchase. Pass null for an anonymous (signed-out) user —
  /// RevenueCat assigns a stable anonymous id, which we alias on login().
  Future<void> configure({String? appUserId}) async {
    if (_configured) return;
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    final isApple = Platform.isIOS || Platform.isMacOS;
    final config = PurchasesConfiguration(Config.revenueCatKey(isApple: isApple))
      ..appUserID = appUserId;
    await Purchases.configure(config);
    _configured = true;
  }

  /// Point RevenueCat at the signed-in Supabase user. Merges any anonymous
  /// purchases made before sign-in into this identity.
  Future<CustomerInfo?> login(String userId) async {
    if (!_configured) return null;
    try {
      final result = await Purchases.logIn(userId);
      return result.customerInfo;
    } on PlatformException {
      return null; // network/identity hiccup — entitlements stay as they were
    }
  }

  /// Return to an anonymous RevenueCat identity on sign-out.
  Future<void> logout() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } on PlatformException catch (e) {
      // Already anonymous → nothing to do; any other error is non-fatal here.
      if (PurchasesErrorHelper.getErrorCode(e) !=
          PurchasesErrorCode.logOutWithAnonymousUserError) {
        // swallow: sign-out should never be blocked by a billing error
      }
    }
  }

  Future<CustomerInfo?> customerInfo() async {
    if (!_configured) return null;
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException {
      return null;
    }
  }

  /// True if [entitlement] is currently active for the customer.
  bool isEntitled(CustomerInfo? info, String entitlement) =>
      info?.entitlements.active.containsKey(entitlement) ?? false;

  /// Present the RevenueCat-hosted paywall for the current offering. Returns true
  /// if the user came away entitled (purchased or restored). The paywall itself
  /// is designed/edited in the RevenueCat dashboard — no app release needed.
  Future<bool> presentPaywall() async {
    if (!_configured) return false;
    try {
      final result = await RevenueCatUI.presentPaywall();
      return _entitledResult(result);
    } on PlatformException {
      return false;
    }
  }

  /// Purchase a specific store product (by its product id, e.g.
  /// `lactic_plus_monthly`) directly from the current offering — no RC-hosted
  /// paywall. Our own [PremiumScreen] is the paywall; this buys the selected
  /// tier+billing. Returns ([ok], [cancelled]): [ok] true if the purchase
  /// completed (entitlements update via the customer-info listener); [cancelled]
  /// true if the user backed out (so the UI can stay silent rather than error).
  Future<({bool ok, bool cancelled})> purchaseProduct(String productId) async {
    if (!_configured) return (ok: false, cancelled: false);
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering == null) return (ok: false, cancelled: false);
      Package? pkg;
      for (final p in offering.availablePackages) {
        if (p.storeProduct.identifier == productId) {
          pkg = p;
          break;
        }
      }
      if (pkg == null) return (ok: false, cancelled: false);
      await Purchases.purchase(PurchaseParams.package(pkg));
      return (ok: true, cancelled: false);
    } on PlatformException catch (e) {
      final cancelled = PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      return (ok: false, cancelled: cancelled);
    }
  }

  /// Show the paywall ONLY if the user lacks [entitlement] — ideal for gating a
  /// premium action inline (returns true if they already had it or just bought).
  Future<bool> presentPaywallIfNeeded(String entitlement) async {
    if (!_configured) return false;
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(entitlement);
      return result == PaywallResult.notPresented || _entitledResult(result);
    } on PlatformException {
      return false;
    }
  }

  /// RevenueCat Customer Center — native manage / cancel / restore / refund flow.
  Future<void> presentCustomerCenter() async {
    if (!_configured) return;
    try {
      await RevenueCatUI.presentCustomerCenter();
    } on PlatformException {
      // user dismissed or a transient error — nothing actionable here
    }
  }

  /// Restore prior purchases (App Store / Play account). Returns the refreshed
  /// CustomerInfo, or null on failure.
  Future<CustomerInfo?> restore() async {
    if (!_configured) return null;
    try {
      return await Purchases.restorePurchases();
    } on PlatformException {
      return null;
    }
  }

  bool _entitledResult(PaywallResult r) =>
      r == PaywallResult.purchased || r == PaywallResult.restored;
}
