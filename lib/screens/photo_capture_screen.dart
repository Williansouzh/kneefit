import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'measurements_screen.dart';

/// Check-in de fotos: frente, lado e costas. A câmera mostra linhas-guia (cabeça, pés, centro)
/// e a foto anterior da mesma pose em transparência, para repetir distância e posição.
class PhotoCaptureScreen extends StatefulWidget {
  final PhotoSet? editing;
  const PhotoCaptureScreen({super.key, this.editing});
  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> with WidgetsBindingObserver {
  late final Store store = context.read<Store>();
  late final PhotoSet set = widget.editing ?? PhotoSet(date: dateOnly(DateTime.now()), photos: {});
  late final bool isNew = widget.editing == null;
  final _taken = <PhotoPose, String>{}; // fotos novas desta tela (apagadas se sair sem salvar)

  List<CameraDescription> _cameras = [];
  CameraController? _camera;
  int _camIndex = 0;
  PhotoPose _pose = PhotoPose.front;
  bool _ghost = true, _busy = false;
  int _timer = 10, _countdown = 0;
  String? _error;

  /// Foto de referência: a da mesma pose no check-in anterior a este.
  String? get _reference => store.photoSets.where((p) => p.date.isBefore(set.date) && p.photos.containsKey(_pose)).lastOrNull?.photos[_pose];

  String? get _current => _taken[_pose] ?? set.photos[_pose];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _camera?.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _open();
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      // Começa pela traseira: com o celular apoiado, a foto sai melhor.
      _camIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back).clamp(0, _cameras.length);
      await _open();
    } catch (e) {
      setState(() => _error = 'Câmera indisponível: $e');
    }
  }

  Future<void> _open() async {
    if (_cameras.isEmpty) return setState(() => _error = 'Nenhuma câmera encontrada.');
    final old = _camera;
    _camera = null;
    await old?.dispose();
    final c = CameraController(_cameras[_camIndex], ResolutionPreset.high, enableAudio: false);
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _camera = c);
    } on CameraException catch (e) {
      setState(() => _error = e.code == 'CameraAccessDenied' ? 'Libere a câmera nas configurações do Android.' : 'Erro na câmera: ${e.description}');
    }
  }

  Future<void> _shoot() async {
    final c = _camera;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    for (_countdown = _timer; _countdown > 0; _countdown--) {
      if (!mounted) return;
      setState(() {});
      HapticFeedback.selectionClick();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    try {
      final shot = await c.takePicture();
      final name = 'photo_${set.id}_${_pose.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(shot.path).copy(store.media(name).path);
      await File(shot.path).delete().catchError((_) => File(shot.path));
      final previous = _taken[_pose];
      if (previous != null) await store.media(previous).delete().catchError((_) => store.media(previous));
      HapticFeedback.heavyImpact();
      setState(() {
        _taken[_pose] = name;
        final next = PhotoPose.values.where((p) => !(_taken.containsKey(p) || set.photos.containsKey(p))).firstOrNull;
        if (next != null) _pose = next;
      });
    } catch (e) {
      if (mounted) toast(context, 'Não deu para tirar a foto: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    for (final e in _taken.entries) {
      final old = set.photos[e.key];
      if (old != null) await store.media(old).delete().catchError((_) => store.media(old));
      set.photos[e.key] = e.value;
    }
    _taken.clear();
    if (set.photos.isEmpty) return;
    store.addPhotoSet(set);
    if (!mounted) return;
    final measure = isNew &&
        await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Fotos salvas 📸'),
                content: const Text('Aproveita e registra as medidas de hoje?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Agora não')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Medir')),
                ],
              ),
            ) ==
            true;
    if (!mounted) return;
    Navigator.pop(context);
    if (measure) Navigator.push(context, MaterialPageRoute(builder: (_) => const MeasureForm()));
  }

  Future<bool> _discardTaken() async {
    if (_taken.isEmpty) return true;
    if (!await confirm(context, 'Sair sem salvar?', 'As fotos novas serão descartadas.', ok: 'Descartar')) return false;
    for (final f in _taken.values) {
      await store.media(f).delete().catchError((_) => store.media(f));
    }
    _taken.clear();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = _camera;
    final pad = MediaQuery.paddingOf(context);
    final reviewing = _current != null && !_taken.containsKey(_pose) && !isNew;
    return PopScope(
      canPop: _taken.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _discardTaken() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)))
                : c == null || !c.value.isInitialized
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: AspectRatio(
                          aspectRatio: 1 / c.value.aspectRatio,
                          child: Stack(fit: StackFit.expand, children: [
                            if (reviewing) Image.file(store.media(_current!), fit: BoxFit.cover) else CameraPreview(c),
                            if (_ghost && _reference != null && !reviewing)
                              Opacity(opacity: .3, child: Image.file(store.media(_reference!), fit: BoxFit.cover, cacheWidth: 720)),
                            const IgnorePointer(child: CustomPaint(painter: _GuidePainter())),
                            if (_countdown > 0)
                              Center(
                                child: Text('$_countdown',
                                    style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 20)])),
                              ),
                          ]),
                        ),
                      ),
          ),
          // Topo: voltar, pose e dicas.
          Positioned(
            top: pad.top + 8,
            left: 8,
            right: 8,
            child: Column(children: [
              Row(children: [
                IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    if (await _discardTaken() && context.mounted) Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: SegmentedButton<PhotoPose>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      selectedBackgroundColor: brand,
                      selectedForegroundColor: Colors.white,
                    ),
                    segments: [
                      for (final p in PhotoPose.values)
                        ButtonSegment(
                          value: p,
                          label: Text('${p.label}${(_taken[p] ?? set.photos[p]) != null ? ' ✓' : ''}'),
                        ),
                    ],
                    selected: {_pose},
                    onSelectionChanged: (s) => setState(() => _pose = s.first),
                  ),
                ),
                const SizedBox(width: 8),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  switch (_pose) {
                    PhotoPose.front => 'Braços relaxados ao lado, pés na largura do quadril',
                    PhotoPose.side => 'Lado direito para a câmera, braços relaxados',
                    PhotoPose.back => 'De costas, braços relaxados, mesma distância',
                  },
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ),
          // Base: temporizador, fantasma, disparo, trocar câmera, salvar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + pad.bottom),
              color: Colors.black54,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final t in [0, 3, 10])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(t == 0 ? 'Sem timer' : '${t}s'),
                        selected: _timer == t,
                        onSelected: (_) => setState(() => _timer = t),
                      ),
                    ),
                  if (_reference != null)
                    IconButton(
                      color: Colors.white,
                      tooltip: 'Foto anterior por cima',
                      icon: Icon(_ghost ? Icons.layers : Icons.layers_clear),
                      onPressed: () => setState(() => _ghost = !_ghost),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _cameras.length > 1
                        ? IconButton(
                            color: Colors.white,
                            iconSize: 30,
                            icon: const Icon(Icons.cameraswitch_outlined),
                            onPressed: () {
                              _camIndex = (_camIndex + 1) % _cameras.length;
                              _open();
                            },
                          )
                        : const SizedBox(),
                  ),
                  GestureDetector(
                    onTap: reviewing ? () => setState(() => set.photos.remove(_pose)) : _shoot,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _busy ? Colors.white38 : Colors.white),
                        child: reviewing ? const Icon(Icons.replay, color: Colors.black, size: 30) : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                        onPressed: _taken.isEmpty && (isNew || set.photos.isEmpty) ? null : _save,
                        child: const Text('Salvar'),
                      ),
                    ),
                  ),
                ]),
                if (!isNew)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    onPressed: () async {
                      if (!await confirm(context, 'Excluir este check-in?', 'As 3 fotos serão apagadas do celular.')) return;
                      await store.deletePhotoSet(set);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text('Excluir check-in de ${dayMonth.format(set.date)}'),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Linhas-guia: centro, topo da cabeça (10%) e pés (90%).
class _GuidePainter extends CustomPainter {
  const _GuidePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .55)
      ..strokeWidth = 1.5;
    final dash = Paint()
      ..color = brand.withValues(alpha: .9)
      ..strokeWidth = 2.5;
    void hline(double y, Paint paint) {
      for (var x = 0.0; x < size.width; x += 16) {
        canvas.drawLine(Offset(x, y), Offset(x + 9, y), paint);
      }
    }

    for (var y = 0.0; y < size.height; y += 16) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + 9), p);
    }
    hline(size.height * .10, dash);
    hline(size.height * .90, dash);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final (y, t) in [(size.height * .10 + 4, 'cabeça'), (size.height * .90 - 20, 'pés')]) {
      tp.text = TextSpan(text: t, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800));
      tp.layout();
      tp.paint(canvas, Offset(8, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
