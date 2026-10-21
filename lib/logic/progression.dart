import '../models.dart';
import 'knee.dart';

/// O que fazer no próximo treino de um exercício.
class Suggestion {
  final double? weight; // nulo: sem histórico (ou peso do corpo)
  final String text;
  final bool up, reduced;
  const Suggestion(this.weight, this.text, {this.up = false, this.reduced = false});
}

/// Registros de um exercício nas sessões terminadas, do mais recente para o mais antigo.
List<(Session, ExerciseLog)> exerciseHistory(List<Session> sessions, String exerciseId) {
  final out = [
    for (final s in sessions)
      if (s.finished)
        for (final e in s.exercises)
          if (e.exerciseId == exerciseId && e.done.isNotEmpty) (s, e),
  ];
  out.sort((a, b) => b.$1.date.compareTo(a.$1.date));
  return out;
}

double roundTo(double v, double step) => step <= 0 ? v : (v / step).round() * step;

String kg(double v) => '${v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',')} kg';

/// Progressão dupla: bateu o topo das repetições em todas as séries sem passar do esforço da meta
/// (RIR igual ou maior), sobe [Exercise.increment]. Nos exercícios de joelho, a fase do semáforo
/// aplica o multiplicador sobre a última carga feita com o joelho liberado.
Suggestion suggest(Exercise ex, List<Session> sessions, KneeStatus knee) {
  final history = exerciseHistory(sessions, ex.id);
  if (history.isEmpty) return const Suggestion(null, 'Primeira vez: comece leve e anote a carga.');
  final last = history.first.$2;

  if (ex.seconds) {
    final hit = last.done.every((s) => s.reps >= ex.repMax);
    return Suggestion(last.topWeight == 0 ? null : last.topWeight,
        hit ? 'Bateu ${ex.repMax}s em todas: tente +5s.' : 'Mantenha e tente chegar a ${ex.repMax}s.',
        up: hit);
  }

  if (ex.knee && !knee.progressing) {
    // Referência: a última sessão feita com o joelho liberado (senão a redução se acumularia).
    final ref = history.firstWhere((h) => knee.phaseAt[h.$1.id] == KneePhase.normal, orElse: () => history.first).$2;
    if (ref.topWeight == 0) return const Suggestion(null, 'Peso do corpo: só a amplitude sem dor.', reduced: true);
    // Arredonda em 2,5 kg (ou menos, se o aumento do exercício for menor): anilhas comuns.
    final w = roundTo(ref.topWeight * knee.factor, ex.increment > 0 && ex.increment < 2.5 ? ex.increment : 2.5);
    return Suggestion(w, '${KneeStatus.pct(knee.factor)} de ${kg(ref.topWeight)} (semáforo do joelho).', reduced: true);
  }

  final w = last.topWeight;
  final hit = last.done.length >= ex.sets &&
      last.done.every((s) => s.reps >= ex.repMax && s.rir >= ex.rir && s.weight >= w);
  if (w == 0) {
    return Suggestion(null, hit ? 'Bateu ${ex.repMax} reps: adicione carga ou dificuldade.' : 'Busque ${ex.repMax} reps.',
        up: hit);
  }
  if (hit) return Suggestion(w + ex.increment, 'Bateu ${ex.repMax} reps com RIR ${ex.rir}+: suba para ${kg(w + ex.increment)}.', up: true);
  return Suggestion(w, 'Mantenha ${kg(w)} e busque ${ex.repMax} reps em todas as séries.');
}
