import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../store.dart';

class CloudException implements Exception {
  final String message;
  const CloudException(this.message);
  @override
  String toString() => message;
}

/// Backup no Cloudflare R2, pelo Worker de `cloud/`. Fotos, vídeos e o JSON dos dados sobem
/// direto para o bucket em links assinados; tudo continua também no celular.
/// Sincroniza ao abrir o app e uns segundos depois de cada mudança.
class Cloud extends ChangeNotifier {
  final Store store;
  final Duration delay;
  Cloud(this.store, {this.delay = const Duration(seconds: 20)});

  static const backupName = 'fitknee.json';

  File get _file => File('${store.dir.path}/cloud.json');

  String url = '', token = '';
  Set<String> uploaded = {}; // arquivos de mídia que já estão no bucket
  DateTime? lastSync;
  String? error;
  bool syncing = false;
  bool get configured => url.isNotEmpty && token.isNotEmpty;

  Timer? _timer;
  bool _again = false;

  Future<void> load() async {
    if (await _file.exists()) {
      final j = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
      url = j['url'] ?? '';
      token = j['token'] ?? '';
      uploaded = {for (final n in j['uploaded'] ?? []) n as String};
      lastSync = j['lastSync'] == null ? null : DateTime.parse(j['lastSync']);
    }
    store.addListener(_onChange);
  }

  Future<void> _save() => _file.writeAsString(jsonEncode({
        'url': url,
        'token': token,
        'uploaded': [...uploaded],
        'lastSync': lastSync?.toIso8601String(),
      }));

  /// Confere o endereço e o token antes de guardar.
  Future<void> configure(String newUrl, String newToken) async {
    final old = (url, token);
    url = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    token = newToken.trim();
    try {
      await _list();
    } catch (_) {
      url = old.$1;
      token = old.$2;
      rethrow;
    }
    uploaded = {};
    await _save();
    notifyListeners();
  }

  Future<void> disconnect() async {
    _timer?.cancel();
    url = token = '';
    uploaded = {};
    lastSync = null;
    error = null;
    await _save();
    notifyListeners();
  }

  void _onChange() {
    if (!configured) return;
    _timer?.cancel();
    _timer = Timer(delay, () => sync().ignore());
  }

  @override
  void dispose() {
    _timer?.cancel();
    store.removeListener(_onChange);
    super.dispose();
  }

  /// Fotos e vídeos que os dados citam.
  static Set<String> mediaIn(Map<String, dynamic> j) => {
        for (final p in j['photoSets'] ?? []) ...[for (final f in (p['photos'] as Map).values) f as String],
        for (final v in j['videos'] ?? []) v['file'] as String,
      };

  /// Sobe a mídia nova, depois o JSON (que só cita arquivos que já estão lá) e por fim apaga
  /// do bucket o que foi excluído no app.
  Future<void> sync() async {
    if (!configured) return;
    if (syncing) {
      _again = true;
      return;
    }
    syncing = true;
    error = null;
    notifyListeners();
    try {
      await store.flush();
      final data = store.toJson();
      final local = mediaIn(data);
      for (final name in local.difference(uploaded)) {
        final f = store.media(name);
        if (!await f.exists()) continue;
        await _put(name, f.openRead(), await f.length());
        uploaded.add(name);
        await _save();
      }
      final json = utf8.encode(jsonEncode(data));
      await _put(backupName, Stream.value(json), json.length);
      for (final name in uploaded.difference(local)) {
        await _delete(name);
        uploaded.remove(name);
      }
      lastSync = DateTime.now();
      await _save();
    } on CloudException catch (e) {
      error = e.message;
    } finally {
      syncing = false;
      notifyListeners();
    }
    if (_again) {
      _again = false;
      await sync();
    }
  }

  /// Celular novo (ou reinstalado): baixa o JSON e as mídias que faltam, e restaura.
  /// Devolve quantos arquivos baixou.
  Future<int> restore() async {
    final remote = {for (final f in await _list()) f.$1};
    if (!remote.contains(backupName)) throw const CloudException('Ainda não há backup na nuvem.');
    final raw = utf8.decode(await _getBytes(backupName));
    final media = mediaIn(jsonDecode(raw) as Map<String, dynamic>).intersection(remote);
    await store.mediaDir.create(recursive: true);
    var downloaded = 0;
    for (final name in media) {
      final target = store.media(name);
      if (await target.exists()) continue;
      final tmp = File('${target.path}.part');
      await _download(name, tmp);
      await tmp.rename(target.path);
      downloaded++;
    }
    uploaded = media;
    await store.restore(raw);
    lastSync = DateTime.now();
    await _save();
    notifyListeners();
    return downloaded;
  }

  // ---------- HTTP ----------

  HttpClient _client() => HttpClient()..connectionTimeout = const Duration(seconds: 15);

  /// Chamada ao Worker (com o token).
  Future<Object?> _worker(String method, String path, [Object? body]) async {
    final client = _client();
    try {
      final req = await client.openUrl(method, Uri.parse('$url$path'));
      req.headers.set('authorization', 'Bearer $token');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode == 401) throw const CloudException('Token da nuvem inválido.');
      if (res.statusCode >= 300) throw CloudException('A nuvem respondeu ${res.statusCode}.');
      return text.isEmpty ? null : jsonDecode(text);
    } on SocketException {
      throw const CloudException('Sem conexão com a nuvem.');
    } on HandshakeException {
      throw const CloudException('Sem conexão segura com a nuvem.');
    } on FormatException {
      throw const CloudException('Endereço da nuvem errado: a resposta não é do Worker do FitKnee.');
    } finally {
      client.close();
    }
  }

  Future<String> _sign(String method, String name) async =>
      ((await _worker('POST', '/sign', {'method': method, 'name': name})) as Map)['url'] as String;

  Future<List<(String, int)>> _list() async =>
      [for (final f in (await _worker('GET', '/files')) as List) (f['name'] as String, f['size'] as int)];

  Future<void> _delete(String name) => _worker('DELETE', '/files/${Uri.encodeComponent(name)}');

  /// Envia direto para o bucket, em stream (vídeos podem ser grandes).
  Future<void> _put(String name, Stream<List<int>> data, int length) async {
    final signed = Uri.parse(await _sign('PUT', name));
    final client = _client();
    try {
      final req = await client.openUrl('PUT', signed);
      req.contentLength = length;
      await req.addStream(data);
      final res = await req.close();
      await res.drain<void>();
      if (res.statusCode != 200) throw CloudException('O R2 recusou $name (${res.statusCode}).');
    } on SocketException {
      throw const CloudException('A conexão caiu durante o envio.');
    } finally {
      client.close();
    }
  }

  Future<HttpClientResponse> _open(String name, HttpClient client) async {
    final res = await (await client.getUrl(Uri.parse(await _sign('GET', name)))).close();
    if (res.statusCode != 200) {
      await res.drain<void>();
      throw CloudException('Não deu para baixar $name (${res.statusCode}).');
    }
    return res;
  }

  Future<List<int>> _getBytes(String name) async {
    final client = _client();
    try {
      final res = await _open(name, client);
      return [for (final chunk in await res.toList()) ...chunk];
    } on SocketException {
      throw const CloudException('Sem conexão com a nuvem.');
    } finally {
      client.close();
    }
  }

  Future<void> _download(String name, File target) async {
    final client = _client();
    try {
      await (await _open(name, client)).pipe(target.openWrite());
    } on SocketException {
      throw const CloudException('A conexão caiu durante o download.');
    } finally {
      client.close();
    }
  }
}
