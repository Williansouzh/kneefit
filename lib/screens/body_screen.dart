import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/stats.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'compare_screen.dart';
import 'measurements_screen.dart';
import 'photo_capture_screen.dart';

/// Peso (com tendência), medidas e fotos.
class BodyScreen extends StatelessWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('Corpo')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        _WeightChart(store: store),
        const Section('Medidas'),
        _MeasuresCard(store: store),
        Section('Fotos',
            trailing: TextButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Check-in'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoCaptureScreen())),
            )),
        _PhotosStrip(store: store),
      ]),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final Store store;
  const _WeightChart({required this.store});

  Future<void> _add(BuildContext context) async {
    final kg = await askNumber(context, 'Peso de hoje', initial: store.weights.lastOrNull?.kg);
    if (kg != null && kg > 20 && kg < 300) store.setWeight(DateTime.now(), kg);
  }

  @override
  Widget build(BuildContext context) {
    final trend = weightTrend(store.weights);
    final rate = weeklyRate(trend);
    final cs = Theme.of(context).colorScheme;
    final shown = trend.length > 90 ? trend.sublist(trend.length - 90) : trend;
    final start = shown.firstOrNull?.date;
    double x(DateTime d) => d.difference(start!).inDays.toDouble();
    final all = [for (final p in shown) ...[p.kg, p.trend]];
    final lo = all.isEmpty ? 0.0 : all.reduce((a, b) => a < b ? a : b) - .5;
    final hi = all.isEmpty ? 1.0 : all.reduce((a, b) => a > b ? a : b) + .5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tendência (média de 7 dias)', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(trend.isEmpty ? '—' : '${num1(double.parse(trend.last.trend.toStringAsFixed(1)))} kg',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                if (rate != null)
                  Text('${signedKg(rate)} por semana',
                      style: TextStyle(fontWeight: FontWeight.w800, color: rate >= 0.1 ? green : (rate < 0 ? red : amber))),
              ]),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              icon: const Icon(Icons.add),
              label: const Text('Pesar'),
              onPressed: () => _add(context),
            ),
          ]),
          if (shown.length >= 2) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(LineChartData(
                minY: lo,
                maxY: hi,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: .4), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, meta) =>
                          v == meta.min || v == meta.max ? const SizedBox() : Text(num1(v), style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (final p in shown) FlSpot(x(p.date), p.kg)],
                    barWidth: 0,
                    color: Colors.transparent,
                    dotData: FlDotData(
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3, color: cs.onSurfaceVariant.withValues(alpha: .45), strokeWidth: 0),
                    ),
                  ),
                  LineChartBarData(
                    spots: [for (final p in shown) FlSpot(x(p.date), p.trend)],
                    isCurved: true,
                    color: teal,
                    barWidth: 3.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: teal.withValues(alpha: .1)),
                  ),
                ],
              )),
            ),
            const SizedBox(height: 6),
            Text('Pontos: peso do dia · Linha: tendência real',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Pese-se todo dia (ou quase), de manhã, em jejum. A tendência aparece a partir da segunda pesagem.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          if (store.weights.isNotEmpty)
            TextButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => _WeightList(store: store),
              ),
              child: const Text('Ver pesagens'),
            ),
        ]),
      ),
    );
  }
}

class _WeightList extends StatelessWidget {
  final Store store;
  const _WeightList({required this.store});
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(shrinkWrap: true, children: [
            for (final w in store.weights.reversed)
              ListTile(
                title: Text('${num1(w.kg)} kg', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(capitalize(dayMonth.format(w.date))),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => store.removeWeight(w)),
              ),
          ]),
        ),
      );
}

class _MeasuresCard extends StatelessWidget {
  final Store store;
  const _MeasuresCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final first = store.measurements.firstOrNull, last = store.measurements.lastOrNull;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeasurementsScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: last == null
              ? const Row(children: [
                  Badge2(Icons.straighten, brand),
                  SizedBox(width: 14),
                  Expanded(child: Text('Registre as medidas junto com as fotos, a cada check-in.', style: TextStyle(fontWeight: FontWeight.w700))),
                  Icon(Icons.chevron_right),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Última: ${dayMonth.format(last.date)}${first != last ? ' · comparando com ${dayMonth.format(first!.date)}' : ''}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in last.values.entries)
                      () {
                        final diff = first == last ? null : (first!.values[e.key] == null ? null : e.value - first.values[e.key]!);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: '${e.key} ', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                            TextSpan(text: num1(e.value), style: const TextStyle(fontWeight: FontWeight.w900)),
                            if (diff != null && diff != 0)
                              TextSpan(
                                text: ' ${diff > 0 ? '+' : ''}${num1(diff)}',
                                style: TextStyle(fontWeight: FontWeight.w800, color: diff > 0 ? teal : amber),
                              ),
                          ])),
                        );
                      }(),
                  ]),
                ]),
        ),
      ),
    );
  }
}

class _PhotosStrip extends StatelessWidget {
  final Store store;
  const _PhotosStrip({required this.store});

  @override
  Widget build(BuildContext context) {
    if (store.photoSets.isEmpty) {
      return Card(
        child: Empty(
          icon: Icons.photo_camera_front_outlined,
          title: 'Sem fotos ainda',
          message: 'A cada ${store.checkInWeeks} semanas: frente, lado e costas, com a mesma pose e luz. O guia na câmera ajuda a repetir.',
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 170,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: store.photoSets.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final p = store.photoSets[store.photoSets.length - 1 - i];
            final file = p.photos[PhotoPose.front] ?? p.photos.values.first;
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoCaptureScreen(editing: p))),
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(store.media(file).path), width: 100, height: 140, fit: BoxFit.cover, cacheWidth: 300),
                ),
                const SizedBox(height: 4),
                Text(dayMonth.format(p.date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            );
          },
        ),
      ),
      if (store.photoSets.length >= 2) ...[
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.compare),
          label: const Text('Comparar antes e depois'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompareScreen())),
        ),
      ],
    ]);
  }
}
