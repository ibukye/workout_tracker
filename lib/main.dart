import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workout_tracker/screens/main_screen.dart'; // 最初に表示する画面をインポート

import 'data/database.dart'; // db を使うため

// dbのインスタンスはグローバルにここに置くのが一般的
final db = AppDatabase();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await requestNotificationPermission();
  await createNotificationChannel();

  // このまま
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  // Androidのプラグインインスタンスを取得
  final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    // 正確なアラームの権限をリクエストする
    await androidPlugin.requestExactAlarmsPermission();
  }

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => SelectedDayNotifier(),
      child: const WorkoutTrackerApp(),
    ),
  );
}

// SelectedDayNotifierはmain.dartに残しても良い
class SelectedDayNotifier extends ChangeNotifier {
  DateTime _day = DateTime.now();
  DateTime get day => _day;

  void setDay(DateTime newDay) {
    _day = newDay;
    notifyListeners();
  }
}

class WorkoutTrackerApp extends StatelessWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const MainScreen(), // MainScreenを呼び出す
    );
  }
}

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}

Future<void> createNotificationChannel() async {
  const channel = AndroidNotificationChannel(
    'workout_channel',
    'Workout Notifications',
    description: '通知の説明',
    importance: Importance.high,
  );

  final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(channel);
  }
}

Future<void> scheduleNotification({required int id, required int minutesLater, required String message}) async {

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Protein Reminder',
    message,
    tz.TZDateTime.now(tz.local).add(Duration(minutes: minutesLater)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_channel', 
          'Workout Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

// 通知
void showNotification() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'workout_channel', // チャンネルID
    'Workout Notifications', // チャンネル名
    description: '通知の説明',
    importance: Importance.high,
  );

  final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(channel);
  }

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'workout_channel', // チャンネルID
    'Workout Notifications',
    channelDescription: '通知の説明',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    'It\'s time to train!',
    'Record your workout',
    notificationDetails,
  );
}


// TODO: 通知
// TODO: 最後の履歴追加が終わってから30分後にはプロテインを飲むことを催促する通知を作成する

// TODO: 今日のトレーニング履歴で間違ったところを消せるようにしたい

// TODO: 広告は三分間とか

// TODO: AddWorkoutScreenに今日のトレーニングを追加？

// TODO: 初期値: Weightとrepsの入力欄に、前回同じ種目で記録した数値を薄くヒント表示（hintText）すると親切です。

// TODO: 統計・グラフ機能
/*
トレーニングの成果を可視化する機能は、ユーザーのモチベーションを大いに高めます。
種目ごとのMAX重量推移グラフ: fl_chartのようなライブラリを使い、種目ごとの最大重量の変遷を折れ線グラフで表示します。
部位ごとのトレーニング量: 月ごとに、どの部位をどれくらいの量（セット数やボリューム）こなしたかを円グラフや棒グラフで表示します。
新しいタブ（例：「Stats」）を追加して、これらのグラフをまとめて表示するのが良いでしょう。
*/

// OK: エクササイズの順序を並び替えたら毎回リフレッシュされるのをなくしたい -> チェックボタンをクリックしたらその順番を保存するみたいな感じ

// OK: 例えばLegPressを押して項目を追加する画面に行った後に、戻るという操作をしたらAddWorkout画面ですべてのトグルが閉じている状態になるんですけど、一回開いたトグルの状態を保存することはできませんか