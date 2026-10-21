import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/progression.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Progressão real de um exercício: maior carga de cada sessão no gráfico e as séries feitas.
class ExerciseProgressScreen extends StatelessWidget {
  final Exercise exercise;
  const ExerciseProgressScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final history = exerciseHistory(store.sessions, exercise.id);
    final points = history.reversed.toList();
    final cs = Theme.of(context).colorScheme;
    final metric = exercise.seconds || points.every((p) => p.$2.topWeight == 0);
    double value((Session, ExerciseLog) p) =>
        metric ? p.$2.done.fold<int>(0, (m, s) => s.reps > m ? s.reps : m).toDouble() : p.$2.topWeight;
    final best = points.isEmpty ? null : points.map(value).reduce((a, b) => a > b ? a : b);
    final unit = exercise.seconds ? 's' : (metric ? ' reps' : ' kg');

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
      body: points.isEmpty
          ? const Empty(icon: Icons.show_chart, title: 'Sem registros', message: 'Faça este exercício num treino para ver a evolução.')
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              Row(children: [
                _Stat('Recorde', '${num1(best!)}$unit', green),
                const SizedBox(width: 10),
                _Stat('Primeira vez', '${num1(value(points.first))}$unit', cs.onSurfaceVariant),
                const SizedBox(width: 10),
                _Stat('Sessões', '${points.length}', brand),
              ]),
              const SizedBox(height: 14),
              if (points.length > 1)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
                    child: SizedBox(
                      height: 200,
                      child: LineChart(LineChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          bottomTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (v, _) => Text(num1(v), style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [for (final (i, p) in points.indexed) FlSpot(i.toDouble(), value(p))],
                            color: brand,
                            barWidth: 3,
                            isCurved: false,
                            belowBarData: BarAreaData(show: true, color: brand.withValues(alpha: .12)),
                            dotData: FlDotData(
                              getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
                                radius: 4,
                                color: points[i].$2.knee && points[i].$1.worstPain != null ? painColor(points[i].$1.worstPain!) : brand,
                                strokeWidth: 0,
                              ),
                            ),
                          ),
                        ],
                      )),
                    ),
                  ),
                ),
              const Section('Sessões'),
              for (final (s, e) in history)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(capitalize(dayMonth.format(s.date)), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(e.done.map((x) => '${x.weight == 0 ? '' : '${num1(x.weight)}×'}${x.reps}${e.seconds ? 's' : ''}').join('  ·  ')),
                    trailing: e.knee ? Text('${s.painLeft?.emoji ?? ''}${s.painRight?.emoji ?? ''}') : null,
                  ),
                ),
            ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      );
}
