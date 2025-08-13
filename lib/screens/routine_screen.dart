import 'package:flutter/material.dart';

import '../data/database.dart'; // dbインスタンスやCategory、Exerciseクラスのため
import '../main.dart';         // グローバルなdbインスタンスを使うため
import 'add_workout_detail_screen.dart'; // 再生ボタンからの画面遷移のため

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
        toolbarHeight: 45,
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