import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'defaults.dart';
import 'logic/knee.dart';
import 'logic/progression.dart';
import 'models.dart';

/// Todos os dados do app, num JSON na pasta do app. Fotos e vídeos ficam em [mediaDir]
/// e o JSON guarda só o nome do arquivo. Nada sai do celular, a não ser pelo backup ou pelo resumo.
class Store extends ChangeNotifier {
  final Directory dir;
  Store(this.dir);

  File get _file => File('${dir.path}/fitknee.json');
  Directory get mediaDir => Directory('${dir.path}/media');
  File media(String name) => File('${mediaDir.path}/$name');

  List<WorkoutDay> plan = [];
  List<Session> sessions = [];
  KneeRules rules = KneeRules();
  List<Meal> meals = [];
  Map<String, List<String>> mealChecks = {};
  List<WeightEntry> weights = [];
  List<Measurement> measurements = [];
  List<String> measureNames = [...defaultMeasures];
  List<PhotoSet> photoSets = [];
  List<VideoEntry> videos = [];
  int checkInWeeks = 4;

  Future<void> load() async {
    await mediaDir.create(recursive: true);
    if (!await _file.exists()) {
      plan = defaultPlan();
      meals = defaultMeals();
      await _write();
      return;
    }
    _read(jsonDecode(await _file.readAsString()) as Map<String, dynamic>);
  }

  /// Restaura um backup (o JSON de [toJson]). Fotos e vídeos não vão no backup: os que não
  /// existirem neste celular somem da lista.
  Future<void> restore(String json) async {
    final j = jsonDecode(json);
    if (j is! Map<String, dynamic> || j['version'] != 1 || j['plan'] is! List) {
      throw const FormatException('Este arquivo não é um backup do FitKnee.');
    }
    _read(j);
    photoSets.removeWhere((p) => p.photos.values.any((f) => !media(f).existsSync()));
    videos.removeWhere((v) => !media(v.file).existsSync());
    await _write();
    notifyListeners();
  }

  void _read(Map<String, dynamic> j) {
    plan = [for (final d in j['plan'] ?? []) WorkoutDay.fromJson(d)];
    sessions = [for (final s in j['sessions'] ?? []) Session.fromJson(s)];
    rules = KneeRules.fromJson(j['rules'] ?? {});
    meals = [for (final m in j['meals'] ?? []) Meal.fromJson(m)];
    mealChecks = {
      for (final e in ((j['mealChecks'] ?? {}) as Map).entries) e.key as String: [for (final id in e.value) id as String],
    };
    weights = [for (final w in j['weights'] ?? []) WeightEntry.fromJson(w)];
    measurements = [for (final m in j['measurements'] ?? []) Measurement.fromJson(m)];
    measureNames = [for (final n in j['measureNames'] ?? defaultMeasures) n as String];
    photoSets = [for (final p in j['photoSets'] ?? []) PhotoSet.fromJson(p)];
    videos = [for (final v in j['videos'] ?? []) VideoEntry.fromJson(v)];
    checkInWeeks = j['checkInWeeks'] ?? 4;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'plan': [for (final d in plan) d.toJson()],
        'sessions': [for (final s in sessions) s.toJson()],
        'rules': rules.toJson(),
        'meals': [for (final m in meals) m.toJson()],
        'mealChecks': mealChecks,
        'weights': [for (final w in weights) w.toJson()],
        'measurements': [for (final m in measurements) m.toJson()],
        'measureNames': measureNames,
        'photoSets': [for (final p in photoSets) p.toJson()],
        'videos': [for (final v in videos) v.toJson()],
        'checkInWeeks': checkInWeeks,
      };

  /// Grava num temporário e troca, para um fechamento no meio não corromper o arquivo.
  Future<void> _write() async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    await tmp.rename(_file.path);
  }

  Future<void>? _pending;
  Future<void> _saving = Future.value();

  /// Salva logo depois da mudança (agrupando as que vêm juntas) e avisa as telas.
  void changed() {
    notifyListeners();
    _pending ??= Future(() {
      _pending = null;
      _saving = _saving.then((_) => _write());
    });
  }

  /// Espera a gravação em andamento (testes e antes de exportar).
  Future<void> flush() async {
    await _pending;
    await _saving;
  }

  // ---------- Treino ----------

  KneeStatus get knee => kneeStatus(sessions, rules);

  Session? get activeSession => sessions.where((s) => !s.finished).firstOrNull;

  /// Treino do dia da semana; se não houver, o próximo da ficha depois do último feito.
  WorkoutDay? dayFor(DateTime date) => plan.where((d) => d.weekdays.contains(date.weekday)).firstOrNull;

  WorkoutDay? get nextDay {
    if (plan.isEmpty) return null;
    final today = dayFor(DateTime.now());
    if (today != null) return today;
    final last = (sessions.where((s) => s.finished).toList()..sort((a, b) => a.date.compareTo(b.date))).lastOrNull;
    final i = last == null ? -1 : plan.indexWhere((d) => d.id == last.dayId);
    return plan[(i + 1) % plan.length];
  }

  bool trainedOn(DateTime day) => sessions.any((s) => s.finished && dateOnly(s.date) == dateOnly(day));

  /// Começa uma sessão já com as cargas sugeridas em cada série.
  Session startSession(WorkoutDay day) {
    final k = knee;
    final s = Session(dayId: day.id, dayName: day.name, date: DateTime.now(), exercises: [
      for (final ex in day.exercises)
        () {
          final sug = suggest(ex, sessions, k);
          return ExerciseLog(
            exerciseId: ex.id,
            name: ex.name,
            knee: ex.knee,
            seconds: ex.seconds,
            repMax: ex.repMax,
            rir: ex.rir,
            sets: [for (var i = 0; i < ex.sets; i++) SetLog(weight: sug.weight ?? 0, reps: ex.repMax, rir: ex.rir)],
          );
        }(),
    ]);
    sessions.add(s);
    changed();
    return s;
  }

  void finishSession(Session s, {required Pain left, required Pain right, String note = ''}) {
    s
      ..painLeft = left
      ..painRight = right
      ..note = note
      ..finished = true;
    changed();
  }

  void deleteSession(Session s) {
    sessions.remove(s);
    changed();
  }

  Exercise? exercise(String id) =>
      plan.expand((d) => d.exercises).where((e) => e.id == id).firstOrNull;

  // ---------- Refeições ----------

  List<String> checksOn(DateTime day) => mealChecks[dayKey(day)] ?? const [];

  void toggleMeal(DateTime day, String mealId) {
    final list = [...checksOn(day)];
    list.contains(mealId) ? list.remove(mealId) : list.add(mealId);
    mealChecks[dayKey(day)] = list;
    changed();
  }

  // ---------- Corpo ----------

  void setWeight(DateTime day, double kg) {
    weights.removeWhere((w) => dateOnly(w.date) == dateOnly(day));
    weights.add(WeightEntry(dateOnly(day), kg));
    weights.sort((a, b) => a.date.compareTo(b.date));
    changed();
  }

  void removeWeight(WeightEntry w) {
    weights.remove(w);
    changed();
  }

  void setMeasurement(Measurement m) {
    measurements.removeWhere((x) => dateOnly(x.date) == dateOnly(m.date));
    measurements.add(m);
    measurements.sort((a, b) => a.date.compareTo(b.date));
    changed();
  }

  void addPhotoSet(PhotoSet p) {
    photoSets.removeWhere((x) => x.id == p.id);
    photoSets.add(p);
    photoSets.sort((a, b) => a.date.compareTo(b.date));
    changed();
  }

  Future<void> deletePhotoSet(PhotoSet p) async {
    photoSets.remove(p);
    for (final f in p.photos.values) {
      final file = media(f);
      if (await file.exists()) await file.delete();
    }
    changed();
  }

  /// Dias até o próximo check-in de fotos (negativo: atrasado). Nulo se nunca fez.
  int? get daysToCheckIn {
    final last = photoSets.lastOrNull;
    if (last == null) return null;
    return last.date.add(Duration(days: 7 * checkInWeeks)).difference(dateOnly(DateTime.now())).inDays;
  }

  // ---------- Diário em vídeo ----------

  void addVideo(VideoEntry v) {
    videos.add(v);
    videos.sort((a, b) => b.date.compareTo(a.date));
    changed();
  }

  Future<void> deleteVideo(VideoEntry v) async {
    videos.remove(v);
    final file = media(v.file);
    if (await file.exists()) await file.delete();
    changed();
  }
}
