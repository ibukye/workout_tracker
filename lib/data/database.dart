// database.dart の修正版

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// 自動生成ファイルのpartディレクティブ
part 'database.g.dart'; // ←ここはdriftのコード生成で使うのでファイル名を間違えないこと

// 今日の日付を取得する
final today = DateTime.now();

// ① テーブルの定義（Workoutsテーブル）
// それぞれのカラムをどう定義するかを指定
class Workouts extends Table {
  // 主キー、自動採番
  IntColumn get id => integer().autoIncrement()();
  // ワークアウトの種目名
  TextColumn get name => text()();
  // 重量(kg)
  RealColumn get weight => real()();
  // 回数(reps)
  IntColumn get reps => integer()();
  // セット数(sets)
  IntColumn get sets => integer()();
  // 記録した日時
  DateTimeColumn get date => dateTime()();
}

// 部位table
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

// Training項目table
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get order => integer().withDefault(const Constant(0))(); // 表示順序
}

// 🎯 Routineテーブルを追加
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dayOfWeek => integer()(); // 0=Monday, 1=Tuesday, ..., 6=Sunday
  TextColumn get exerciseName => text()();
  IntColumn get order => integer().withDefault(const Constant(0))(); // 表示順序
}

// ② データベースクラス定義
@DriftDatabase(tables: [Workouts, Categories, Exercises, Routines])
class AppDatabase extends _$AppDatabase {
  // データベースファイルを開く処理を呼び出して初期化
  AppDatabase() : super(_openConnection());

  // スキーマバージョン（DBのバージョン管理用）
  @override
  int get schemaVersion => 4;

  // 🎯 MigrationStrategyを追加
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // 初めてDBが作られるときに全てのテーブルを作成
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // バージョンアップ時に必要なテーブルやカラムを追加
        if (from < 2) {
          await m.createTable(categories);
          await m.createTable(exercises);
        }
        if (from < 3) {
          await m.createTable(routines);
        }
        if (from < 4) {
          await m.addColumn(exercises, exercises.order);
        }
      },
      beforeOpen: (details) async {
        // DBが開かれる直前に毎回呼ばれる
        // もしDBが新規作成されたか、アップグレードされた場合
        if (details.wasCreated || details.hadUpgrade) {
          // デフォルトデータが存在しないことを確認してから挿入
          final hasData = await (select(categories).get().then((l) => l.isNotEmpty));
          if (!hasData) {
            await _insertDefaultData();
          }
        }
      },
    );
  }

  // 🎯 デフォルトの部位とトレーニング項目を追加
  Future<void> _insertDefaultData() async {
    print('デフォルトデータを作成中...');
    
    try {
      // デフォルト部位を追加
      final defaultCategories = ['Chest', 'Arm', 'Shoulder', 'Back', 'Abs', 'Leg'];
      
      for (final categoryName in defaultCategories) {
        // カテゴリーを追加
        final categoryId = await into(categories).insert(
          CategoriesCompanion.insert(name: categoryName)
        );
        
        print('カテゴリー "$categoryName" を作成しました (ID: $categoryId)');
        
        // 各部位にデフォルトのトレーニング項目を追加
        List<String> exercises = _getDefaultExercises(categoryName);
        
        for (final exerciseName in exercises) {
          final exerciseId = await into(this.exercises).insert(ExercisesCompanion.insert(
            name: exerciseName,
            categoryId: categoryId,
            order: Value(exercises.indexOf(exerciseName)), // 順序を設定
          ));
          print('  エクササイズ "$exerciseName" を作成しました (ID: $exerciseId)');
        }
      }
      
      print('デフォルトデータの作成が完了しました');
    } catch (e) {
      print('デフォルトデータの作成中にエラーが発生: $e');
      rethrow; // エラーを再スロー
    }
  }

  // 🎯 カテゴリー別のデフォルトエクササイズを取得
  List<String> _getDefaultExercises(String categoryName) {
    switch (categoryName) {
      case 'Chest':
        return ['Chest Press', 'Dumbbell Bench Press', 'Pec Fly', 'Dumbbell Fly', 'Push-up'];
      case 'Arm':
        return ['Dumbbell Curl', 'Hammer Curl', 'Tricep Extension', 'Tricep Dips'];
      case 'Shoulder':
        return ['Shoulder Press', 'Side Raise', 'Front Raise', 'Rear Delt Fly'];
      case 'Back':
        return ['Pull-up', 'Deadlift', 'Lat Pulldown', 'Seated Row'];
      case 'Abs':
        return ['Crunch', 'Plank', 'Russian Twist', 'Leg Raise'];
      case 'Leg':
        return ['Squat', 'Leg Press', 'Leg Extension', 'Leg Curl', 'Calf Raise'];
      default:
        return [];
    }
  }

  // 🎯 デフォルトデータが存在するかチェック
  Future<bool> hasDefaultData() async {
    try {
      final categoryCount = await (selectOnly(categories)
        ..addColumns([categories.id.count()])).getSingle();
      
      final count = categoryCount.read(categories.id.count()) ?? 0;
      print('カテゴリー数: $count');
      return count > 0;
    } catch (e) {
      print('デフォルトデータチェック中にエラー: $e');
      return false;
    }
  }

  // 🎯 手動でデフォルトデータを再作成（設定画面などから呼び出し可能）
  Future<void> recreateDefaultData() async {
    try {
      print('デフォルトデータを再作成中...');
      // 既存のエクササイズとカテゴリーを削除
      await delete(exercises).go();
      await delete(categories).go();
      
      // デフォルトデータを再作成
      await _insertDefaultData();
      print('デフォルトデータの再作成が完了しました');
    } catch (e) {
      print('デフォルトデータの再作成中にエラー: $e');
      rethrow;
    }
  }

  // --- カテゴリー一覧とエクササイズ一覧を取得 ---
  Future<Map<Category, List<Exercise>>> getCategoriesWithExercises() async {
    try {
      // 1. 全てのカテゴリーを1回のクエリで取得
      final categoryList = await select(categories).get();
      // 2. 全てのエクササイズを1回のクエリで取得
      final exerciseList = await select(exercises).get();

      // Dart側でエクササイズをcategoryIdごとにグループ化する
      final Map<int, List<Exercise>> exercisesByCategoryId = {};
      for (final exercise in exerciseList) {
        (exercisesByCategoryId[exercise.categoryId] ??= []).add(exercise);
      }

      // カテゴリーにエクササイズを紐付ける
      final Map<Category, List<Exercise>> result = {};
      for (final cat in categoryList) {
        // 順序でソートしながら紐付け
        final exercisesForCategory = exercisesByCategoryId[cat.id] ?? [];
        exercisesForCategory.sort((a, b) => a.order.compareTo(b.order));
        result[cat] = exercisesForCategory;
      }
      
      print('カテゴリー取得完了: ${result.length} カテゴリー (効率化版)');
      return result;
    } catch (e) {
      print('カテゴリー取得中にエラー: $e');
      return {};
    }
  }

  // --- カテゴリーを追加 ---
  Future<int> insertCategory(String name) {
    return into(categories).insert(CategoriesCompanion.insert(name: name));
  }

  // --- エクササイズを追加 ---
  Future<int> insertExercise(String name, int categoryId) async {
    // 同じカテゴリーの最大order値を取得
    final maxOrder = await (selectOnly(exercises)
      ..addColumns([exercises.order.max()])
      ..where(exercises.categoryId.equals(categoryId)))
      .getSingleOrNull();
    
    final nextOrder = (maxOrder?.read(exercises.order.max()) ?? -1) + 1;
    
    return into(exercises).insert(
      ExercisesCompanion.insert(
        name: name, 
        categoryId: categoryId,
        order: Value(nextOrder),
      ),
    );
  }

// エクササイズ名を更新
  Future<int> updateExerciseName(int exerciseId, String newName) async {
    return await (update(exercises)
      ..where((e) => e.id.equals(exerciseId)))
      .write(ExercisesCompanion(name: Value(newName)));
  }

// エクササイズを削除
Future<int> deleteExercise(int exerciseId) async {
  return await (delete(exercises)
    ..where((e) => e.id.equals(exerciseId)))
    .go();
}

// カテゴリーを削除（関連するエクササイズも削除）
Future<void> deleteCategory(int categoryId) async {
  try {
    // 関連するエクササイズを先に削除
    await (delete(exercises)
      ..where((e) => e.categoryId.equals(categoryId)))
      .go();
    
    // カテゴリーを削除
    await (delete(categories)
      ..where((c) => c.id.equals(categoryId)))
      .go();
  } catch (e) {
    print('カテゴリー削除中にエラー: $e');
    rethrow;
  }
}

  // カテゴリー名を更新
  Future<int> updateCategoryName(int categoryId, String newName) async {
    return await (update(categories)
      ..where((c) => c.id.equals(categoryId)))
      .write(CategoriesCompanion(name: Value(newName)));
  }

  // 🎯 すべてのエクササイズ名を取得（Routine用）
  Future<List<String>> getAllExerciseNames() async {
    try {
      final exerciseList = await select(exercises).get();
      return exerciseList.map((e) => e.name).toList()..sort();
    } catch (e) {
      print('エクササイズ名取得中にエラー: $e');
      return [];
    }
  }

  // エクササイズの順序を更新
  Future<void> reorderExercises(int categoryId, List<int> exerciseIds) async {
    try {
      // トランザクションを使用して一括更新
      await transaction(() async {
        for (int i = 0; i < exerciseIds.length; i++) {
          await (update(exercises)
            ..where((e) => e.id.equals(exerciseIds[i]) & e.categoryId.equals(categoryId)))
            .write(ExercisesCompanion(order: Value(i)));
        }
      });
      print('エクササイズの順序を更新しました');
    } catch (e) {
      print('エクササイズ順序更新中にエラー: $e');
      rethrow;
    }
  }

  // 🎯 Routine関連のメソッド
  
  // 曜日ごとのRoutineを取得
  Future<Map<int, List<String>>> getWeeklyRoutines() async {
    try {
      final routineList = await (select(routines)
        ..orderBy([(r) => OrderingTerm.asc(r.dayOfWeek), (r) => OrderingTerm.asc(r.order)]))
        .get();
      
      final Map<int, List<String>> result = {};
      
      for (int i = 0; i < 7; i++) {
        result[i] = [];
      }
      
      for (final routine in routineList) {
        result[routine.dayOfWeek]?.add(routine.exerciseName);
      }
      
      return result;
    } catch (e) {
      print('週間ルーチン取得中にエラー: $e');
      return {for (int i = 0; i < 7; i++) i: []};
    }
  }

  // Routineに運動を追加
  Future<int> addRoutine(int dayOfWeek, String exerciseName) async {
    try {
      // 同じ曜日の最大order値を取得
      final maxOrder = await (selectOnly(routines)
        ..addColumns([routines.order.max()])
        ..where(routines.dayOfWeek.equals(dayOfWeek)))
        .getSingleOrNull();
      
      final nextOrder = (maxOrder?.read(routines.order.max()) ?? -1) + 1;
      
      return await into(routines).insert(
        RoutinesCompanion.insert(
          dayOfWeek: dayOfWeek,
          exerciseName: exerciseName,
          order: Value(nextOrder),              // ← Value<int>
        ),
      );
    } catch (e) {
      print('ルーチン追加中にエラー: $e');
      rethrow;
    }
  }

  // Routineから運動を削除
  Future<int> removeRoutine(int dayOfWeek, String exerciseName) async {
    return await (delete(routines)
      ..where((r) => r.dayOfWeek.equals(dayOfWeek) & r.exerciseName.equals(exerciseName)))
      .go();
  }


  // ③ 全ワークアウトデータを取得するメソッド
  Future<List<Workout>> getAllWorkouts() {
    return (select(workouts)
          ..orderBy(
            [(w) => OrderingTerm.desc(w.date)], // 日付降順で並べる
          ))
        .get();
  }

  // ワークアウトがある日付のみを取得（効率化版）
  Future<Set<DateTime>> getWorkoutDates() async {
    try {
      // workoutsテーブルからdateカラムだけを重複なく取得
      final query = selectOnly(workouts, distinct: true)..addColumns([workouts.date]);
      final results = await query.get();
      
      // 日付部分（年/月/日）のみを抽出してSetに変換
      final dates = results.map((row) {
        final date = row.read(workouts.date)!;
        return DateTime(date.year, date.month, date.day);
      }).toSet();
      
      return dates;
    } catch (e) {
      print('Error in getWorkoutDates: $e');
      return <DateTime>{};
    }
  }

  // today's ワークアウトを取得するメソッド
  Future<Map<String, List<Workout>>> getWorkoutsByName({required DateTime today}) async {
    // 今日の0時を作る
    final start = DateTime(today.year, today.month, today.day);
    // 明日の0時を作る
    final end = start.add(Duration(days: 1));

    final result = await (select(workouts)..where((tbl) => tbl.date.isBetweenValues(start, end))).get();

    // 種目ごとにまとめる
    final grouped = <String, List<Workout>>{};
    for (final workout in result) { 
      grouped.putIfAbsent(workout.name, () => []).add(workout); 
    }
    return grouped;
  }

  /// 特定の日に、特定の名前のワークアウトを取得する
  Future<List<Workout>> getWorkoutsByNameForDate(String name, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return (select(workouts)
          ..where((tbl) => tbl.name.equals(name) & tbl.date.isBetweenValues(start, end))
          ..orderBy([(w) => OrderingTerm.asc(w.sets)])) // セット順に並べる
        .get();
  }

  // ④ ワークアウトを追加するメソッド
  Future<int> insertWorkout(WorkoutsCompanion workout) {
    return into(workouts).insert(workout);
  }

  // Workoutを削除するメソッド parameter: id
  Future<int> deleteWorkout(int id) {
    return (delete(workouts)..where((tbl) => tbl.id.equals(id))).go();
  }

   /// 特定の種目の最大重量を取得する（結果がない場合は0.0を返す）
  Future<double> maxWeightByName(String name) async {
    final query = customSelect(
      'SELECT MAX(weight) AS max_weight FROM workouts WHERE name = ?',
      variables: [Variable.withString(name)],
      readsFrom: {workouts},
    );

    final row = await query.getSingleOrNull();

    // rowがnull、またはmax_weightがnullの場合に0.0を安全に返す
    if (row == null || row.data['max_weight'] == null) {
      return 0.0;
    }

    // 取得した値をdoubleとして返す
    return row.read<double>('max_weight');
  }
}

// ⑥ DBファイルのオープン処理
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // ストレージのドキュメントディレクトリを取得
    final dbFolder = await getApplicationDocumentsDirectory();
    // DBファイルのパスを作成
    final file = File(p.join(dbFolder.path, 'workout.sqlite'));
    // NativeDatabaseを返す
    return NativeDatabase(file);
  });
}