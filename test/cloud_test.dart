// Backup no R2 de ponta a ponta, contra o Worker rodando. Pulado sem CLOUD_URL e CLOUD_TOKEN:
//   (cd cloud && TOKEN=... BUCKET_NAME=fitknee-e2e PORT=8788 npm run local)
//   CLOUD_URL=http://localhost:8788 CLOUD_TOKEN=... flutter test test/cloud_test.dart
import 'dart:io';

import 'package:fitknee/models.dart';
import 'package:fitknee/services/cloud.dart';
import 'package:fitknee/store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final url = Platform.environment['CLOUD_URL'];
  final token = Platform.environment['CLOUD_TOKEN'];
  final skip = url == null || token == null ? 'Defina CLOUD_URL e CLOUD_TOKEN para rodar' : null;

  Future<(Store, Cloud)> phone() async {
    final store = Store(await Directory.systemTemp.createTemp('fitknee_cloud_'));
    await store.load();
    final cloud = Cloud(store, delay: const Duration(milliseconds: 50));
    await cloud.load();
    return (store, cloud);
  }

  test('sobe fotos, vídeo e dados; outro celular restaura; excluir apaga da nuvem', () async {
    final (store, cloud) = await phone();
    await expectLater(cloud.configure(url!, 'token-errado-mas-comprido'), throwsA(isA<CloudException>()));
    expect(cloud.configured, isFalse);
    await cloud.configure(url, token!);

    await store.media('photo_a_front.jpg').writeAsBytes([0xff, 0xd8, 1, 2, 3]);
    await store.media('photo_a_side.jpg').writeAsBytes([0xff, 0xd8, 4, 5]);
    final video = List<int>.generate(3 * 1024 * 1024, (i) => i % 251); // 3 MB, em stream
    await store.media('video_1.mp4').writeAsBytes(video);
    store.addPhotoSet(PhotoSet(date: DateTime(2026, 10, 1), photos: {PhotoPose.front: 'photo_a_front.jpg', PhotoPose.side: 'photo_a_side.jpg'}));
    store.addVideo(VideoEntry(file: 'video_1.mp4', date: DateTime(2026, 10, 1), title: 'Semana 1'));
    store.setWeight(DateTime(2026, 10, 1), 63.4);

    await cloud.sync();
    expect(cloud.error, isNull);
    expect(cloud.uploaded, {'photo_a_front.jpg', 'photo_a_side.jpg', 'video_1.mp4'});

    // Celular novo: restaura tudo, com os arquivos idênticos.
    final (store2, cloud2) = await phone();
    await cloud2.configure(url, token);
    expect(await cloud2.restore(), 3);
    expect(store2.weights.single.kg, 63.4);
    expect(store2.photoSets.single.photos.length, 2);
    expect(store2.videos.single.title, 'Semana 1');
    expect(await store2.media('video_1.mp4').readAsBytes(), video);
    expect(await store2.media('photo_a_front.jpg').readAsBytes(), [0xff, 0xd8, 1, 2, 3]);

    // Excluir o check-in no primeiro celular apaga as fotos do bucket na próxima sincronização
    // (que acontece sozinha, logo depois da mudança).
    await store.deletePhotoSet(store.photoSets.single);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    while (cloud.syncing) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(cloud.uploaded, {'video_1.mp4'});
    final (store3, cloud3) = await phone();
    await cloud3.configure(url, token);
    expect(await cloud3.restore(), 1);
    expect(store3.photoSets, isEmpty);
    expect(store3.videos, hasLength(1));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
