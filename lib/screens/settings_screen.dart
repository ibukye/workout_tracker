import 'package:flutter/material.dart';

// Setting Screen
// TODO: SettingsScreen を作成
// - 単純に「設定画面です」と表示
// - 将来的にテーマ切り替えやバックアップ設定を追加
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setting'), backgroundColor: Colors.blue.shade50, toolbarHeight: 45,),
      body: const Center(
        child: Text('ここに設定項目を追加'),
        // TODO: テーマ切り替えスイッチ
        // TODO: データバックアップ/リストア機能
      ),
    );
  }
}