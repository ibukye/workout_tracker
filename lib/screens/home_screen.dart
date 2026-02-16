import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../main.dart'; // SelectedDayNotifier を使うため
import '../data/database.dart'; // db や Workout クラスを使うため
import 'add_workout_screen.dart'; // 画面遷移のため
import 'add_workout_detail_screen.dart'; // 画面遷移のため

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
    // 初期化時は空のFutureを設定（didChangeDependenciesで実際のデータを取得）
    _todaysWorkouts = Future.value({});
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
      appBar: AppBar(title: const Text('Home'), backgroundColor: Colors.blue.shade50, toolbarHeight: 45,),
      body: FutureBuilder<Map<String, List<Workout>>>(
        future: _todaysWorkouts, 
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;
          final workoutMap = snapshot.data ?? {};
          final entries = workoutMap.entries.toList();

          return Column(
            children: [
              // TODO: Notification 実装
              /*
              ElevatedButton(child: const Text('notification'), onPressed: showNotification,),
              ElevatedButton(
                onPressed: () {
                  scheduleNotification(id: 1, minutesLater: 1, message: 'done');
                  scheduleNotification(id: 2, minutesLater: 10, message: '10 min later');
                },
                child: Text('Training Finished'),
              ),*/
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35, 
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
                          Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => AddWorkoutDetailScreen(
                              workoutName: name, 
                              selectedDay: selectedDay
                            ),
                          ),
                        ).then((result) {
                          if (result == true) {
                            _fetchWorkoutsForDay(selectedDay); // この部分で更新されます
                          }
                        });
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
                ),
              ),
            ]
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AddWorkoutScreen()))
                      .then((_) {_loadWorkoutDates();});},
                    child: const Icon(Icons.add),
      )
    );
  }
}