import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'add_workout_screen.dart';
import 'routine_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // 初期インデックスを設定
  }

  // ▼▼▼ pagesリストを State のメンバーにする (contextを使わないのでこれでOK) ▼▼▼
  final List<Widget> _pages = [
    const HomeScreen(),
    const AddWorkoutScreen(), 
    const RoutineScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    //final selectedDay = context.watch<SelectedDayNotifier>().day;
    /*final pages = [
      const HomeScreen(),                             // Home画面
      AddWorkoutScreen(selectedDay: selectedDay),     // ホーム画面のカレンダーで選択された日のトレーニング履歴に追加
      const RoutineScreen(),                          // 一週間のトレーニングメニューを作成できる＋通知機能つけたい
      const SettingsScreen(),                         // 
    ];*/

    return Scaffold(
      // ▼▼▼ bodyをIndexedStackに変更 ▼▼▼
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
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