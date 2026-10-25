import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/chapter_pages_cache.dart';
import 'package:venera/foundation/res.dart';

void main() {
  final cache = ChapterPagesCache.instance;
  var clock = DateTime(2026);

  setUp(() {
    cache.clear();
    clock = DateTime(2026);
    cache.now = () => clock;
  });

  tearDown(() {
    cache.clear();
    cache.now = DateTime.now;
  });

  test('a loaded chapter is served from memory afterwards', () async {
    var calls = 0;
    Future<Res<List<String>>> loader() async {
      calls++;
      return const Res(['a', 'b']);
    }

    expect((await cache.load('k', loader)).data, ['a', 'b']);
    expect((await cache.load('k', loader)).data, ['a', 'b']);
    expect(calls, 1);
  });

  test('concurrent loads of one chapter share a request', () async {
    var calls = 0;
    Future<Res<List<String>>> loader() async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return const Res(['a']);
    }

    final results = await Future.wait([
      cache.load('k', loader),
      cache.load('k', loader),
    ]);
    expect(results.map((r) => r.data), [
      ['a'],
      ['a'],
    ]);
    expect(calls, 1);
  });

  test('entries expire after the ttl', () async {
    await cache.load('k', () async => const Res(['a']));
    clock = clock.add(ChapterPagesCache.ttl + const Duration(seconds: 1));
    expect(cache.get('k'), isNull);
  });

  test('failures are not cached', () async {
    var calls = 0;
    Future<Res<List<String>>> loader() async {
      calls++;
      return const Res.error('boom');
    }

    expect((await cache.load('k', loader)).error, isTrue);
    expect((await cache.load('k', loader)).error, isTrue);
    expect(calls, 2);
  });

  test('a loader that throws at once does not block later loads', () async {
    await expectLater(
      cache.load('k', () => throw StateError('sync')),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);
    expect((await cache.load('k', () async => const Res(['a']))).data, ['a']);
  });

  test('the least recently used chapter is dropped past capacity', () async {
    for (var i = 0; i < ChapterPagesCache.capacity; i++) {
      await cache.load('k$i', () async => Res(['$i']));
    }
    // Touch the oldest so the second oldest becomes the eviction candidate.
    expect(cache.get('k0'), ['0']);
    await cache.load('extra', () async => const Res(['x']));
    expect(cache.get('k0'), ['0']);
    expect(cache.get('k1'), isNull);
  });
}
