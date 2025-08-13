import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;

import '../main.dart'; // SelectedDayNotifier を使うため
import '../data/database.dart'; // db や Category, Exercise クラスを使うため
import 'add_workout_detail_screen.dart'; // 画面遷移のため


// Add Workout Screen
class AddWorkoutScreen extends StatefulWidget {
  //final DateTime? selectedDay;
  //const AddWorkoutScreen({super.key, this.selectedDay});
  const AddWorkoutScreen({super.key});

  @override
  State<AddWorkoutScreen> createState() => _AddWorkoutScreenState();
}

class _AddWorkoutScreenState extends State<AddWorkoutScreen> {
  Map<Category, List<Exercise>> _categoriesData = {};
  bool _isLoading = true;
  bool _isEditMode = false;

  // ▼▼▼ 状態を保持するマップを追加 ▼▼▼
  final Map<int, bool> _expansionState = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    final data = await db.getCategoriesWithExercises();
    setState(() {
      _categoriesData = data;
      _isLoading = false;
    });
  }

  void _refreshData() {
    _loadData();
  }

  // ▼▼▼ 編集モード切り替えと保存のロジック ▼▼▼
  void _toggleEditMode() async {
    // 編集モードが終了するとき（true -> false）に保存処理を実行
    if (_isEditMode) {
      await _saveAllReorderedExercises();
    }
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  // 保存処理をまとめた新しいメソッド
  Future<void> _saveAllReorderedExercises() async {
    try {
      for (final entry in _categoriesData.entries) {
        final categoryId = entry.key.id;
        final exerciseIds = entry.value.map((e) => e.id).toList();
        await db.reorderExercises(categoryId, exerciseIds);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('すべての順序を保存しました'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('順序の保存に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = context.watch<SelectedDayNotifier>().day;
    //final day = widget.selectedDay ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Exercises' : 'Add Workout'),
        backgroundColor: Colors.blue.shade50,
        toolbarHeight: 45,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categoriesData.isEmpty
              ? const Center(child: Text('カテゴリーが見つかりません'))
              // ▼▼▼ ListViewの修正 ▼▼▼
              : ListView(
                  children: _categoriesData.entries.map((entry) {
                    final category = entry.key;
                    final exercises = entry.value;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ExpansionTile(
                        key: PageStorageKey('category_${category.id}'), // 一意のキー
                        initiallyExpanded: _expansionState[category.id] ?? false,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _expansionState[category.id] = expanded;
                          });
                        },
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
                ),
    );
  }

  Widget _buildEditableExerciseList(Category category, List<Exercise> exercises) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exercises.length,
      // ▼▼▼ onReorderの修正 ▼▼▼
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final Exercise movedExercise = exercises.removeAt(oldIndex);
          exercises.insert(newIndex, movedExercise);
          // データベースへの保存はここでは行わない
        });
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