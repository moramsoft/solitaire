/// Monetization service boundary enabling v1.0 Free Beta and v1.1 drop-in
/// AdMob/MAX + RevenueCat without modifying game logic or UI.
abstract class MonetizationService {
  bool get isAdFree;

  Future<void> onGameCompleted();
  Future<bool> showRewarded(String placement);
  Future<bool> purchaseAdFree();
  Future<bool> restorePurchases();
  Future<void> reportBadAd(String reason);
}

/// v1.0 Free Beta implementation: zero ads, zero paywalls.
class BetaFreeMonetizationService implements MonetizationService {
  const BetaFreeMonetizationService();

  @override
  bool get isAdFree => true;

  @override
  Future<void> onGameCompleted() async {}

  @override
  Future<bool> showRewarded(String placement) async => true;

  @override
  Future<bool> purchaseAdFree() async => true;

  @override
  Future<bool> restorePurchases() async => true;

  @override
  Future<void> reportBadAd(String reason) async {}
}
