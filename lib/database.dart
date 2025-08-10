import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// 自動生成ファイルのpartディレクティブ
part 'database.g.dart'; // ←ここはdriftのコード生成で使うのでファイル名を間違えないこと

// ① テーブルの定義（Workoutsテーブル）
// それぞれのカラムをどう定義するかを指定
class Workouts extends Table {
  // 主キー、自動採番
  IntColumn get id => integer().autoIncrement()();

  // ワークアウトの種目名
  TextColumn get name => text()();

  // 重量(kg)
  IntColumn get weight => integer()();

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

  // ④ ワークアウトを追加するメソッド
  Future<int> insertWorkout(WorkoutsCompanion workout) {
    return into(workouts).insert(workout);
  }

  // ⑤ 特定の種目の最大重量を取得するメソッド例
  Future<int?> maxWeightByName(String name) {
    final query = customSelect(
      'SELECT MAX(weight) AS max_weight FROM workouts WHERE name = ?',
      variables: [Variable.withString(name)],
      readsFrom: {workouts},
    );
    // 結果のマップからmax_weightをintとして取得
    return query.map((row) => row.data['max_weight'] as int?).getSingleOrNull();
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
