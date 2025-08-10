import 'package:flutter/material.dart';
// ↓ SQLite(Drift)を使う場合に必要なインポート（後で追加）
// import 'package:drift/drift.dart' as drift;
// import 'package:drift/native.dart';
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';

void main() {
  runApp(const WorkoutTrackerApp());
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 各タブで表示する画面
  final List<Widget> _pages = [
    const HomeScreen(),
    // TODO: ここに「記録追加画面」を作って追加してください
    const AddWorkoutScreen(), // ←仮の画面（本当は AddWorkoutScreen() を作る）
    // TODO: ここに「設定画面」を作って追加してください
    const Placeholder(), // ←仮の画面（本当は SettingsScreen() を作る）
  ];

  // タブをタップしたときに呼ばれる関数
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // 選択中の画面を表示
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: '追加',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

// Home Screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ホーム画面')),
      body: const Center(
        child: Text('ここに今日の記録や統計を表示します'),
        // TODO: SQLiteから「今日の記録」を読み込んでリスト表示
        // TODO: 総重量やMAX重量などを計算して表示
        // TODO: 将来的にグラフ（charts_flutter など）で推移表示
      ),
    );
  }
}

// Add Workout Screen
class AddWorkoutScreen extends StatelessWidget {
  const AddWorkoutScreen({super.key});

  // Workout Data structure 
  final Map<String, List<String>> workoutCategories = const {
    'Abs': ['Crunch', 'Plank'],
    'Leg': ['Squat', 'Leg Press'],
    'Arm': ['Bicep Curl', 'Tricep Extension'],
    'Shoulder': ['Overhead Press', 'Lateral Raise'],
    'Back': ['Pull-up', 'Deadlift'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Workout')),
      body: ListView(
        children: workoutCategories.entries.map((entry) {
          final category = entry.key;
          final workouts = entry.value;

          return ExpansionTile(
            title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: workouts.map((workoutName) {
              return ListTile(
                title: Text(workoutName),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: タップされたワークアウト名を AddWorkoutDetailScreen に渡して遷移する処理を書く
                  //       この先でSQLiteにデータをInsertする処理を書くことになる
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddWorkoutDetailScreen(workoutName: workoutName)));
                },
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

// Add Workout Detail Screen
class AddWorkoutDetailScreen extends StatelessWidget {
  final String workoutName; // TapされたworkoutNameを受け取る
  const AddWorkoutDetailScreen({super.key, required this.workoutName});

  @override
  Widget build(BuildContext context) {
    // Form用のcontroller
    final TextEditingController weightController = TextEditingController();
    final TextEditingController repsController = TextEditingController();
    final TextEditingController setsController = TextEditingController(text: '1');

    return Scaffold(
      appBar: AppBar(title: Text(workoutName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // input weight
            TextField(controller: weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)'),),
            // input reps
            TextField(controller: repsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'reps'),),
            // input sets default is 1
            TextField(controller: setsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'sets'),),
            // emtpy line
            const SizedBox(height: 20),
            // Submit Button
            ElevatedButton(
              onPressed: () {
                // TODO: 入力データをSQLiteに保存する処理を追加
                // 例:
                // final workout = WorkoutsCompanion(
                //   name: drift.Value(workoutName),
                //   weight: drift.Value(int.parse(weightController.text)),
                //   reps: drift.Value(int.parse(repsController.text)),
                //   sets: drift.Value(int.parse(setsController.text)),
                //   date: drift.Value(DateTime.now()),
                // );
                // await db.insertWorkout(workout);
                Navigator.pop(context); // 入力完了後に前の画面に戻る
              },
              child: const Text('Save'),
            ),
          ], 
        ),
      ),
    );
  }
}

// Setting Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setting')),
      body: const Center(
        child: Text('ここに設定項目を追加'),
        // TODO: テーマ切り替えスイッチ
        // TODO: データバックアップ/リストア機能
      ),
    );
  }
}

// TODO: AddWorkoutScreen を作成
// - 種目名を入力する TextField
// - 重量・回数を入力する NumberField
// - 保存ボタンを配置
// - 保存後はホーム画面に戻る or データベースに保存

// TODO: SettingsScreen を作成
// - 単純に「設定画面です」と表示
// - 将来的にテーマ切り替えやバックアップ設定を追加

// =========================
// ▼ Drift(SQLite) 実装予定位置
// =========================
// 1. Workoutsテーブル定義（name, weight, reps, sets, date）
// 2. AppDatabaseクラス作成（insert, query, delete, update関数）
// 3. main.dartでDatabaseインスタンスをグローバルまたはProvider経由で渡す
// 4. AddWorkoutDetailScreenからinsertを呼ぶ
// 5. HomeScreenでselectして表示
