import 'package:intl/intl.dart';

import '../models.dart';
import 'knee.dart';
import 'progression.dart';

/// Ponto da curva de peso: o do dia e a média dos últimos [window] dias (tendência).
class TrendPoint {
  final DateTime date;
  final double kg, trend;
  const TrendPoint(this.date, this.kg, this.trend);
}

/// Média móvel simples por dias de calendário: cada pesagem com a média das pesagens dos
/// [window] dias até ela. Água e comida mexem no número do dia; a média mostra o rumo.
List<TrendPoint> weightTrend(List<WeightEntry> entries, {int window = 7}) {
  final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
  return [
    for (final e in sorted)
      () {
        final from = e.date.subtract(Duration(days: window - 1));
        final win = sorted.where((x) => !x.date.isBefore(from) && !x.date.isAfter(e.date));
        return TrendPoint(e.date, e.kg, win.fold<double>(0, (s, x) => s + x.kg) / win.length);
      }(),
  ];
}

/// Variação da tendência por semana, comparando a última com a de ~7 dias antes.
/// Nulo sem histórico suficiente.
double? weeklyRate(List<TrendPoint> trend) {
  if (trend.length < 2) return null;
  final last = trend.last;
  final target = last.date.subtract(const Duration(days: 7));
  final before = trend.where((p) => !p.date.isAfter(target)).lastOrNull;
  if (before == null) {
    final first = trend.first;
    final days = last.date.difference(first.date).inDays;
    if (days < 4) return null;
    return (last.trend - first.trend) / days * 7;
  }
  final days = last.date.difference(before.date).inDays;
  return (last.trend - before.trend) / days * 7;
}

String signedKg(double v) => '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(2).replaceAll('.', ',')} kg';

/// Relatório da semana [start]..[start]+6 para mandar ao treinador, fisio ou nutricionista.
String weeklyReport({
  required DateTime start,
  required List<WorkoutDay> plan,
  required List<Session> sessions,
  required KneeStatus knee,
  required List<Meal> meals,
  required Map<String, List<String>> mealChecks,
  required List<WeightEntry> weights,
  required List<Measurement> measurements,
  required List<VideoEntry> videos,
}) {
  final end = start.add(const Duration(days: 6));
  bool inWeek(DateTime d) => !dateOnly(d).isBefore(start) && !dateOnly(d).isAfter(end);
  final df = DateFormat('dd/MM', 'pt_BR');
  final wd = DateFormat('EEE dd/MM', 'pt_BR');
  final b = StringBuffer('📋 Resumo semanal — ${df.format(start)} a ${df.format(end)}\n');

  final week = sessions.where((s) => s.finished && inWeek(s.date)).toList()..sort((a, b) => a.date.compareTo(b.date));
  final planned = plan.fold<int>(0, (n, d) => n + d.weekdays.length);
  b.writeln('\n🏋️ Treinos: ${week.length} de $planned planejados');
  for (final s in week) {
    final pain = [
      if (s.painLeft != null) 'E ${s.painLeft!.emoji}',
      if (s.painRight != null) 'D ${s.painRight!.emoji}',
    ].join(' ');
    b.writeln('• ${s.dayName} (${wd.format(s.date)})${pain.isEmpty ? '' : ' — joelho $pain'}');
    for (final e in s.exercises.where((e) => e.done.isNotEmpty)) {
      final reps = e.done.map((x) => x.reps).join('/');
      final prev = exerciseHistory(sessions.where((x) => x.date.isBefore(s.date)).toList(), e.exerciseId).firstOrNull;
      final change = prev == null || e.topWeight == 0
          ? ''
          : e.topWeight > prev.$2.topWeight
              ? ' (↑ de ${kg(prev.$2.topWeight)})'
              : e.topWeight < prev.$2.topWeight
                  ? ' (↓ de ${kg(prev.$2.topWeight)})'
                  : '';
      final load = e.topWeight == 0 ? '' : ' @ ${kg(e.topWeight)}';
      b.writeln('   ${e.name}: ${e.done.length}× $reps${e.seconds ? 's' : ''}$load$change');
    }
    if (s.note.trim().isNotEmpty) b.writeln('   Nota: ${s.note.trim()}');
  }

  b.writeln('\n🦵 Joelho: ${knee.title}. ${knee.advice}');
  if (knee.seePhysio) b.writeln('⚠️ Dor forte em sessões seguidas: vale falar com o fisioterapeuta.');

  if (meals.isNotEmpty) {
    var done = 0;
    final perMeal = {for (final m in meals) m.id: 0};
    for (var i = 0; i < 7; i++) {
      final checks = mealChecks[dayKey(start.add(Duration(days: i)))] ?? const [];
      for (final m in meals) {
        if (checks.contains(m.id)) {
          done++;
          perMeal[m.id] = perMeal[m.id]! + 1;
        }
      }
    }
    final total = meals.length * 7;
    b.writeln('\n🍽️ Refeições: ${(done * 100 / total).round()}% ($done de $total)');
    b.writeln('   ${meals.map((m) => '${m.name} ${perMeal[m.id]}/7').join(' · ')}');
  }

  final trend = weightTrend(weights);
  final weekTrend = trend.where((p) => !p.date.isAfter(end)).toList();
  if (weekTrend.isNotEmpty) {
    final rate = weeklyRate(weekTrend);
    final n = weights.where((w) => inWeek(w.date)).length;
    b.writeln('\n⚖️ Peso (média de 7 dias): ${weekTrend.last.trend.toStringAsFixed(1).replaceAll('.', ',')} kg'
        '${rate == null ? '' : ' (${signedKg(rate)}/semana)'} · $n pesagem(ns) na semana');
  }

  final m = measurements.where((x) => inWeek(x.date)).lastOrNull;
  if (m != null) {
    b.writeln('\n📏 Medidas (${df.format(m.date)}): '
        '${m.values.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(1).replaceAll('.', ',')}').join(' · ')} cm');
  }

  final v = videos.where((x) => inWeek(x.date)).length;
  if (v > 0) b.writeln('\n🎥 Diário em vídeo: $v gravação(ões)');
  return b.toString().trimRight();
}
