import 'package:flutter/material.dart';
// ↓ SQLite(Drift)を使う場合に必要なインポート（後で追加）
import 'package:drift/drift.dart' as drift;

import 'package:workout_tracker/database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';

final db = AppDatabase();

void main() async {
  // 🎯 Flutter の初期化を確実に行う
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 🎯 データベースの初期化処理を実行
    print('アプリケーション起動: データベース初期化開始');
    await db.initializeApp();
    print('データベース初期化完了');
  } catch (e) {
    print('データベース初期化でエラーが発生しましたが、アプリを続行します: $e');
  }

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
  //DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final selectedDay = context.watch<SelectedDayNotifier>().day;
    final pages = [
      const HomeScreen(),                             // Home画面
      AddWorkoutScreen(selectedDay: selectedDay),     // ホーム画面のカレンダーで選択された日のトレーニング履歴に追加
      const RoutineScreen(),                          // 一週間のトレーニングメニューを作成できる＋通知機能つけたい
      const SettingsScreen(),                         // 
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Routine'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
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
      appBar: AppBar(title: const Text('ホーム画面'), backgroundColor: Colors.blue.shade50, toolbarHeight: 48,),
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
                height: 300, 
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
                  headerStyle: HeaderStyle(formatButtonVisible: false),
                  shouldFillViewport: true,
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
class AddWorkoutScreen extends StatefulWidget {
  final DateTime? selectedDay;
  const AddWorkoutScreen({super.key, this.selectedDay});

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  late Future<Map<Category, List<Exercise>>> _categoriesData;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _categoriesData = db.getCategoriesWithExercises();
  }

  void _refreshData() {
    setState(() {
      _categoriesData = db.getCategoriesWithExercises();
    });
  }

  void _toggleEditMode() {
    setState(() { _isEditMode = !_isEditMode; });
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.selectedDay ?? DateTime.now(); // デフォルト値を設定

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Exercises' : 'Add Workout'),
        backgroundColor: Colors.blue.shade50,
        toolbarHeight: 48,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.done : Icons.edit),
            color: _isEditMode ? Colors.green : Theme.of(context).colorScheme.onSurface,
            onPressed: _toggleEditMode,
          ),
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: Theme.of(context).colorScheme.onSurface,
              onPressed: _showAddCategoryDialog,
            ),
        ],
      ),
      //appBar: AppBar(title: const Text('Add Workout'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddCategoryDialog(),),],),
      body: FutureBuilder<Map<Category, List<Exercise>>>(
        future: _categoriesData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final categoriesData = snapshot.data ?? {};
          if (categoriesData.isEmpty) {
            return const Center(child: Text('カテゴリーが見つかりません'));
          }

          return ListView(
            children: categoriesData.entries.map((entry) {
              final category = entry.key;
              final exercises = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _getCategoryColor(category.name),
                    child: Icon(
                      _getCategoryIcon(category.name),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isEditMode)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.red,
                          onPressed: () => _confirmDeleteCategory(category),
                        ),
                      if (!_isEditMode)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: () => _showAddExerciseDialog(category),
                        ),
                    ],
                  ),
                  children: _isEditMode
                      ? [_buildEditableExerciseList(category, exercises)]
                      : exercises.map((exercise) {
                          return ListTile(
                            leading: Icon(
                              Icons.fitness_center,
                              color: _getCategoryColor(category.name),
                              size: 20,
                            ),
                            title: Text(exercise.name),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddWorkoutDetailScreen(
                                    workoutName: exercise.name,
                                    selectedDay: day,
                                  ),
                                ),
                              ).then((_) => _refreshData());
                            },
                          );
                        }).toList(),
                  ),
                );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildEditableExerciseList(Category category, List<Exercise> exercises) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exercises.length,
      onReorder: (int oldIndex, int newIndex) async {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        
        // 並び替え処理を実装
        final List<Exercise> reorderedExercises = List.from(exercises);
        final Exercise movedExercise = reorderedExercises.removeAt(oldIndex);
        reorderedExercises.insert(newIndex, movedExercise);
        
        // データベースの順序を更新
        final exerciseIds = reorderedExercises.map((e) => e.id).toList();
        
        try {
          await db.reorderExercises(category.id, exerciseIds);
          _refreshData(); // データを再取得して画面を更新
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('並び替えを保存しました'),
              duration: Duration(seconds: 1),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('並び替えの保存に失敗しました: $e')),
          );
        }
      },
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return Card(
          key: ValueKey(exercise.id),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: ListTile(
            dense: true,
            leading: Icon(
              Icons.drag_handle,
              color: Colors.grey.shade600,
            ),
            title: Text(exercise.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 14),
                  color: Colors.blue,
                  onPressed: () => _showEditExerciseDialog(exercise),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: Colors.red,
                  onPressed: () => _confirmDeleteExercise(exercise),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditExerciseDialog(Exercise exercise) {
    final controller = TextEditingController(text: exercise.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エクササイズ名を編集'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'エクササイズ名',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty && name != exercise.name) {
                await db.updateExerciseName(exercise.id, name);
                _refreshData();
                Navigator.pop(context);
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('カテゴリー「${category.name}」を削除しますか？\n関連するすべてのエクササイズも削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              try {
                await db.deleteCategory(category.id);
                _refreshData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('カテゴリー「${category.name}」を削除しました')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('エラーが発生しました: $e')),
                );
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExercise(Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('エクササイズ「${exercise.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              try {
                await db.deleteExercise(exercise.id);
                _refreshData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('エクササイズ「${exercise.name}」を削除しました')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('エラーが発生しました: $e')),
                );
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいカテゴリーを追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'カテゴリー名',
            hintText: 'Chest, Arms, Legs など',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await db.insertCategory(name);
                _refreshData();
                Navigator.pop(context);
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  // カテゴリー名に基づいて色を返すヘルパーメソッド
  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'chest':
        return Colors.red;
      case 'arm':
        return Colors.orange;
      case 'shoulder':
        return Colors.amber;
      case 'back':
        return Colors.green;
      case 'abs':
        return Colors.blue;
      case 'leg':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // カテゴリー名に基づいてアイコンを返すヘルパーメソッド
  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'chest':
        return Icons.favorite;
      case 'arm':
        return Icons.accessibility_new;
      case 'shoulder':
        return Icons.fitness_center;
      case 'back':
        return Icons.self_improvement;
      case 'abs':
        return Icons.sports_gymnastics;
      case 'leg':
        return Icons.directions_run;
      default:
        return Icons.fitness_center;
    }
  }

  void _showAddExerciseDialog(Category category) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${category.name}に新しいエクササイズを追加'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'エクササイズ名',
            hintText: 'Push-up, Sit-up など',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await db.insertExercise(name, category.id);
                _refreshData();
                Navigator.pop(context);
              }
            },
            child: const Text('追加'),
          ),
        ],
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
                // 入力データをSQLiteに保存する処理
                final workout = WorkoutsCompanion(
                  name: drift.Value(workoutName),
                  weight: drift.Value(weight),
                  reps: drift.Value(reps),
                  sets: drift.Value(sets),
                  date: drift.Value(selectedDay),
                );
                await db.insertWorkout(workout);
                //Navigator.pop(context); // 入力完了後に前の画面に戻る
                //Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen(),),);
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MainScreen()),  (route) => false,);
              },
              child: const Text('Save'),
            ),
          ], 
        ),
      ),
    );
  }
}



// Routine Screen
// 一週間の曜日の身のカレンダーを表示して、その曜日に何をするかを設定できる画面
// その日の決まった時間に通知を送ることが可能
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  Future<Map<int, List<String>>>? _weeklyRoutines;
  // 展開状態を保持するマップ
  late Map<int, bool> _expandedState = {};

  // 曜日名のマップ
   final Map<int, String> _dayNames = {
    0: 'Monday',
    1: 'Tuesday', 
    2: 'Wednesday',
    3: 'Thursday',
    4: 'Friday',
    5: 'Saturday',
    6: 'Sunday',
  };

  @override
  void initState() {
    super.initState();

    // 今日の曜日番号を取得（DateTime.monday=1〜sunday=7 を 0〜6 に変換）
    int todayWeekday = DateTime.now().weekday; // 1=Monday, 7=Sunday
    int todayIndex = todayWeekday == 7 ? 0 : todayWeekday; // 0=Monday, 6=Sunday に変換

    // 0〜6 まで false、今日だけ true にする
    _expandedState = {
      for (var i = 0; i < 7; i++) i: i == todayIndex,
    };

    _loadRoutines();
  }

  void _loadRoutines() {
    setState(() {
      _weeklyRoutines = db.getWeeklyRoutines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Routine'),
        backgroundColor: Colors.blue.shade50,
        toolbarHeight: 48,
      ),
      body: FutureBuilder<Map<int, List<String>>>(
        future: _weeklyRoutines, 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final routines = snapshot.data ?? {};
          
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: 7,
            itemBuilder: (context, index) {
              final dayOfWeek = index;
              final dayName = _dayNames[dayOfWeek]!;
              final dayRoutines = routines[dayOfWeek] ?? [];
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                elevation: 2,
                child: ExpansionTile(
                  key: PageStorageKey('day_$dayOfWeek'), // 状態保持のためのキー
                  initiallyExpanded: _expandedState[dayOfWeek] ?? false, // 今日だけ展開
                  onExpansionChanged: (expanded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _expandedState[dayOfWeek] = expanded;
                      });
                    });
                  },
                  title: Row(
                    children: [
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _getDayColor(dayOfWeek),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          dayName.substring(0, 3), // Mon, Tue, etc.
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${dayRoutines.length} exercises',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.blue,
                        onPressed: () => _showAddExerciseDialog(dayOfWeek, dayName),
                      ),
                    ],
                  ),
                  children: [
                    if (dayRoutines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No exercises added yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...dayRoutines.asMap().entries.map((entry) {
                        final exerciseName = entry.value;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          child: Card(
                            elevation: 1,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getDayColor(dayOfWeek).withOpacity(0.2),
                                child: Icon(
                                  Icons.fitness_center,
                                  color: _getDayColor(dayOfWeek),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                exerciseName,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    color: Colors.green,
                                    onPressed: () {
                                      // 今日の日付でAddWorkoutDetailScreenに遷移
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddWorkoutDetailScreen(
                                            workoutName: exerciseName,
                                            selectedDay: DateTime.now(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () => _confirmDeleteExercise(dayOfWeek, exerciseName),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        }
      ,) 
    );
  }
  Color _getDayColor(int dayOfWeek) {
    final colors = [
      Colors.red,      // Monday
      Colors.orange,   // Tuesday  
      Colors.yellow.shade700, // Wednesday
      Colors.green,    // Thursday
      Colors.blue,     // Friday
      Colors.indigo,   // Saturday
      Colors.purple,   // Sunday
    ];
    return colors[dayOfWeek];
  }

  void _showAddExerciseDialog(int dayOfWeek, String dayName) async {
    final categoriesData = await db.getCategoriesWithExercises();
    
    if (categoriesData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクササイズが登録されていません。まずエクササイズを追加してください。')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$dayNameに追加するエクササイズを選択'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: categoriesData.entries.map((entry) {
                final category = entry.key;
                final exercises = entry.value;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 2,
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(category.name),
                      child: Icon(
                        _getCategoryIcon(category.name),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      '${exercises.length} exercises',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    children: exercises.map((exercise) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Icon(
                            Icons.fitness_center,
                            color: _getCategoryColor(category.name),
                            size: 20,
                          ),
                          title: Text(
                            exercise.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: Icon(
                            Icons.add_circle_outline,
                            color: _getCategoryColor(category.name),
                          ),
                          onTap: () async {
                            try {
                              await db.addRoutine(dayOfWeek, exercise.name);
                              _loadRoutines();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${exercise.name}を$dayNameに追加しました')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('エラーが発生しました: $e')),
                              );
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  // カテゴリー名に基づいて色を返すヘルパーメソッド
  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'chest':
        return Colors.red;
      case 'arm':
        return Colors.orange;
      case 'shoulder':
        return Colors.amber;
      case 'back':
        return Colors.green;
      case 'abs':
        return Colors.blue;
      case 'leg':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // カテゴリー名に基づいてアイコンを返すヘルパーメソッド
  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'chest':
        return Icons.favorite;
      case 'arm':
        return Icons.accessibility_new;
      case 'shoulder':
        return Icons.fitness_center;
      case 'back':
        return Icons.self_improvement;
      case 'abs':
        return Icons.sports_gymnastics;
      case 'leg':
        return Icons.directions_run;
      default:
        return Icons.fitness_center;
    }
  }

  void _confirmDeleteExercise(int dayOfWeek, String exerciseName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('$exerciseNameを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await db.removeRoutine(dayOfWeek, exerciseName);
                _loadRoutines();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$exerciseNameを削除しました')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('エラーが発生しました: $e')),
                );
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}







// Setting Screen
// TODO: SettingsScreen を作成
// - 単純に「設定画面です」と表示
// - 将来的にテーマ切り替えやバックアップ設定を追加
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setting'), backgroundColor: Colors.blue.shade50, toolbarHeight: 48,),
      body: const Center(
        child: Text('ここに設定項目を追加'),
        // TODO: テーマ切り替えスイッチ
        // TODO: データバックアップ/リストア機能
      ),
    );
  }
}




// TODO: 通知
// TODO: 最後の履歴追加が終わってから30分後にはプロテインを飲むことを催促する通知を作成する

// TODO: エクササイズの順序を並び替えたら毎回リフレッシュされるのをなくしたい -> チェックボタンをクリックしたらその順番を保存するみたいな感じ

// TODO: 例えばLegPressを押して項目を追加する画面に行った後に、戻るという操作をしたらAddWorkout画面ですべてのトグルが閉じている状態になるんですけど、一回開いたトグルの状態を保存することはできませんか