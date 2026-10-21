import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Antes e depois da mesma pose: arraste o divisor para comparar, ou veja lado a lado.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late final Store store = context.read<Store>();
  late PhotoSet _before = store.photoSets.first, _after = store.photoSets.last;
  PhotoPose _pose = PhotoPose.front;
  double _split = .5;
  bool _sideBySide = false;

  Future<PhotoSet?> _pick() => showModalBottomSheet<PhotoSet>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          top: false,
          child: ListView(shrinkWrap: true, children: [
            for (final p in store.photoSets.reversed)
              ListTile(
                title: Text(capitalize(dayMonth.format(p.date)), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(p.photos.keys.map((k) => k.label).join(' · ')),
                onTap: () => Navigator.pop(c, p),
              ),
          ]),
        ),
      );

  Widget _photo(PhotoSet s) {
    final f = s.photos[_pose];
    return f == null
        ? Container(color: Colors.black26, alignment: Alignment.center, child: Text('Sem foto de ${_pose.label.toLowerCase()}'))
        : Image.file(store.media(f), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final days = _after.date.difference(_before.date).inDays;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antes e depois', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: _sideBySide ? 'Divisor' : 'Lado a lado',
            icon: Icon(_sideBySide ? Icons.compare : Icons.view_column_outlined),
            onPressed: () => setState(() => _sideBySide = !_sideBySide),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async => (await _pick())?.let((p) => setState(() => _before = p)),
                child: Text('Antes: ${dayMonth.format(_before.date)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async => (await _pick())?.let((p) => setState(() => _after = p)),
                child: Text('Depois: ${dayMonth.format(_after.date)}'),
              ),
            ),
          ]),
        ),
        SegmentedButton<PhotoPose>(
          showSelectedIcon: false,
          segments: [for (final p in PhotoPose.values) ButtonSegment(value: p, label: Text(p.label))],
          selected: {_pose},
          onSelectionChanged: (s) => setState(() => _pose = s.first),
        ),
        const SizedBox(height: 10),
        Text('${days.abs()} dias de diferença', style: const TextStyle(fontWeight: FontWeight.w800, color: brand)),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _sideBySide
                  ? Row(children: [Expanded(child: _photo(_before)), const SizedBox(width: 4), Expanded(child: _photo(_after))])
                  : LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        onHorizontalDragUpdate: (d) => setState(() => _split = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
                        onTapDown: (d) => setState(() => _split = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
                        child: Stack(fit: StackFit.expand, children: [
                          _photo(_after),
                          ClipRect(clipper: _LeftClipper(_split), child: _photo(_before)),
                          Positioned(
                            left: box.maxWidth * _split - 1.5,
                            top: 0,
                            bottom: 0,
                            child: Container(width: 3, color: Colors.white),
                          ),
                          Positioned(
                            left: box.maxWidth * _split - 20,
                            top: box.maxHeight / 2 - 20,
                            child: const CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.compare_arrows, color: Colors.black),
                            ),
                          ),
                          const Positioned(left: 10, top: 10, child: _Tag('Antes')),
                          const Positioned(right: 10, top: 10, child: _Tag('Depois')),
                        ]),
                      ),
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

class _LeftClipper extends CustomClipper<Rect> {
  final double split;
  _LeftClipper(this.split);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * split, size.height);
  @override
  bool shouldReclip(_LeftClipper old) => old.split != split;
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      );
}
