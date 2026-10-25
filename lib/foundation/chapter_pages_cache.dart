import 'package:venera/foundation/res.dart';

/// Recently loaded chapter page lists, keyed by source, comic and chapter.
///
/// Turning to a chapter the reader prefetched, or reopening one just read,
/// then skips the source's `loadComicPages` round trip (a JS call plus a
/// request) and its loading spinner. Concurrent loads of one chapter share a
/// single request. Entries expire after [ttl] because some sources sign their
/// image URLs, and only successful results are kept.
class ChapterPagesCache {
  ChapterPagesCache._();

  static final instance = ChapterPagesCache._();

  static const capacity = 32;

  static const ttl = Duration(minutes: 15);

  /// Clock override for tests.
  DateTime Function() now = DateTime.now;

  /// Insertion-ordered, so the first key is the least recently used.
  final _entries = <String, (DateTime, List<String>)>{};

  final _inFlight = <String, Future<Res<List<String>>>>{};

  static String keyOf(String? sourceKey, String cid, String? eid) =>
      '$sourceKey@$cid@$eid';

  /// The cached page list for [key], or null if missing or expired.
  List<String>? get(String key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (now().difference(entry.$1) > ttl) return null;
    // Re-insert to mark it most recently used.
    _entries[key] = entry;
    return entry.$2;
  }

  /// Returns the cached list for [key], or runs [loader] (once, however many
  /// callers ask at the same time) and caches a successful result.
  Future<Res<List<String>>> load(
    String key,
    Future<Res<List<String>>> Function() loader,
  ) {
    final cached = get(key);
    if (cached != null) {
      return Future.value(Res(cached));
    }
    final existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }
    final future = Future.sync(loader).then((res) {
      if (res.success) {
        _put(key, res.data);
      }
      return res;
    });
    _inFlight[key] = future;
    // Registered after the entry is stored: completion callbacks always run
    // later, so even a loader that throws at once cannot leave it behind.
    future.whenComplete(() => _inFlight.remove(key)).ignore();
    return future;
  }

  void invalidate(String key) {
    _entries.remove(key);
  }

  void clear() {
    _entries.clear();
  }

  void _put(String key, List<String> pages) {
    _entries.remove(key);
    _entries[key] = (now(), pages);
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}
