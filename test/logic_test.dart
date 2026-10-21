import 'dart:io';

import 'package:fitknee/logic/knee.dart';
import 'package:fitknee/logic/progression.dart';
import 'package:fitknee/logic/stats.dart';
import 'package:fitknee/models.dart';
import 'package:fitknee/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final legPress = Exercise(id: 'lp', name: 'Leg press', sets: 3, repMin: 10, repMax: 12, rir: 2, knee: true, increment: 5);
final row = Exercise(id: 'row', name: 'Remada', sets: 3, repMin: 8, repMax: 12, rir: 2, increment: 2.5);
var _day = DateTime(2026, 10, 1);

/// Sessão terminada com as séries dadas como (carga, reps, rir) e o semáforo dos dois joelhos.
Session session(Pain? pain, {Map<Exercise, List<(double, int, int)>> sets = const {}, Pain? right}) {
  _day = _day.add(const Duration(days: 2));
  return Session(
    dayId: 'a',
    dayName: 'A',
    date: _day,
    finished: true,
    painLeft: pain,
    painRight: right ?? pain,
    exercises: [
      for (final e in sets.entries)
        ExerciseLog(
          exerciseId: e.key.id,
          name: e.key.name,
          knee: e.key.knee,
          sets: [for (final (w, r, rir) in e.value) SetLog(weight: w, reps: r, rir: rir, done: true)],
        ),
    ],
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => _day = DateTime(2026, 10, 1));
  final rules = KneeRules();

  group('semáforo do joelho', () {
    KneePhase phaseAfter(List<Pain> pains) => kneeStatus([for (final p in pains) session(p)], rules).phase;

    test('verde mantém liberado; amarelo pede atenção e um verde libera de novo', () {
      expect(phaseAfter([Pain.green, Pain.green]), KneePhase.normal);
      expect(phaseAfter([Pain.yellow]), KneePhase.caution);
      expect(phaseAfter([Pain.yellow, Pain.green]), KneePhase.normal);
    });

    test('dois amarelos seguidos vão para o retorno fase 2', () {
      expect(phaseAfter([Pain.yellow, Pain.yellow]), KneePhase.return2);
    });

    test('vermelho ativa o retorno e cada 2 verdes seguidos avançam uma fase', () {
      expect(phaseAfter([Pain.red]), KneePhase.return1);
      expect(phaseAfter([Pain.red, Pain.green]), KneePhase.return1);
      expect(phaseAfter([Pain.red, Pain.green, Pain.green]), KneePhase.return2);
      expect(phaseAfter([Pain.red, Pain.green, Pain.green, Pain.yellow, Pain.green]), KneePhase.return2);
      expect(phaseAfter([Pain.red, ...List.filled(6, Pain.green)]), KneePhase.normal);
    });

    test('o pior joelho manda e dois vermelhos seguidos sugerem fisioterapeuta', () {
      final s = kneeStatus([session(Pain.green, right: Pain.red)], rules);
      expect(s.phase, KneePhase.return1);
      expect(s.seePhysio, isFalse);
      expect(kneeStatus([session(Pain.red), session(Pain.red)], rules).seePhysio, isTrue);
    });
  });

  group('sugestão de carga', () {
    test('bateu o topo das reps com RIR da meta: sobe o incremento', () {
      final h = [session(Pain.green, sets: {row: [(50, 12, 2), (50, 12, 2), (50, 12, 3)]})];
      final s = suggest(row, h, kneeStatus(h, rules));
      expect(s.weight, 52.5);
      expect(s.up, isTrue);
    });

    test('não bateu (ou passou do esforço): mantém a carga', () {
      final h = [session(Pain.green, sets: {row: [(50, 12, 2), (50, 12, 1), (50, 10, 2)]})];
      expect(suggest(row, h, kneeStatus(h, rules)).weight, 50);
    });

    test('joelho em retorno usa a última carga sem dor, sem acumular a redução', () {
      final h = [
        session(Pain.green, sets: {legPress: [(100, 12, 2), (100, 12, 2), (100, 12, 2)]}),
        session(Pain.red, sets: {legPress: [(100, 10, 2)]}),
        session(Pain.green, sets: {legPress: [(50, 12, 3)]}),
      ];
      final knee = kneeStatus(h, rules);
      expect(knee.phase, KneePhase.return1);
      final s = suggest(legPress, h, knee);
      expect(s.weight, 50); // 50% de 100, não 50% de 50
      expect(s.reduced, isTrue);
      // Exercício que não carrega o joelho não muda.
      expect(suggest(row, [...h, session(Pain.green, sets: {row: [(40, 10, 2)]})], knee).weight, 40);
    });
  });

  group('peso', () {
    test('média móvel de 7 dias e ganho por semana', () {
      final entries = [
        for (var i = 0; i < 15; i++) WeightEntry(DateTime(2026, 10, 1).add(Duration(days: i)), 60 + i * 0.05 + (i.isEven ? .4 : -.4)),
      ];
      final t = weightTrend(entries);
      expect(t.first.trend, entries.first.kg);
      // A tendência oscila bem menos que o número do dia.
      expect((t[10].trend - t[9].trend).abs(), lessThan(.2));
      expect(weeklyRate(t), closeTo(.35, .15)); // sobra um resíduo da oscilação de ±0,4 kg
    });

    test('sem histórico suficiente não chuta ritmo', () {
      expect(weeklyRate(weightTrend([WeightEntry(DateTime(2026, 10, 1), 60)])), isNull);
    });
  });

  test('resumo semanal traz treinos, cargas, joelho, refeições e peso', () {
    final monday = DateTime(2026, 10, 12);
    final s1 = Session(
      dayId: 'a', dayName: 'A — Pernas', date: DateTime(2026, 10, 5), finished: true, painLeft: Pain.green, painRight: Pain.green,
      exercises: [ExerciseLog(exerciseId: 'lp', name: 'Leg press', knee: true, sets: [SetLog(weight: 100, reps: 12, done: true)])],
    );
    final s2 = Session(
      dayId: 'a', dayName: 'A — Pernas', date: DateTime(2026, 10, 13), finished: true, painLeft: Pain.yellow, painRight: Pain.green,
      note: 'Escada doeu',
      exercises: [ExerciseLog(exerciseId: 'lp', name: 'Leg press', knee: true, sets: [SetLog(weight: 105, reps: 12, done: true)])],
    );
    final meals = [Meal(id: 'm1', name: 'Almoço', hour: 12, minute: 0), Meal(id: 'm2', name: 'Shake', hour: 16, minute: 0)];
    final text = weeklyReport(
      start: monday,
      plan: [WorkoutDay(name: 'A', weekdays: [1, 4], exercises: [])],
      sessions: [s1, s2],
      knee: kneeStatus([s1, s2], rules),
      meals: meals,
      mealChecks: {'2026-10-12': ['m1', 'm2'], '2026-10-13': ['m1']},
      weights: [WeightEntry(DateTime(2026, 10, 12), 61), WeightEntry(DateTime(2026, 10, 14), 61.4)],
      measurements: const [],
      videos: const [],
    );
    expect(text, contains('Treinos: 1 de 2 planejados'));
    expect(text, contains('Leg press: 1× 12 @ 105 kg (↑ de 100 kg)'));
    expect(text, contains('joelho E 🟡 D 🟢'));
    expect(text, contains('Nota: Escada doeu'));
    expect(text, contains('Atenção: carga reduzida'));
    expect(text, contains('Refeições: 21% (3 de 14)'));
    expect(text, contains('Shake 1/7'));
    expect(text, contains('61,2 kg'));
  });

  test('dados sobrevivem a fechar e abrir o app, e o backup restaura', () async {
    final dir = await Directory.systemTemp.createTemp('fitknee');
    addTearDown(() => dir.delete(recursive: true));
    final store = Store(dir);
    await store.load();
    expect(store.plan, hasLength(4)); // ficha inicial
    expect(store.meals, isNotEmpty);
    final day = store.plan.first;
    final s = store.startSession(day);
    expect(s.exercises, hasLength(day.exercises.length));
    s.exercises.first.sets.first.done = true;
    store.finishSession(s, left: Pain.yellow, right: Pain.green, note: 'ok');
    store.setWeight(DateTime(2026, 10, 20), 62.3);
    await store.flush();
    final backup = File('${dir.path}/fitknee.json').readAsStringSync();

    final reopened = Store(dir);
    await reopened.load();
    expect(reopened.sessions.single.painLeft, Pain.yellow);
    expect(reopened.knee.phase, KneePhase.caution);
    expect(reopened.weights.single.kg, 62.3);

    reopened.sessions.clear();
    await reopened.restore(backup);
    expect(reopened.sessions, hasLength(1));
    expect(() => reopened.restore('{"x":1}'), throwsFormatException);
  });
}
