import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;

import '../data/database.dart'; // WorkoutsCompanionやdbインスタンスのため
import '../main.dart';         // scheduleNotificationやグローバル変数を使うため
import 'main_screen.dart';      // 最後の画面遷移でMainScreenに戻るため

import '../services/ad_manager.dart'; // 👈 作成したファイルをインポート

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

  // スクロールバーcontroller
  final _scrollController = ScrollController();

  // 履歴とMAX重量を保持するState変数
  List<Workout> _todaysHistory = [];
  double? _maxWeight;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // 初期データをロードするメソッドを呼び出す

    // WeightのTextFieldがフォーカスされたときの処理
    _weightFocusNode.addListener(() {
      if (_weightFocusNode.hasFocus) {
        // フォーカスが当たった直後にテキストを全選択する
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _weightController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _weightController.text.length,
          );
        });
      }
    });

    // RepsのTextFieldがフォーカスされたときの処理
    _repsFocusNode.addListener(() {
      if (_repsFocusNode.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _repsController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _repsController.text.length,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    // --- 2. widgetが不要になったらリソースを解放 ---
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();

    // FocusNodeからリスナーを削除
    _weightFocusNode.removeListener(() {});
    _repsFocusNode.removeListener(() {});

    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    _setsFocusNode.dispose();

     _scrollController.dispose();

    super.dispose();
  }

  // データを取得するメソッド
  Future<void> _loadInitialData() async {
    // 今日の履歴を取得
    final history = await db.getWorkoutsByNameForDate(widget.workoutName, widget.selectedDay);
    // Max重量を取得　
    final max = await db.maxWeightByName(widget.workoutName);

    setState(() {
      _todaysHistory = history;
      _maxWeight = max;
      _isLoading = false;
    });

    // 前回の記録をヒントとしてコントローラーに設定
    if (history.isNotEmpty) {
      _weightController.text = history.last.weight.toString();
      _repsController.text = history.last.reps.toString();
    }
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

    await AdManager.showInterstitialAdIfNeeded();

    // 以前の通知があればキャンセルし、新しい通知を30分後にスケジュールする
    await flutterLocalNotificationsPlugin.cancel(999); // 通知IDを固定してキャンセル
    await scheduleNotification(
      id: 999, // プロテイン通知専用のID
      minutesLater: 1, // 30分後
      message: 'トレーニングお疲れ様でした！プロテインを摂取しましょう💪',
    );

    if (mounted) {
      //Navigator.of(context).popUntil((route) => route.isFirst);
      //Navigator.of(context).pop(true);
      //Navigator.pop(context, true);
      // MainScreenのHomeタブ（インデックス0）に戻る
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 0)),
        (route) => false, // すべての既存routeを削除
      );
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
                  // 履歴表示エリアをFlexibleでラップ
                  Flexible(
                    flex: 2, // スペースの配分（デフォルトは1）
                    child: _buildHistorySection(),
                  ),

                  // 入力フォーム
                  _buildInputForm(),
                  
                  // 中央配置のキー
                  const Spacer(),
                  
                  // 下部: 保存ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveWorkout,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Save', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  // Layout

  // 履歴表示
  Widget _buildHistorySection() {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Today's History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_todaysHistory.isNotEmpty)
                  Chip(
                    label: Text('Total Sets: ${_todaysHistory.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.blue.shade100,
                    side: BorderSide.none,
                  ),
              ],
            ),
            // MAX重量のChipは合計セット数の下へ移動（デザインの好みで調整）
            if (_maxWeight != null && _maxWeight! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Chip(
                  label: Text('MAX: ${_maxWeight}kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.amber.shade100,
                  side: BorderSide.none,
                ),
              ),
            
            // 空白
            const SizedBox(height: 8),
            
            // 履歴表示
            _todaysHistory.isEmpty
              ? const Text('No records for today yet.', style: TextStyle(color: Colors.grey))
              : Column(
                children: _todaysHistory.asMap().entries.map((entry) {
                  final index = entry.key;
                  final workout = entry.value;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      'Set ${index+1}: ${workout.weight} kg x ${workout.reps} reps',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
      ),
    );
  }


  // 入力フォーム
  Widget _buildInputForm() {
    return Column(
      children: [
        TextField(
            controller: _weightController,
            focusNode: _weightFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
            textInputAction: TextInputAction.next,
            onEditingComplete: () => FocusScope.of(context).requestFocus(_repsFocusNode),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _repsController,
            focusNode: _repsFocusNode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
            textInputAction: TextInputAction.next,
            onEditingComplete: () => FocusScope.of(context).requestFocus(_setsFocusNode),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _setsController,
            focusNode: _setsFocusNode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sets'),
            textInputAction: TextInputAction.done,
            onEditingComplete: _saveWorkout,
          ),
      ],
    );
  }
}