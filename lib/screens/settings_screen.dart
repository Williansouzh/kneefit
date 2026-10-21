import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/knee.dart';
import '../models.dart';
import '../services/alarms.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Refeições e alarmes, regras do semáforo, intervalo do check-in e backup.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom), children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: const Badge2(Icons.restaurant, teal),
              title: const Text('Refeições e alarmes', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${store.meals.length} refeições · ${store.meals.where((m) => m.alarm).length} com alarme'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealsScreen())),
            ),
            ListTile(
              leading: const Badge2(Icons.traffic, amber),
              title: const Text('Regras do semáforo', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Quanto reduzir a carga em cada fase'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RulesScreen())),
            ),
            ListTile(
              leading: const Badge2(Icons.photo_camera_outlined, brand),
              title: const Text('Check-in de fotos', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('A cada ${store.checkInWeeks} semanas'),
              trailing: DropdownButton<int>(
                value: store.checkInWeeks,
                underline: const SizedBox(),
                items: [for (final w in [2, 3, 4, 6, 8]) DropdownMenuItem(value: w, child: Text('$w sem'))],
                onChanged: (w) {
                  store.checkInWeeks = w ?? 4;
                  store.changed();
                },
              ),
            ),
          ]),
        ),
        const Section('Backup'),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Badge2(Icons.upload_file, teal),
              title: const Text('Exportar backup', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Treinos, dor, refeições, peso e medidas (sem fotos e vídeos)'),
              onTap: () async {
                await store.flush();
                final file = File('${Directory.systemTemp.path}/fitknee-backup-${dayKey(DateTime.now())}.json');
                await file.writeAsString(const JsonEncoder.withIndent(' ').convert(store.toJson()));
                await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Backup do FitKnee'));
              },
            ),
            ListTile(
              leading: const Badge2(Icons.download, brand),
              title: const Text('Restaurar backup', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Substitui os dados deste celular'),
              onTap: () async {
                final picked = (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json'])).singleOrNull;
                if (picked == null || !context.mounted) return;
                if (!await confirm(context, 'Restaurar este backup?', 'Os dados atuais serão substituídos.', ok: 'Restaurar')) return;
                try {
                  await store.restore(utf8.decode(await picked.readAsBytes()));
                  if (context.mounted) {
                    context.read<Alarms>().sync(store.meals).ignore();
                    toast(context, 'Backup restaurado.');
                  }
                } catch (e) {
                  if (context.mounted) toast(context, '$e');
                }
              },
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(
          'Tudo fica só neste celular. O FitKnee não substitui o fisioterapeuta: as regras do semáforo são um guia '
          'conservador. Dor forte, inchaço, falseio ou travamento: pare e procure avaliação.',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}

class MealsScreen extends StatelessWidget {
  const MealsScreen({super.key});

  Future<void> _sync(BuildContext context) => context.read<Alarms>().sync(context.read<Store>().meals);

  Future<void> _edit(BuildContext context, [Meal? meal]) async {
    final store = context.read<Store>();
    final name = TextEditingController(text: meal?.name);
    final hint = TextEditingController(text: meal?.hint);
    var time = TimeOfDay(hour: meal?.hour ?? 12, minute: meal?.minute ?? 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(meal == null ? 'Nova refeição' : 'Editar refeição'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 10),
            TextField(controller: hint, decoration: const InputDecoration(labelText: 'O que comer (lembrete)')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(time.format(c)),
              onPressed: () async {
                final t = await showTimePicker(context: c, initialTime: time);
                if (t != null) set(() => time = t);
              },
            ),
          ]),
          actions: [
            if (meal != null)
              TextButton(
                onPressed: () {
                  store.meals.remove(meal);
                  Navigator.pop(c, true);
                },
                child: const Text('Excluir', style: TextStyle(color: red)),
              ),
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                final m = meal ?? Meal(name: '', hour: 0, minute: 0);
                m
                  ..name = name.text.trim()
                  ..hint = hint.text.trim()
                  ..hour = time.hour
                  ..minute = time.minute;
                if (meal == null) store.meals.add(m);
                Navigator.pop(c, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    store.meals.sort((a, b) => a.minutes.compareTo(b.minutes));
    store.changed();
    if (context.mounted) await _sync(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('Refeições')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Refeição'),
        onPressed: () => _edit(context),
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 96 + MediaQuery.paddingOf(context).bottom), children: [
        Text('Horários fixos, pensados para quem esquece de comer. O alarme toca todo dia no horário.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Permitir notificações'),
          onPressed: () async {
            final ok = await context.read<Alarms>().requestPermission();
            if (!context.mounted) return;
            await _sync(context);
            if (context.mounted) toast(context, ok ? 'Alarmes ativos.' : 'Sem permissão: libere as notificações do FitKnee no Android.');
          },
        ),
        const SizedBox(height: 12),
        for (final m in store.meals)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: SwitchListTile(
              value: m.alarm,
              onChanged: (v) async {
                m.alarm = v;
                store.changed();
                await _sync(context);
              },
              title: Text('${m.time}  ${m.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: m.hint.isEmpty ? null : Text(m.hint),
              secondary: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, m)),
            ),
          ),
      ]),
    );
  }
}

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final r = store.rules;
    Widget slider(String title, String help, double value, ValueChanged<double> set) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
                Text(KneeStatus.pct(value), style: const TextStyle(fontWeight: FontWeight.w900, color: brand)),
              ]),
              Text(help, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Slider(
                value: value,
                min: .3,
                max: 1,
                divisions: 14,
                onChanged: (v) {
                  set(double.parse(v.toStringAsFixed(2)));
                  store.changed();
                },
              ),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Semáforo')),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom), children: [
        const Text(
          'Depois de cada treino você marca cada joelho. O pior dos dois decide:\n'
          '🟢 sem dor: segue (ou volta uma fase).\n'
          '🟡 incômodo: atenção. Um segundo 🟡 seguido vai para o retorno fase 2.\n'
          '🔴 dor: retorno fase 1. Duas 🔴 seguidas: procure o fisio.\n'
          'As porcentagens valem só para os exercícios marcados como "de joelho", sobre a última carga feita sem dor.',
          style: TextStyle(height: 1.45),
        ),
        const SizedBox(height: 14),
        slider('🟡 Atenção', 'Depois de um incômodo', r.cautionFactor, (v) => r.cautionFactor = v),
        slider('🔴 Retorno fase 1', 'Logo depois de dor', r.return1Factor, (v) => r.return1Factor = v),
        slider('Retorno fase 2', '', r.return2Factor, (v) => r.return2Factor = v),
        slider('Retorno fase 3', 'Última antes de liberar', r.return3Factor, (v) => r.return3Factor = v),
        Card(
          child: ListTile(
            title: const Text('Sessões 🟢 para avançar de fase', style: TextStyle(fontWeight: FontWeight.w900)),
            trailing: DropdownButton<int>(
              value: r.greensToAdvance,
              underline: const SizedBox(),
              items: [for (final n in [1, 2, 3, 4]) DropdownMenuItem(value: n, child: Text('$n'))],
              onChanged: (n) {
                r.greensToAdvance = n ?? 2;
                store.changed();
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            store.rules = KneeRules();
            store.changed();
          },
          child: const Text('Voltar ao padrão'),
        ),
      ]),
    );
  }
}
