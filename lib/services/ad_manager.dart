import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdManager {
  /// 広告を表示する最小間隔（1時間）
  static const Duration _minInterval = Duration(hours: 1);

  /// 広告を表示するために必要な最小保存回数（3回）
  static const int _minSaveCount = 3;

  /// 必要であればインタースティシャル広告を表示するメソッド
  static Future<void> showInterstitialAdIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 最後の広告表示からの経過時間を確認
    final lastAdTimestamp = prefs.getInt('lastAdTimestamp') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastAdTimestamp < _minInterval.inMilliseconds) {
      // 最後の表示から時間が経っていない場合は、何もしない
      print('Ad interval not met. Skipping ad.');
      _incrementSaveCount(prefs); // 保存回数のカウントは進める
      return;
    }

    // 2. 保存回数を確認
    final saveCount = (prefs.getInt('saveCount') ?? 0) + 1;
    if (saveCount < _minSaveCount) {
      // 保存回数が足りない場合は、カウントを更新するだけ
      print('Save count not met ($saveCount/$_minSaveCount). Skipping ad.');
      await prefs.setInt('saveCount', saveCount);
      return;
    }

    // 3. 条件を満たした場合、広告を表示
    print('Conditions met. Showing interstitial ad.');
    _showInterstitialAd();

    // 4. 広告を表示したら、時刻と回数をリセット
    await prefs.setInt('lastAdTimestamp', now);
    await prefs.setInt('saveCount', 0);
  }

  /// 保存回数だけをインクリメントするプライベートメソッド
  static Future<void> _incrementSaveCount(SharedPreferences prefs) async {
    final saveCount = (prefs.getInt('saveCount') ?? 0) + 1;
    await prefs.setInt('saveCount', saveCount);
    print('Save count incremented to $saveCount');
  }

  /// 実際のインタースティシャル広告をロードして表示する処理
  static void _showInterstitialAd() {
    // 広告ユニットIDを、先ほどAdMobで作成したものに置き換えます
    final adUnitId = 'ca-app-pub-6399683469260585/1776255053';

    // google_mobile_adsパッケージを使った実装
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          // 広告表示後のコールバックを設定
          ad.fullScreenContentCallback = FullScreenContentCallback(
            // 広告が閉じられたら破棄する
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            // 広告の表示に失敗したら破棄する
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Ad failed to show: $error');
              ad.dispose();
            },
          );
          // 広告を表示
          ad.show();
        },
        onAdFailedToLoad: (error) {
          print('InterstitialAd failed to load: $error');
        },
      ),
    );
  }
}