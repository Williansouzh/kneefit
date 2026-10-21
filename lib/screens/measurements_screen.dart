import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

/// Medidas em centímetros: um registro por dia, sempre nos mesmos pontos do corpo.
class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final list = store.measurements.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Medidas')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Medir hoje'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeasureForm())),
      ),
      body: list.isEmpty
          ? const Empty(
              icon: Icons.straighten,
              title: 'Nenhuma medida',
              message: 'Meça de manhã, com a fita firme sem apertar, sempre no mesmo ponto (ex.: braço no maior volume, relaxado).',
            )
          : ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom), children: [
              for (final (i, m) in list.indexed)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(capitalize(dayMonth.format(m.date)), style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(m.values.entries.map((e) {
                      final prev = i + 1 < list.length ? list[i + 1].values[e.key] : null;
                      final d = prev == null ? 0 : e.value - prev;
                      return '${e.key}: ${num1(e.value)}${d == 0 ? '' : ' (${d > 0 ? '+' : ''}${num1(d.toDouble())})'}';
                    }).join('\n')),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MeasureForm(editing: m))),
                  ),
                ),
            ]),
    );
  }
}

class MeasureForm extends StatefulWidget {
  final Measurement? editing;
  const MeasureForm({super.key, this.editing});
  @override
  State<MeasureForm> createState() => _MeasureFormState();
}

class _MeasureFormState extends State<MeasureForm> {
  late final Store store = context.read<Store>();
  late final Map<String, TextEditingController> _fields = {
    for (final n in {...store.measureNames, ...?widget.editing?.values.keys})
      n: TextEditingController(text: widget.editing?.values[n] == null ? '' : num1(widget.editing!.values[n]!)),
  };

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addName() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo ponto de medida'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Ex.: Antebraço D')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Adicionar'))],
      ),
    );
    if (name == null || name.isEmpty || _fields.containsKey(name)) return;
    store.measureNames.add(name);
    store.changed();
    setState(() => _fields[name] = TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    final last = store.measurements.where((m) => m != widget.editing).lastOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? 'Medir hoje' : dayMonth.format(widget.editing!.date)),
        actions: [
          if (widget.editing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirm(context, 'Excluir estas medidas?', 'Não dá para desfazer.')) return;
                store.measurements.remove(widget.editing);
                store.changed();
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom), children: [
        for (final e in _fields.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: e.value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: e.key,
                suffixText: 'cm',
                helperText: last?.values[e.key] == null ? null : 'Antes: ${num1(last!.values[e.key]!)} cm',
              ),
            ),
          ),
        TextButton.icon(onPressed: _addName, icon: const Icon(Icons.add), label: const Text('Outro ponto')),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            final values = {
              for (final e in _fields.entries)
                if (parseNum(e.value.text) case final v? when v > 0) e.key: v,
            };
            if (values.isEmpty) return toast(context, 'Preencha pelo menos uma medida.');
            if (widget.editing != null) store.measurements.remove(widget.editing);
            store.setMeasurement(Measurement(widget.editing?.date ?? dateOnly(DateTime.now()), values));
            Navigator.pop(context);
          },
          child: const Text('Salvar'),
        ),
      ]),
    );
  }
}
