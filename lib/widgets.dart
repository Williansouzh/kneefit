import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'theme.dart';

final dayMonth = DateFormat("d 'de' MMM", 'pt_BR');
final weekdayDay = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
const weekdayShort = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String num1(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');
double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'Excluir'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: red),
            onPressed: () => Navigator.pop(c, true),
            child: Text(ok),
          ),
        ],
      ),
    ) ??
    false;

/// Título de seção.
class Section extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const Section(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ?trailing,
        ]),
      );
}

/// Ícone em quadradinho colorido.
class Badge2 extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const Badge2(this.icon, this.color, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(size * .3)),
        child: Icon(icon, color: color, size: size * .55),
      );
}

/// Três botões do semáforo para um joelho.
class PainPicker extends StatelessWidget {
  final String label;
  final Pain? value;
  final ValueChanged<Pain> onChanged;
  const PainPicker({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        Row(children: [
          for (final p in Pain.values) ...[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(p);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value == p ? painColor(p).withValues(alpha: .18) : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: value == p ? painColor(p) : Colors.transparent, width: 2),
                  ),
                  child: Column(children: [
                    Text(p.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 2),
                    Text(p.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            if (p != Pain.red) const SizedBox(width: 8),
          ],
        ]),
      ]);
}

/// Mensagem de lista vazia.
class Empty extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final Widget? action;
  const Empty({super.key, required this.icon, required this.title, required this.message, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(children: [
          Badge2(icon, brand, size: 72),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Pede um número (peso, carga, medida).
Future<double?> askNumber(BuildContext context, String title, {double? initial, String suffix = 'kg'}) {
  final c = TextEditingController(text: initial == null ? '' : num1(initial));
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(suffixText: suffix),
        onSubmitted: (v) => Navigator.pop(ctx, parseNum(v)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, parseNum(c.text)), child: const Text('Salvar')),
      ],
    ),
  );
}
