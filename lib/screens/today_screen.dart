import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/knee.dart';
import '../logic/stats.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'photo_capture_screen.dart';
import 'report_screen.dart';
import 'session_screen.dart';
import 'settings_screen.dart';

/// Painel do dia: joelho, treino de hoje, refeições, peso e check-in de fotos.
class TodayScreen extends StatelessWidget {
  final ValueChanged<int> onTab;
  const TodayScreen({super.key, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final now = DateTime.now();
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: ListView(padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 24), children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(capitalize(weekdayDay.format(now)),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
              const Text('Bora, sem pular etapa.', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.15)),
            ]),
          ),
          IconButton.filledTonal(
            tooltip: 'Resumo da semana',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ]),
        const SizedBox(height: 18),
        _KneeCard(status: store.knee),
        const SizedBox(height: 12),
        _WorkoutCard(store: store),
        const Section('Refeições de hoje'),
        _MealsCard(store: store, day: now),
        const Section('Peso'),
        _WeightCard(store: store, onOpen: () => onTab(2)),
        if ((store.daysToCheckIn ?? 0) <= 3) ...[
          const SizedBox(height: 12),
          _CheckInCard(days: store.daysToCheckIn),
        ],
      ]),
    );
  }
}

class _KneeCard extends StatelessWidget {
  final KneeStatus status;
  const _KneeCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = painColor(status.light);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.withValues(alpha: .4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(status.light.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(child: Text(status.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
          if (status.inReturn)
            Row(children: [
              for (var i = 0; i < status.rules.greensToAdvance; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(i < status.greens ? Icons.circle : Icons.circle_outlined, size: 12, color: green),
                ),
            ]),
        ]),
        const SizedBox(height: 6),
        Text(status.advice, style: const TextStyle(height: 1.35)),
        if (status.seePhysio) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: red.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
            child: const Text('⚠️ Dor forte em sessões seguidas. Pare os exercícios que doem e fale com o fisioterapeuta.',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Store store;
  const _WorkoutCard({required this.store});

  void _open(BuildContext context, Session s) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => SessionScreen(session: s)));

  @override
  Widget build(BuildContext context) {
    final active = store.activeSession;
    final today = store.dayFor(DateTime.now());
    final day = today ?? store.nextDay;
    final done = store.trainedOn(DateTime.now());
    final cs = Theme.of(context).colorScheme;

    final (String eyebrow, String title, String? action) = switch (null) {
      _ when active != null => ('Em andamento', active.dayName, 'Continuar treino'),
      _ when done => ('Treino de hoje', 'Feito ✅', null),
      _ when day == null => ('Ficha vazia', 'Monte sua ficha em Treino', null),
      _ when today != null => ('Treino de hoje', today.name, 'Começar treino'),
      _ => ('Hoje é descanso', 'Próximo: ${day.name}', 'Treinar mesmo assim'),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF23262E), Color(0xFF111318)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(eyebrow.toUpperCase(),
            style: const TextStyle(color: brand, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        if (day != null && active == null && !done) ...[
          const SizedBox(height: 6),
          Text(
            '${day.exercises.length} exercícios · ${day.exercises.where((e) => e.knee).length} de joelho',
            style: TextStyle(color: Colors.white.withValues(alpha: .7)),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: Icon(active != null ? Icons.play_arrow : Icons.bolt),
            label: Text(action),
            onPressed: () => _open(context, active ?? store.startSession(day!)),
          ),
        ] else if (done)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Agora é comer e dormir bem.', style: TextStyle(color: cs.inversePrimary)),
          ),
      ]),
    );
  }
}

class _MealsCard extends StatelessWidget {
  final Store store;
  final DateTime day;
  const _MealsCard({required this.store, required this.day});

  @override
  Widget build(BuildContext context) {
    final checks = store.checksOn(day);
    final nowMin = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
    final cs = Theme.of(context).colorScheme;
    if (store.meals.isEmpty) {
      return const Card(child: ListTile(title: Text('Sem refeições cadastradas'), subtitle: Text('Ajustes → Refeições')));
    }
    return Card(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: checks.length / store.meals.length,
                  minHeight: 10,
                  color: teal,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${checks.length}/${store.meals.length}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        ),
        for (final m in store.meals)
          CheckboxListTile(
            value: checks.contains(m.id),
            onChanged: (_) => store.toggleMeal(day, m.id),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: teal,
            title: Text(m.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration: checks.contains(m.id) ? TextDecoration.lineThrough : null,
                )),
            subtitle: m.hint.isEmpty ? null : Text(m.hint, maxLines: 1, overflow: TextOverflow.ellipsis),
            secondary: Text(
              m.time,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: !checks.contains(m.id) && m.minutes + 60 < nowMin ? red : cs.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 6),
      ]),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final Store store;
  final VoidCallback onOpen;
  const _WeightCard({required this.store, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final trend = weightTrend(store.weights);
    final rate = weeklyRate(trend);
    final today = store.weights.where((w) => dateOnly(w.date) == dateOnly(DateTime.now())).firstOrNull;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Badge2(Icons.trending_up, teal),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trend.isEmpty ? 'Sem pesagens ainda' : 'Tendência: ${num1(trend.last.trend)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(
                  rate == null ? 'Pese-se de manhã, em jejum, depois do banheiro.' : '${signedKg(rate)} por semana',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ]),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () async {
                final kg = await askNumber(context, 'Peso de hoje', initial: today?.kg ?? store.weights.lastOrNull?.kg);
                if (kg != null && kg > 20 && kg < 300) store.setWeight(DateTime.now(), kg);
              },
              child: Text(today == null ? 'Pesar' : num1(today.kg)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final int? days;
  const _CheckInCard({required this.days});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          leading: const Badge2(Icons.photo_camera_outlined, brand),
          title: Text(
            days == null ? 'Faça o primeiro check-in de fotos' : (days! <= 0 ? 'Check-in de fotos: hoje!' : 'Check-in de fotos em $days dia(s)'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Mesma pose, mesmo lugar, mesma luz.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoCaptureScreen())),
        ),
      );
}
