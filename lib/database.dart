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

// ② データベースクラス定義
@DriftDatabase(tables: [Workouts])
class AppDatabase extends _$AppDatabase {
  // データベースファイルを開く処理を呼び出して初期化
  AppDatabase() : super(_openConnection());

  // スキーマバージョン（DBのバージョン管理用）
  @override
  int get schemaVersion => 1;

  // ③ 全ワークアウトデータを取得するメソッド
  Future<List<Workout>> getAllWorkouts() {
    return (select(workouts)
          ..orderBy(
            [(w) => OrderingTerm.desc(w.date)], // 日付降順で並べる
          ))
        .get();
  }

  // 🎯 修正版：ワークアウトがある日付のみを取得（null安全）
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
    for (final workout in result) { grouped.putIfAbsent(workout.name, () => []).add(workout); }
    return grouped;
  }

  // ④ ワークアウトを追加するメソッド
  Future<int> insertWorkout(WorkoutsCompanion workout) {
    return into(workouts).insert(workout);
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
