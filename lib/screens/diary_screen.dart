import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../defaults.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Diário em vídeo: gravações curtas por data, para ter o arquivo da evolução sem editar nada.
class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Diário')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.fiber_manual_record, color: red),
        label: const Text('Gravar'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordScreen())),
      ),
      body: store.videos.isEmpty
          ? const Empty(
              icon: Icons.videocam_outlined,
              title: 'Seu arquivo de evolução',
              message: 'Grave até 10 minutos, uma vez por semana. As perguntas-guia aparecem na tela; '
                  'daqui a meses, assistir o começo é o que segura a motivação.',
            )
          : ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 96 + MediaQuery.paddingOf(context).bottom), children: [
              for (final v in store.videos)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: brand.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.play_arrow_rounded, color: brand, size: 34),
                    ),
                    title: Text(v.title.isEmpty ? capitalize(weekdayDay.format(v.date)) : v.title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${v.title.isEmpty ? '' : '${capitalize(dayMonth.format(v.date))} · '}${_clock(v.seconds)}',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (a) async {
                        if (a == 'rename') {
                          final t = await _askTitle(context, v.title);
                          if (t != null) {
                            v.title = t;
                            store.changed();
                          }
                        } else if (await confirm(context, 'Excluir este vídeo?', 'Ele será apagado do celular.') && context.mounted) {
                          await store.deleteVideo(v);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Dar um título')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(video: v))),
                  ),
                ),
            ]),
    );
  }
}

Future<String?> _askTitle(BuildContext context, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Título do vídeo'),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Ex.: Semana 6 — voltei a agachar')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Pular')),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Salvar')),
      ],
    ),
  );
}

/// Gravação com a câmera frontal. As perguntas-guia ficam no topo (opcionais); para em 10 minutos.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});
  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  static const maxSeconds = 600;
  CameraController? _camera;
  String? _error;
  bool _recording = false, _prompts = true, _saving = false;
  int _prompt = 0, _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
      // Qualidade média: 10 minutos ficam em ~100–200 MB, em vez de quase 1 GB.
      final c = CameraController(cam, ResolutionPreset.medium, enableAudio: true);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _camera = c);
    } on CameraException catch (e) {
      setState(() => _error = e.code.contains('AccessDenied') ? 'Libere câmera e microfone nas configurações do Android.' : 'Erro na câmera: ${e.description}');
    } catch (e) {
      setState(() => _error = 'Câmera indisponível: $e');
    }
  }

  Future<void> _toggle() async {
    final c = _camera;
    if (c == null || _saving) return;
    if (!_recording) {
      await c.startVideoRecording();
      HapticFeedback.mediumImpact();
      setState(() {
        _recording = true;
        _elapsed = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed++);
        if (_elapsed >= maxSeconds) _toggle();
      });
      return;
    }
    _timer?.cancel();
    setState(() => _saving = true);
    final store = context.read<Store>();
    try {
      final file = await c.stopVideoRecording();
      final name = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await File(file.path).copy(store.media(name).path);
      await File(file.path).delete().catchError((_) => File(file.path));
      if (!mounted) return;
      final title = await _askTitle(context, '');
      store.addVideo(VideoEntry(file: name, date: DateTime.now(), title: title ?? '', seconds: _elapsed));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        toast(context, 'Não deu para salvar o vídeo: $e');
        setState(() {
          _saving = false;
          _recording = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _camera;
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: !_recording,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)))
                : c == null
                    ? const Center(child: CircularProgressIndicator())
                    : Center(child: AspectRatio(aspectRatio: 1 / c.value.aspectRatio, child: CameraPreview(c))),
          ),
          Positioned(
            top: pad.top + 8,
            left: 12,
            right: 12,
            child: Column(children: [
              Row(children: [
                if (!_recording) IconButton(color: Colors.white, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _recording ? red : Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text('${_clock(_elapsed)} / 10:00', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
                const Spacer(),
                IconButton(
                  color: Colors.white,
                  tooltip: 'Perguntas-guia',
                  icon: Icon(_prompts ? Icons.help : Icons.help_outline),
                  onPressed: () => setState(() => _prompts = !_prompts),
                ),
              ]),
              if (_prompts) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _prompt == 0 ? null : () => setState(() => _prompt--),
                    ),
                    Expanded(
                      child: Column(children: [
                        Text('${_prompt + 1} de ${videoPrompts.length}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(videoPrompts[_prompt],
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.2)),
                      ]),
                    ),
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _prompt == videoPrompts.length - 1 ? null : () => setState(() => _prompt++),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          Positioned(
            bottom: pad.bottom + 28,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
                  padding: EdgeInsets.all(_recording ? 22 : 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(_recording ? 8 : 40)),
                    child: _saving ? const Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : null,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  final VideoEntry video;
  const PlayerScreen({super.key, required this.video});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController _c = VideoPlayerController.file(context.read<Store>().media(widget.video.file));

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (mounted) setState(() {});
    });
    _c.initialize().then((_) => _c.play());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.video.title.isEmpty ? capitalize(dayMonth.format(widget.video.date)) : widget.video.title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: !v.isInitialized
          ? Center(child: v.hasError ? Text('Não deu para abrir: ${v.errorDescription}', style: const TextStyle(color: Colors.white)) : const CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => v.isPlaying ? _c.pause() : _c.play(),
                  child: Center(child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(_c))),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
                child: Row(children: [
                  IconButton(
                    color: Colors.white,
                    iconSize: 34,
                    icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    onPressed: () => v.isPlaying ? _c.pause() : _c.play(),
                  ),
                  Expanded(child: VideoProgressIndicator(_c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: brand))),
                  const SizedBox(width: 12),
                  Text('${_clock(v.position.inSeconds)} / ${_clock(v.duration.inSeconds)}', style: const TextStyle(color: Colors.white)),
                ]),
              ),
            ]),
    );
  }
}
