import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'exercise_progress_screen.dart';
import 'plan_editor.dart';
import 'session_screen.dart';

/// Ficha da semana e histórico de treinos.
class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Treino'),
            bottom: const TabBar(tabs: [Tab(text: 'Ficha'), Tab(text: 'Histórico')]),
          ),
          body: const TabBarView(children: [_PlanTab(), _HistoryTab()]),
        ),
      );
}

class _PlanTab extends StatelessWidget {
  const _PlanTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      for (final day in store.plan) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(day.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(
                      day.weekdays.isEmpty ? 'Sem dia fixo' : ([...day.weekdays]..sort()).map((d) => weekdayShort[d]).join(' · '),
                      style: const TextStyle(color: brand, fontWeight: FontWeight.w800),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DayEditorScreen(day: day))),
                ),
              ]),
              for (final ex in day.exercises)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text('${ex.target} · RIR ${ex.rir}${ex.knee ? ' · 🦵' : ''}'),
                  trailing: Icon(Icons.show_chart, color: cs.onSurfaceVariant),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseProgressScreen(exercise: ex))),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
      ],
      OutlinedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('Novo dia de treino'),
        onPressed: () {
          final day = WorkoutDay(name: 'Novo treino', weekdays: [], exercises: []);
          store.plan.add(day);
          store.changed();
          Navigator.push(context, MaterialPageRoute(builder: (_) => DayEditorScreen(day: day)));
        },
      ),
    ]);
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final list = store.sessions.where((s) => s.finished).toList()..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) {
      return const Empty(
        icon: Icons.history,
        title: 'Nenhum treino ainda',
        message: 'Os treinos terminados aparecem aqui, com o semáforo de cada joelho.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = list[i];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            title: Text(s.dayName, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${capitalize(dayMonth.format(s.date))} · ${s.setsDone} séries · ${num1(s.volume)} kg'
                '${s.note.isEmpty ? '' : '\n${s.note}'}'),
            trailing: Text('${s.painLeft?.emoji ?? ''}${s.painRight?.emoji ?? ''}', style: const TextStyle(fontSize: 18)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionScreen(session: s))),
          ),
        );
      },
    );
  }
}
