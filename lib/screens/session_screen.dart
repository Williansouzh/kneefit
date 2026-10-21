import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/knee.dart';
import '../logic/progression.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Treino em andamento (ou um já feito, para corrigir). Cada série: carga, repetições, RIR e ✓.
/// Marcar uma série inicia o descanso do exercício.
class SessionScreen extends StatefulWidget {
  final Session session;
  const SessionScreen({super.key, required this.session});
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  Timer? _ticker;
  int _restLeft = 0, _restTotal = 0;

  Session get s => widget.session;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_restLeft > 0 && --_restLeft == 0) HapticFeedback.heavyImpact();
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _changed() {
    context.read<Store>().changed();
    setState(() {});
  }

  void _toggle(ExerciseLog e, SetLog set) {
    set.done = !set.done;
    if (set.done) {
      HapticFeedback.mediumImpact();
      final rest = context.read<Store>().exercise(e.exerciseId)?.restSeconds ?? 90;
      _restLeft = _restTotal = rest;
    }
    _changed();
  }

  Future<void> _finish() async {
    final result = await showModalBottomSheet<(Pain, Pain, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FinishSheet(note: s.note, left: s.painLeft, right: s.painRight),
    );
    if (result == null || !mounted) return;
    final store = context.read<Store>();
    final before = store.knee.phase;
    store.finishSession(s, left: result.$1, right: result.$2, note: result.$3);
    final after = store.knee;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Text(after.light.emoji, style: const TextStyle(fontSize: 36)),
        title: const Text('Treino registrado 💪'),
        content: Text([
          '${s.setsDone} séries · ${num1(s.volume)} kg de volume.',
          if (after.phase != before) '\n${after.title}: ${after.advice}' else if (after.phase != KneePhase.normal) '\n${after.advice}',
          if (after.seePhysio) '\n⚠️ Dor forte de novo: pare o que dói e fale com o fisioterapeuta.',
        ].join('\n')),
        actions: [FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c), child: const Text('Fechar'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _discard() async {
    if (!await confirm(context, 'Descartar este treino?', 'As séries anotadas serão apagadas.', ok: 'Descartar')) return;
    if (!mounted) return;
    context.read<Store>().deleteSession(s);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final knee = store.knee;
    final elapsed = DateTime.now().difference(s.date);
    final pad = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.dayName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        actions: [
          if (!s.finished)
            Center(
              child: Text('${elapsed.inMinutes} min',
                  style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          PopupMenuButton<String>(
            onSelected: (_) => _discard(),
            itemBuilder: (_) => [PopupMenuItem(value: 'x', child: Text(s.finished ? 'Excluir treino' : 'Descartar treino'))],
          ),
        ],
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 120 + pad), children: [
        if (!s.finished && knee.phase != KneePhase.normal)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('${knee.light.emoji} ${knee.title}: cargas de joelho já ajustadas.',
                style: TextStyle(fontWeight: FontWeight.w800, color: painColor(knee.light))),
          ),
        for (final e in s.exercises) ...[
          _ExerciseCard(
            log: e,
            exercise: store.exercise(e.exerciseId),
            suggestion: switch (store.exercise(e.exerciseId)) {
              final ex? when !s.finished => suggest(ex, store.sessions, knee),
              _ => null,
            },
            onToggle: (set) => _toggle(e, set),
            onChanged: _changed,
          ),
          const SizedBox(height: 12),
        ],
      ]),
      bottomSheet: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + pad),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_restLeft > 0) ...[
            _RestBar(left: _restLeft, total: _restTotal, onAdd: () => setState(() => _restLeft += 15), onSkip: () => setState(() => _restLeft = 0)),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            icon: const Icon(Icons.flag),
            label: Text(s.finished ? 'Salvar semáforo e nota' : 'Terminar treino'),
            onPressed: _finish,
          ),
        ]),
      ),
    );
  }
}

class _RestBar extends StatelessWidget {
  final int left, total;
  final VoidCallback onAdd, onSkip;
  const _RestBar({required this.left, required this.total, required this.onAdd, required this.onSkip});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(color: teal.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(value: left / total, strokeWidth: 4, color: teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Descanso ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          TextButton(onPressed: onAdd, child: const Text('+15s')),
          TextButton(onPressed: onSkip, child: const Text('Pular')),
        ]),
      );
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseLog log;
  final Exercise? exercise;
  final Suggestion? suggestion;
  final ValueChanged<SetLog> onToggle;
  final VoidCallback onChanged;
  const _ExerciseCard({
    required this.log,
    required this.exercise,
    required this.suggestion,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ex = exercise;
    final allDone = log.sets.isNotEmpty && log.sets.every((x) => x.done);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(log.name,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: allDone ? cs.onSurfaceVariant : null)),
            ),
            if (log.knee)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: brand.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
                child: const Text('🦵 joelho', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: brand)),
              ),
          ]),
          if (ex != null)
            Text('${ex.target} · RIR ${ex.rir} · descanso ${ex.restSeconds}s', style: TextStyle(color: cs.onSurfaceVariant)),
          if (suggestion != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  suggestion!.up ? Icons.trending_up : (suggestion!.reduced ? Icons.healing : Icons.lightbulb_outline),
                  size: 18,
                  color: suggestion!.up ? green : (suggestion!.reduced ? amber : teal),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(suggestion!.text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              ]),
            ),
          if (ex != null && ex.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(ex.notes, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 30),
            Expanded(flex: 4, child: Text('Carga', style: _head(cs))),
            Expanded(flex: 5, child: Text(log.seconds ? 'Segundos' : 'Reps', textAlign: TextAlign.center, style: _head(cs))),
            Expanded(flex: 3, child: Text('RIR', textAlign: TextAlign.center, style: _head(cs))),
            const SizedBox(width: 48),
          ]),
          for (final (i, set) in log.sets.indexed)
            _SetRow(index: i, set: set, seconds: log.seconds, onToggle: () => onToggle(set), onChanged: onChanged),
          Row(children: [
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Série'),
              onPressed: () {
                final last = log.sets.lastOrNull;
                log.sets.add(SetLog(weight: last?.weight ?? 0, reps: last?.reps ?? log.repMax, rir: last?.rir ?? log.rir));
                onChanged();
              },
            ),
            if (log.sets.length > 1 && !log.sets.last.done)
              TextButton.icon(
                icon: const Icon(Icons.remove, size: 18),
                label: const Text('Tirar'),
                onPressed: () {
                  log.sets.removeLast();
                  onChanged();
                },
              ),
          ]),
        ]),
      ),
    );
  }

  TextStyle _head(ColorScheme cs) => TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant);
}

class _SetRow extends StatelessWidget {
  final int index;
  final SetLog set;
  final bool seconds;
  final VoidCallback onToggle, onChanged;
  const _SetRow({required this.index, required this.set, required this.seconds, required this.onToggle, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final step = seconds ? 5 : 1;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: set.done ? green.withValues(alpha: .12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: Text('${index + 1}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        Expanded(
          flex: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final w = await askNumber(context, 'Carga da série ${index + 1}', initial: set.weight);
              if (w != null && w >= 0) {
                set.weight = w;
                onChanged();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(set.weight == 0 ? '—' : '${num1(set.weight)} kg', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Tiny(Icons.remove, () {
              if (set.reps >= step) set.reps -= step;
              onChanged();
            }),
            SizedBox(
              width: 30,
              child: Text('${set.reps}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            _Tiny(Icons.add, () {
              set.reps += step;
              onChanged();
            }),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Center(
            child: DropdownButton<int>(
              value: set.rir.clamp(0, 5),
              underline: const SizedBox(),
              isDense: true,
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: cs.onSurface, fontSize: 15),
              items: [for (var r = 0; r <= 5; r++) DropdownMenuItem(value: r, child: Text('$r'))],
              onChanged: (v) {
                set.rir = v ?? set.rir;
                onChanged();
              },
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: IconButton(
            onPressed: onToggle,
            icon: Icon(set.done ? Icons.check_circle : Icons.radio_button_unchecked, color: set.done ? green : cs.outline, size: 30),
          ),
        ),
      ]),
    );
  }
}

class _Tiny extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Tiny(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18)),
      );
}

class _FinishSheet extends StatefulWidget {
  final String note;
  final Pain? left, right;
  const _FinishSheet({required this.note, this.left, this.right});
  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  late Pain? _left = widget.left, _right = widget.right;
  late final _note = TextEditingController(text: widget.note);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Como ficaram os joelhos?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Dor é dado, não fracasso: o app ajusta as próximas cargas.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 18),
              PainPicker(label: 'Joelho esquerdo', value: _left, onChanged: (p) => setState(() => _left = p)),
              const SizedBox(height: 16),
              PainPicker(label: 'Joelho direito', value: _right, onChanged: (p) => setState(() => _right = p)),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Nota (opcional)', hintText: 'Dormi mal, doeu na extensora...'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _left == null || _right == null ? null : () => Navigator.pop(context, (_left!, _right!, _note.text.trim())),
                child: const Text('Salvar treino'),
              ),
            ]),
          ),
        ),
      );
}
