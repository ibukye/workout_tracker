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
}

// ② データベースクラス定義
@DriftDatabase(tables: [Workouts, Categories, Exercises])
class AppDatabase extends _$AppDatabase {
  // データベースファイルを開く処理を呼び出して初期化
  AppDatabase() : super(_openConnection());

  // スキーマバージョン（DBのバージョン管理用）
  @override
  int get schemaVersion => 2;

  // 🎯 MigrationStrategyを追加
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        print('データベースを初回作成中...');
        await m.createAll();
        // 初回作成時にデフォルトデータを挿入
        await _insertDefaultData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        print('データベースをアップグレード中... from: $from, to: $to');
        if (from < 2) {
          // バージョン1からのアップグレード処理
          await m.createTable(exercises);
          // 既存データがない場合のみデフォルトデータを挿入
          final existingCategories = await select(categories).get();
          if (existingCategories.isEmpty) {
            await _insertDefaultData();
          }
        }
      },
    );
  }

  // 🎯 アプリ起動時の初期化処理（明示的にチェック）
  Future<void> initializeApp() async {
    try {
      print('アプリ初期化開始...');
      
      // デフォルトデータが存在するかチェック
      final hasData = await hasDefaultData();
      print('デフォルトデータ存在チェック: $hasData');
      
      if (!hasData) {
        print('デフォルトデータが存在しないため、作成します...');
        await _insertDefaultData();
      } else {
        print('デフォルトデータは既に存在します');
      }
    } catch (e) {
      print('アプリ初期化中にエラーが発生: $e');
      // エラーが発生してもアプリが止まらないようにする
    }
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
      final categoryList = await select(categories).get();
      final Map<Category, List<Exercise>> result = {};

      for (final cat in categoryList) {
        final exList = await (select(exercises)
          ..where((e) => e.categoryId.equals(cat.id)))
          .get();
        result[cat] = exList;
      }
      
      print('カテゴリー取得完了: ${result.length} カテゴリー');
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
  Future<int> insertExercise(String name, int categoryId) {
    return into(exercises).insert(
      ExercisesCompanion.insert(name: name, categoryId: categoryId),
    );
  }

  // ③ 全ワークアウトデータを取得するメソッド
  Future<List<Workout>> getAllWorkouts() {
    return (select(workouts)
          ..orderBy(
            [(w) => OrderingTerm.desc(w.date)], // 日付降順で並べる
          ))
        .get();
  }

  // ワークアウトがある日付のみを取得（null安全）
  Future<Set<DateTime>> getWorkoutDates() async {
    try {
      // まずはシンプルにすべてのワークアウトの日付を取得
      final allWorkouts = await select(workouts).get();
      
      // 日付のみを抽出してSetに変換
      final dates = allWorkouts.map((workout) {
        final date = workout.date;
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

  // ④ ワークアウトを追加するメソッド
  Future<int> insertWorkout(WorkoutsCompanion workout) {
    return into(workouts).insert(workout);
  }

  // Workoutを削除するメソッド parameter: id
  Future<int> deleteWorkout(int id) {
    return (delete(workouts)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ⑤ 特定の種目の最大重量を取得するメソッド例
  Future<double?> maxWeightByName(String name) async {
    final query = customSelect(
      'SELECT MAX(weight) AS max_weight FROM workouts WHERE name = ?',
      variables: [Variable.withString(name)],
      readsFrom: {workouts},
    );
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    final maxWeight = row.data['max_weight'];
    if (maxWeight == null) return null;
    if (maxWeight is int) {
      return maxWeight.toDouble();
    } else if (maxWeight is double) {
      return maxWeight;
    } else {
      return null;
    }
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