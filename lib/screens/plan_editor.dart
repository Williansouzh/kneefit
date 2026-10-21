import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Edita um dia da ficha: nome, dias da semana e exercícios (arraste para reordenar).
class DayEditorScreen extends StatefulWidget {
  final WorkoutDay day;
  const DayEditorScreen({super.key, required this.day});
  @override
  State<DayEditorScreen> createState() => _DayEditorScreenState();
}

class _DayEditorScreenState extends State<DayEditorScreen> {
  late final _name = TextEditingController(text: widget.day.name);
  WorkoutDay get day => widget.day;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _changed() {
    context.read<Store>().changed();
    setState(() {});
  }

  Future<void> _edit([Exercise? ex]) async {
    final result = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExerciseEditor(exercise: ex),
    );
    if (result == null) return;
    if (ex == null) day.exercises.add(result);
    _changed();
  }

  Future<void> _deleteDay() async {
    if (!await confirm(context, 'Excluir "${day.name}"?', 'O histórico dos treinos feitos continua salvo.')) return;
    if (!mounted) return;
    final store = context.read<Store>();
    store.plan.remove(day);
    store.changed();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar treino', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        actions: [IconButton(tooltip: 'Excluir dia', icon: const Icon(Icons.delete_outline), onPressed: _deleteDay)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Exercício'),
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + pad), children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nome', hintText: 'A — Pernas'),
          onChanged: (v) {
            day.name = v.trim().isEmpty ? 'Treino' : v.trim();
            context.read<Store>().changed();
          },
        ),
        const Section('Dias da semana'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              label: Text(weekdayShort[d]),
              selected: day.weekdays.contains(d),
              onSelected: (on) {
                on ? day.weekdays.add(d) : day.weekdays.remove(d);
                _changed();
              },
            ),
        ]),
        const Section('Exercícios'),
        if (day.exercises.isEmpty) const Text('Toque em "Exercício" para adicionar.'),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (a, b) {
            day.exercises.insert(b, day.exercises.removeAt(a));
            _changed();
          },
          children: [
            for (final (i, ex) in day.exercises.indexed)
              Card(
                key: ValueKey(ex.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
                  title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${ex.target} · RIR ${ex.rir}${ex.knee ? ' · 🦵 joelho' : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      if (!await confirm(context, 'Tirar "${ex.name}" da ficha?', 'O histórico dele continua salvo.', ok: 'Tirar')) return;
                      day.exercises.remove(ex);
                      _changed();
                    },
                  ),
                  onTap: () => _edit(ex),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

/// Folha para criar ou editar um exercício. Devolve o exercício (o mesmo objeto, se editando).
class ExerciseEditor extends StatefulWidget {
  final Exercise? exercise;
  const ExerciseEditor({super.key, this.exercise});
  @override
  State<ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<ExerciseEditor> {
  late final Exercise e = widget.exercise ?? Exercise(name: '');
  late final _name = TextEditingController(text: e.name);
  late final _notes = TextEditingController(text: e.notes);
  late int _sets = e.sets, _min = e.repMin, _max = e.repMax, _rir = e.rir, _rest = e.restSeconds;
  late double _inc = e.increment;
  late bool _knee = e.knee, _seconds = e.seconds;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Widget _stepper(String label, int value, ValueChanged<int> set, {int step = 1, int min = 0, String suffix = ''}) => Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton.filledTonal(onPressed: value - step < min ? null : () => setState(() => set(value - step)), icon: const Icon(Icons.remove)),
        SizedBox(width: 56, child: Text('$value$suffix', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        IconButton.filledTonal(onPressed: () => setState(() => set(value + step)), icon: const Icon(Icons.add)),
      ]);

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.exercise == null ? 'Novo exercício' : 'Editar exercício',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TextField(controller: _name, autofocus: widget.exercise == null, decoration: const InputDecoration(labelText: 'Nome')),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _knee,
                onChanged: (v) => setState(() => _knee = v),
                title: const Text('Carrega o joelho', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Segue o semáforo: a carga cai quando o joelho reclama.'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _seconds,
                onChanged: (v) => setState(() => _seconds = v),
                title: const Text('Por tempo (isometria)', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              _stepper('Séries', _sets, (v) => _sets = v, min: 1),
              _stepper(_seconds ? 'Mínimo (s)' : 'Reps mínimas', _min, (v) {
                _min = v;
                if (_max < v) _max = v;
              }, step: _seconds ? 5 : 1, min: 1),
              _stepper(_seconds ? 'Meta (s)' : 'Reps máximas', _max, (v) => _max = v < _min ? _min : v, step: _seconds ? 5 : 1, min: 1),
              _stepper('RIR (reps na reserva)', _rir, (v) => _rir = v),
              _stepper('Descanso', _rest, (v) => _rest = v, step: 15, min: 15, suffix: 's'),
              Row(children: [
                const Expanded(child: Text('Aumento de carga', style: TextStyle(fontWeight: FontWeight.w700))),
                for (final v in [1.0, 2.0, 2.5, 5.0])
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ChoiceChip(label: Text(num1(v)), selected: _inc == v, onSelected: (_) => setState(() => _inc = v)),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Dicas de execução (opcional)')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty) return toast(context, 'Dê um nome ao exercício.');
                  e
                    ..name = _name.text.trim()
                    ..notes = _notes.text.trim()
                    ..sets = _sets
                    ..repMin = _min
                    ..repMax = _max
                    ..rir = _rir
                    ..restSeconds = _rest
                    ..increment = _inc
                    ..knee = _knee
                    ..seconds = _seconds;
                  Navigator.pop(context, e);
                },
                child: const Text('Salvar'),
              ),
              if (_knee)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Dica: em condropatia, prefira amplitude até ~90° com carga e controle a descida.',
                      style: TextStyle(color: brand.withValues(alpha: .9), fontSize: 13)),
                ),
            ]),
          ),
        ),
      );
}
