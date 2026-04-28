import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

enum SubscriptionTier { free, premium }

class SubscriptionNotifier extends StateNotifier<SubscriptionTier> {
  SubscriptionNotifier() : super(SubscriptionTier.free) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('is_premium') ?? false;
    state = isPremium ? SubscriptionTier.premium : SubscriptionTier.free;

    // TODO: replace SharedPreferences stub with RevenueCat once integrated:
    // try {
    //   final customerInfo = await Purchases.getCustomerInfo();
    //   state = customerInfo.entitlements.active
    //           .containsKey(AppConstants.premiumEntitlement)
    //       ? SubscriptionTier.premium
    //       : SubscriptionTier.free;
    // } catch (_) {
    //   // Fall back to cached value already set above.
    // }
  }

  /// Initiate a purchase flow for the premium subscription.
  Future<void> purchase() async {
    // TODO: uncomment when RevenueCat is integrated:
    // final offerings = await Purchases.getOfferings();
    // final package = offerings.current?.monthly;
    // if (package != null) await Purchases.purchasePackage(package);

    // Optimistic local update for the stub implementation.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
    state = SubscriptionTier.premium;
  }

  /// Restore previously purchased subscriptions (App Store / Play Store).
  Future<void> restore() async {
    // TODO: uncomment when RevenueCat is integrated:
    // await Purchases.restorePurchases();
    await _load();
  }

  /// Returns true if the user can add another baby given [currentCount].
  bool canAddBaby(int currentCount) =>
      state == SubscriptionTier.premium ||
      currentCount < AppConstants.freeBabyLimit;

  /// Returns true if the user can add another caregiver given [currentCount].
  bool canAddCaregiver(int currentCount) =>
      state == SubscriptionTier.premium ||
      currentCount < AppConstants.freeCaregiverLimit;

  bool get isPremium => state == SubscriptionTier.premium;
}
