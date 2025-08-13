import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;

import '../data/database.dart'; // WorkoutsCompanionやdbインスタンスのため
import '../main.dart';         // scheduleNotificationやグローバル変数を使うため
import 'main_screen.dart';      // 最後の画面遷移でMainScreenに戻るため

// Add Workout Detail Screen
class AddWorkoutDetailScreen extends StatefulWidget {
  final String workoutName; // TapされたworkoutNameを受け取る
  final DateTime selectedDay; // Tapされた日付を受け取る
  const AddWorkoutDetailScreen({super.key, required this.workoutName, required this.selectedDay});

  @override
  State<AddWorkoutDetailScreen> createState() => _AddWorkoutDetailScreenState();
}

class _AddWorkoutDetailScreenState extends State<AddWorkoutDetailScreen> {
  // 👈 Stateクラスを作成

  // --- 1. コントローラーとFocusNodeをここで宣言 ---
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _setsController = TextEditingController(text: '1');

  final _weightFocusNode = FocusNode();
  final _repsFocusNode = FocusNode();
  final _setsFocusNode = FocusNode();

  @override
  void dispose() {
    // --- 2. widgetが不要になったらリソースを解放 ---
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();

    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    _setsFocusNode.dispose();

    super.dispose();
  }

  // --- 3. 保存処理をメソッドとして分離 ---
  Future<void> _saveWorkout() async {
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);
    final sets = int.tryParse(_setsController.text);

    if (weight == null || reps == null || sets == null || reps == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正しい数値を入力してください')),
      );
      return;
    }

    final workout = WorkoutsCompanion(
      name: drift.Value(widget.workoutName),
      weight: drift.Value(weight),
      reps: drift.Value(reps),
      sets: drift.Value(sets),
      date: drift.Value(widget.selectedDay),
    );
    await db.insertWorkout(workout);

    // 以前の通知があればキャンセルし、新しい通知を30分後にスケジュールする
    await flutterLocalNotificationsPlugin.cancel(999); // 通知IDを固定してキャンセル
    await scheduleNotification(
      id: 999, // プロテイン通知専用のID
      minutesLater: 1, // 30分後
      message: 'トレーニングお疲れ様でした！プロテインを摂取しましょう💪',
    );

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.workoutName)), // 👈 widget.を付けてアクセス
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // input weight
            TextField(
              controller: _weightController, // 👈 Stateのコントローラーを使用
              focusNode: _weightFocusNode,   // 👈 FocusNodeを紐付け
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              textInputAction: TextInputAction.next, // 👈 キーボードのアクションを「次へ」に
              onEditingComplete: () {
                // 👈 エンターを押したら次のreps欄にフォーカスを移動
                FocusScope.of(context).requestFocus(_repsFocusNode);
              },
            ),
            // input reps
            TextField(
              controller: _repsController,
              focusNode: _repsFocusNode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'reps'),
              textInputAction: TextInputAction.next,
              onEditingComplete: () {
                // 👈 エンターを押したら次のsets欄にフォーカスを移動
                FocusScope.of(context).requestFocus(_setsFocusNode);
              },
            ),
            // input sets default is 1
            TextField(
              controller: _setsController,
              focusNode: _setsFocusNode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'sets'),
              textInputAction: TextInputAction.done, // 👈 最後なのでアクションを「完了」に
              onEditingComplete: _saveWorkout,       // 👈 エンターを押したら保存処理を実行
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveWorkout, // 👈 ボタンも同じ保存処理を呼ぶ
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}