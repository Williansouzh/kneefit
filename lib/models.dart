import 'package:intl/intl.dart';

/// Dia no formato "2026-10-21" (chave de registros diários).
String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime parseDay(String s) => DateTime.parse(s);
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Semáforo de dor de um joelho depois do treino.
enum Pain { green, yellow, red }

extension PainLabel on Pain {
  String get emoji => const ['🟢', '🟡', '🔴'][index];
  String get label => const ['Sem dor', 'Incômodo', 'Dor'][index];
}

/// Exercício da ficha. [knee]: carrega o joelho, então segue o semáforo de dor.
/// [seconds]: a meta é tempo (isometria), não repetições.
class Exercise {
  String id, name, group, notes;
  int sets, repMin, repMax, rir, restSeconds;
  bool knee, seconds;
  double increment;

  Exercise({
    String? id,
    required this.name,
    this.group = '',
    this.notes = '',
    this.sets = 3,
    this.repMin = 8,
    this.repMax = 12,
    this.rir = 2,
    this.restSeconds = 90,
    this.knee = false,
    this.seconds = false,
    this.increment = 2.5,
  }) : id = id ?? newId();

  String get target => '$sets × ${repMin == repMax ? '$repMin' : '$repMin–$repMax'}${seconds ? 's' : ''}';

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'group': group, 'notes': notes, 'sets': sets, 'repMin': repMin,
        'repMax': repMax, 'rir': rir, 'restSeconds': restSeconds, 'knee': knee, 'seconds': seconds,
        'increment': increment,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'],
        name: j['name'],
        group: j['group'] ?? '',
        notes: j['notes'] ?? '',
        sets: j['sets'] ?? 3,
        repMin: j['repMin'] ?? 8,
        repMax: j['repMax'] ?? 12,
        rir: j['rir'] ?? 2,
        restSeconds: j['restSeconds'] ?? 90,
        knee: j['knee'] ?? false,
        seconds: j['seconds'] ?? false,
        increment: _d(j['increment'] ?? 2.5),
      );
}

/// Treino da ficha (ex.: "A — Pernas"), feito nos [weekdays] (1 = segunda ... 7 = domingo).
class WorkoutDay {
  String id, name;
  List<int> weekdays;
  List<Exercise> exercises;

  WorkoutDay({String? id, required this.name, required this.weekdays, required this.exercises}) : id = id ?? newId();

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'weekdays': weekdays, 'exercises': [for (final e in exercises) e.toJson()]};

  factory WorkoutDay.fromJson(Map<String, dynamic> j) => WorkoutDay(
        id: j['id'],
        name: j['name'],
        weekdays: [for (final d in j['weekdays'] ?? []) d as int],
        exercises: [for (final e in j['exercises'] ?? []) Exercise.fromJson(e)],
      );
}

class SetLog {
  double weight;
  int reps, rir;
  bool done;
  SetLog({this.weight = 0, this.reps = 0, this.rir = 2, this.done = false});

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps, 'rir': rir, 'done': done};
  factory SetLog.fromJson(Map<String, dynamic> j) =>
      SetLog(weight: _d(j['weight']), reps: j['reps'] ?? 0, rir: j['rir'] ?? 2, done: j['done'] ?? false);
}

/// Exercício registrado numa sessão. Guarda nome e flags para o histórico não mudar se a ficha mudar.
class ExerciseLog {
  String exerciseId, name;
  bool knee, seconds;
  int repMax, rir;
  List<SetLog> sets;

  ExerciseLog({
    required this.exerciseId,
    required this.name,
    required this.sets,
    this.knee = false,
    this.seconds = false,
    this.repMax = 12,
    this.rir = 2,
  });

  List<SetLog> get done => sets.where((s) => s.done).toList();
  double get topWeight => done.fold(0, (m, s) => s.weight > m ? s.weight : m);
  double get volume => done.fold(0, (v, s) => v + s.weight * s.reps);

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId, 'name': name, 'knee': knee, 'seconds': seconds, 'repMax': repMax, 'rir': rir,
        'sets': [for (final s in sets) s.toJson()],
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['exerciseId'],
        name: j['name'],
        knee: j['knee'] ?? false,
        seconds: j['seconds'] ?? false,
        repMax: j['repMax'] ?? 12,
        rir: j['rir'] ?? 2,
        sets: [for (final s in j['sets'] ?? []) SetLog.fromJson(s)],
      );
}

/// Um treino feito. Dor é registrada ao terminar ([painLeft]/[painRight]).
class Session {
  String id, dayId, dayName, note;
  DateTime date;
  List<ExerciseLog> exercises;
  Pain? painLeft, painRight;
  bool finished;

  Session({
    String? id,
    required this.dayId,
    required this.dayName,
    required this.date,
    required this.exercises,
    this.note = '',
    this.painLeft,
    this.painRight,
    this.finished = false,
  }) : id = id ?? newId();

  /// O pior dos dois joelhos manda.
  Pain? get worstPain => switch ((painLeft, painRight)) {
        (null, null) => null,
        (final l, null) => l,
        (null, final r) => r,
        (final l?, final r?) => l.index >= r.index ? l : r,
      };

  int get setsDone => exercises.fold(0, (n, e) => n + e.done.length);
  double get volume => exercises.fold(0, (v, e) => v + e.volume);

  Map<String, dynamic> toJson() => {
        'id': id, 'dayId': dayId, 'dayName': dayName, 'date': date.toIso8601String(), 'note': note,
        'painLeft': painLeft?.index, 'painRight': painRight?.index, 'finished': finished,
        'exercises': [for (final e in exercises) e.toJson()],
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'],
        dayId: j['dayId'],
        dayName: j['dayName'] ?? '',
        date: DateTime.parse(j['date']),
        note: j['note'] ?? '',
        painLeft: j['painLeft'] == null ? null : Pain.values[j['painLeft']],
        painRight: j['painRight'] == null ? null : Pain.values[j['painRight']],
        finished: j['finished'] ?? false,
        exercises: [for (final e in j['exercises'] ?? []) ExerciseLog.fromJson(e)],
      );
}

/// Regras do semáforo (editáveis). Multiplicadores sobre a última carga boa dos exercícios de joelho.
class KneeRules {
  double cautionFactor, return1Factor, return2Factor, return3Factor;
  int greensToAdvance;

  KneeRules({
    this.cautionFactor = 0.85,
    this.return1Factor = 0.5,
    this.return2Factor = 0.7,
    this.return3Factor = 0.85,
    this.greensToAdvance = 2,
  });

  Map<String, dynamic> toJson() => {
        'cautionFactor': cautionFactor, 'return1Factor': return1Factor, 'return2Factor': return2Factor,
        'return3Factor': return3Factor, 'greensToAdvance': greensToAdvance,
      };

  factory KneeRules.fromJson(Map<String, dynamic> j) => KneeRules(
        cautionFactor: _d(j['cautionFactor'] ?? 0.85),
        return1Factor: _d(j['return1Factor'] ?? 0.5),
        return2Factor: _d(j['return2Factor'] ?? 0.7),
        return3Factor: _d(j['return3Factor'] ?? 0.85),
        greensToAdvance: j['greensToAdvance'] ?? 2,
      );
}

/// Refeição com horário fixo para o alarme.
class Meal {
  String id, name, hint;
  int hour, minute;
  bool alarm;

  Meal({String? id, required this.name, this.hint = '', required this.hour, required this.minute, this.alarm = true})
      : id = id ?? newId();

  String get time => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  int get minutes => hour * 60 + minute;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hint': hint, 'hour': hour, 'minute': minute, 'alarm': alarm};
  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: j['id'],
        name: j['name'],
        hint: j['hint'] ?? '',
        hour: j['hour'],
        minute: j['minute'],
        alarm: j['alarm'] ?? true,
      );
}

class WeightEntry {
  DateTime date;
  double kg;
  WeightEntry(this.date, this.kg);
  Map<String, dynamic> toJson() => {'date': dayKey(date), 'kg': kg};
  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(parseDay(j['date']), _d(j['kg']));
}

/// Medidas em cm, por nome ("Braço D", "Coxa E"...).
class Measurement {
  DateTime date;
  Map<String, double> values;
  Measurement(this.date, this.values);
  Map<String, dynamic> toJson() => {'date': dayKey(date), 'values': values};
  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        parseDay(j['date']),
        {for (final e in (j['values'] as Map).entries) e.key as String: _d(e.value)},
      );
}

enum PhotoPose { front, side, back }

extension PoseLabel on PhotoPose {
  String get label => const ['Frente', 'Lado', 'Costas'][index];
}

/// Fotos de um check-in (caminho relativo à pasta do app, por pose).
class PhotoSet {
  String id;
  DateTime date;
  Map<PhotoPose, String> photos;
  PhotoSet({String? id, required this.date, required this.photos}) : id = id ?? newId();

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': dayKey(date), 'photos': {for (final e in photos.entries) e.key.name: e.value}};
  factory PhotoSet.fromJson(Map<String, dynamic> j) => PhotoSet(
        id: j['id'],
        date: parseDay(j['date']),
        photos: {for (final e in (j['photos'] as Map).entries) PhotoPose.values.byName(e.key): e.value as String},
      );
}

class VideoEntry {
  String id, file, title;
  DateTime date;
  int seconds;
  VideoEntry({String? id, required this.file, required this.date, this.title = '', this.seconds = 0}) : id = id ?? newId();

  Map<String, dynamic> toJson() =>
      {'id': id, 'file': file, 'date': date.toIso8601String(), 'title': title, 'seconds': seconds};
  factory VideoEntry.fromJson(Map<String, dynamic> j) => VideoEntry(
        id: j['id'],
        file: j['file'],
        date: DateTime.parse(j['date']),
        title: j['title'] ?? '',
        seconds: j['seconds'] ?? 0,
      );
}
