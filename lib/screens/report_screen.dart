import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/stats.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

/// Resumo da semana (segunda a domingo) pronto para mandar ao treinador, fisio ou nutricionista.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _offset = 0; // 0 = esta semana, -1 = a passada...

  DateTime get _start {
    final today = dateOnly(DateTime.now());
    return today.subtract(Duration(days: today.weekday - 1)).add(Duration(days: 7 * _offset));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final text = weeklyReport(
      start: _start,
      plan: store.plan,
      sessions: store.sessions,
      knee: store.knee,
      meals: store.meals,
      mealChecks: store.mealChecks,
      weights: store.weights,
      measurements: store.measurements,
      videos: store.videos,
    );
    final pad = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('Resumo semanal')),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _offset--)),
          Text(
            _offset == 0 ? 'Esta semana' : (_offset == -1 ? 'Semana passada' : 'Semana de ${dayMonth.format(_start)}'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _offset == 0 ? null : () => setState(() => _offset++)),
        ]),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(text, style: const TextStyle(fontSize: 14.5, height: 1.45)),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + pad),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copiar'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  toast(context, 'Resumo copiado. É só colar na conversa.');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Enviar'),
                onPressed: () => SharePlus.instance.share(ShareParams(text: text, subject: 'Resumo semanal')),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
