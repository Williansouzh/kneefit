import 'package:fitknee/defaults.dart';
import 'package:fitknee/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ids criados de seguida não se repetem', () {
    final ids = [for (var i = 0; i < 10000; i++) newId()];
    expect(ids.toSet().length, ids.length);
  });

  test('o plano padrão não tem exercícios com o mesmo id', () {
    final ids = [for (final day in defaultPlan()) for (final e in day.exercises) e.id];
    expect(ids.toSet().length, ids.length);
  });
}
