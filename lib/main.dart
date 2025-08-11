import 'package:flutter/material.dart';
// ↓ SQLite(Drift)を使う場合に必要なインポート（後で追加）
import 'package:drift/drift.dart' as drift;

import 'package:workout_tracker/database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';

final db = AppDatabase();

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SelectedDayNotifier(),
      child: const WorkoutTrackerApp(),
    ),
  );
}

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
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final selectedDay = context.watch<SelectedDayNotifier>().day;
    final pages = [
      const HomeScreen(),
      AddWorkoutScreen(selectedDay: selectedDay),
      //const AddWorkoutScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '追加'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

   @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, List<Workout>>> _todaysWorkouts;
  Set<DateTime> _workoutDates = {};

  @override
  void initState() {
    super.initState();
    _todaysWorkouts = db.getWorkoutsByName(today: DateTime.now());
    _loadWorkoutDates(); // 初回ロード
  }

  void _loadWorkoutDates() async {
    try {
      final dates = await db.getWorkoutDates();
      setState(() {
        _workoutDates = dates;
      });
    } catch (e) {
      print('Error loading workout dates: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectedDay = context.watch<SelectedDayNotifier>().day;
    _fetchWorkoutsForDay(selectedDay);
  }

  void _fetchWorkoutsForDay(DateTime day) {
    setState(() {
      _todaysWorkouts = db.getWorkoutsByName(today: day);
    });
    _loadWorkoutDates(); // 日付を再取得
  }

  // 🎯 軽量なイベント判定
  List<dynamic> _getEventsForDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return _workoutDates.contains(dateOnly) ? ['workout'] : [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = context.watch<SelectedDayNotifier>().day;

    return Scaffold(
      appBar: AppBar(title: const Text('ホーム画面')),
      body: FutureBuilder<Map<String, List<Workout>>>(
        future: _todaysWorkouts, 
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;
          final workoutMap = snapshot.data ?? {};
          final entries = workoutMap.entries.toList();

          return Column(
            children: [
              SizedBox(
                height: 392, 
                child: TableCalendar(
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: selectedDay,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: (selectedDayNew, focusedDay) {
                    context.read<SelectedDayNotifier>().setDay(selectedDayNew);
                    _fetchWorkoutsForDay(selectedDayNew);
                  },
                  eventLoader: _getEventsForDay, // 🎯 軽量化されたローダー
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 2),),
                    selectedTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold,),
                    // 🎯 マーカーのスタイル設定
                    markerDecoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ), 
              Expanded(child: Builder(builder: (_) {
                if (isLoading) return const Center(child: CircularProgressIndicator());
                if (hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (entries.isEmpty) return const Center(child: Text('記録はありません'));
                
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final name = entry.key; // 種目名
                    final sets = entry.value; // List<Workout>

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text(sets.map((w) => '${w.weight}kg x ${w.reps}reps x ${w.sets}sets').join('\n')),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AddWorkoutDetailScreen(workoutName: name, selectedDay: selectedDay),),);
                        },
                      ),
                    );
                  },
                );
              })),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddWorkoutScreen(selectedDay: selectedDay))).then((_) {
                        _loadWorkoutDates(); // 追加後にマークを更新
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Workout'),
                  ),
                ),
              ),
            ]
          );
        },
      ),
    );
  }
}

// Add Workout Screen
class AddWorkoutScreen extends StatelessWidget {
  final DateTime? selectedDay;
  const AddWorkoutScreen({super.key, this.selectedDay});

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
    final day = selectedDay ?? DateTime.now(); // デフォルト値を設定

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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddWorkoutDetailScreen(workoutName: workoutName, selectedDay: day)));
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
  final DateTime selectedDay; // Tapされた日付を受け取る
  const AddWorkoutDetailScreen({super.key, required this.workoutName, required this.selectedDay});

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
              onPressed: () async {
                final weight = double.tryParse(weightController.text);
                final reps = int.tryParse(repsController.text);
                final sets = int.tryParse(setsController.text);

                if (weight == null || reps == null || sets == null) {
                  // 入力が不正の場合はアラート表示などの処理を入れる
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('正しい数値を入力してください')),
                  );
                  return;
                }
                // TODO: 入力データをSQLiteに保存する処理を追加
                final workout = WorkoutsCompanion(
                  name: drift.Value(workoutName),
                  weight: drift.Value(weight),
                  reps: drift.Value(reps),
                  sets: drift.Value(sets),
                  date: drift.Value(selectedDay),
                );
                await db.insertWorkout(workout);
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
