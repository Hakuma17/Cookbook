import 'package:flutter_test/flutter_test.dart';
import 'package:cookbook/stores/favorite_store.dart';

void main() {
  group('FavoriteStore', () {
    test('initial and basic operations', () async {
      final store = FavoriteStore(initialIds: {1, 2, -3});
      expect(store.ids.contains(-3), isFalse, reason: 'กรอง id <= 0');
      expect(store.length, 2);

      await store.set(3, true);
      expect(store.contains(3), isTrue);

      await store.toggle(2, false);
      expect(store.contains(2), isFalse);

      await store.replaceWith([10, 20, 0]);
      expect(store.ids, {10, 20});

      await store.removeMany([10, 999]);
      expect(store.ids, {20});

      await store.clear();
      expect(store.isEmpty, isTrue);
    });
  });
}
