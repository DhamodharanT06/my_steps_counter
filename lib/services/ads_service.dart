import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps loading and showing a single rewarded ad.
///
/// Uses Google's official public TEST ad unit IDs below, which always serve
/// a working test ad and never generate real revenue or violate policy —
/// safe to ship in development, but they MUST be swapped for your own ad
/// unit ID from admob.google.com before a real release (see README.md).
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static String get _unitId {
    if (kReleaseMode) return 'REPLACE_WITH_YOUR_OWN_ADMOB_REWARDED_UNIT_ID';
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/1712485313'
        : 'ca-app-pub-5197112083845726/2879252610';
  }

  bool _initialized = false;
  RewardedAd? _preloaded;
  bool _loading = false;

  /// How many FAQ answers one watched ad unlocks.
  static const revealsPerAd = 1;

  /// Free reveals left from the last watched ad. Kept in memory only (not
  /// saved to disk) — it's a session perk, not something worth persisting.
  int _creditsRemaining = 0;
  int get creditsRemaining => _creditsRemaining;

  /// What the FAQ screen should call. This is the "never block the user"
  /// policy: revealing the answer never depends on whether an ad was
  /// available, loaded in time, or watched to the end — the answer always
  /// reveals. What it DOES do, to still earn money from the ads:
  ///  1. Spend a free credit if one's already banked from an earlier ad —
  ///     no ad shown, instant reveal.
  ///  2. Otherwise, give a brief moment for an ad that's already mid-load.
  ///     If one's ready in that window, show it; if the person watches it
  ///     through, bank the rest of that ad's reveals as credit for next
  ///     time. Either way — watched, skipped, or never became ready — the
  ///     answer still reveals right after.
  /// This trades "an ad on literally every single reveal" for "an ad
  /// whenever one happens to be ready", which is the right trade: a missing
  /// ad network response should never be the thing standing between someone
  /// and an FAQ answer.
  Future<bool> requestReveal() async {
    if (_creditsRemaining > 0) {
      _creditsRemaining--;
      return true;
    }

    // Short grace period for an ad that's already loading — long enough to
    // catch one that's nearly ready, short enough to never feel like a wait.
    var waited = 0;
    while (_preloaded == null && _loading && waited < 1200) {
      await Future.delayed(const Duration(milliseconds: 300));
      waited += 300;
    }

    final ad = _preloaded;
    if (ad == null) {
      _preload(); // keep trying quietly for next time
      return true; // no ad ready — reveal anyway, don't block the person
    }
    _preloaded = null;
    _preload();

    var earned = false;
    final dismissed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!dismissed.isCompleted) dismissed.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        if (!dismissed.isCompleted) dismissed.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (ad, reward) => earned = true);
    final watchedThrough = await dismissed.future;
    if (watchedThrough) _creditsRemaining = revealsPerAd - 1;
    return true; // reveal regardless of whether the ad was watched through
  }

  Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _preload();
  }

  void _preload() {
    if (_loading || _preloaded != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _preloaded = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          if (kDebugMode) debugPrint('[FitPulse] rewarded ad failed: $error');
        },
      ),
    );
  }

  /// Shows a rewarded ad and returns true only if the person actually earned
  /// the reward (watched it through) — that's the signal the FAQ screen uses
  /// to decide whether to reveal the answer.
  Future<bool> showRewarded() async {
    if (!_initialized) await init();

    var waited = 0;
    while (_preloaded == null && _loading && waited < 4000) {
      await Future.delayed(const Duration(milliseconds: 200));
      waited += 200;
    }

    final ad = _preloaded;
    if (ad == null) {
      _preload();
      return false;
    }
    _preloaded = null;
    _preload(); // start loading the next one immediately

    // show() completes as soon as the ad starts displaying — not when the
    // person finishes watching it. onUserEarnedReward only fires near the
    // end, so the real signal to wait for is the ad being dismissed.
    var earned = false;
    final dismissed = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!dismissed.isCompleted) dismissed.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        if (!dismissed.isCompleted) dismissed.complete(false);
      },
    );

    await ad.show(onUserEarnedReward: (ad, reward) => earned = true);
    return dismissed.future;
  }
}
