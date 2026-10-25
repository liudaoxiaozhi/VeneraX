import 'dart:async' show Completer, Future;
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/network/images.dart';
import 'package:venera/utils/io.dart';
import 'base_image_provider.dart';
import 'cached_image.dart' as image_provider;

class CachedImageProvider
    extends BaseImageProvider<image_provider.CachedImageProvider> {
  /// Image provider for normal image.
  ///
  /// [url] is the url of the image. Local file path is also supported.
  const CachedImageProvider(this.url, {
    this.headers,
    this.sourceKey,
    this.cid,
    this.fallbackToLocalCover = false,
  });

  final String url;

  final Map<String, String>? headers;

  final String? sourceKey;

  final String? cid;

  // Use local cover if network image fails to load.
  final bool fallbackToLocalCover;

  /// Slots in use, including ones already handed to a queued load.
  static int loadingCount = 0;

  static const _kMaxLoadingCount = 8;

  /// Loads waiting for a slot, oldest first.
  static final _waiting = Queue<Completer<void>>();

  /// Takes a slot, waiting in line if all are busy. A freed slot goes straight
  /// to the next load in line: polling for one every 100ms used to bring even
  /// disk-cached covers in eight at a time, with a pause between batches.
  static Future<void> _acquireSlot(void Function() checkStop) async {
    if (loadingCount < _kMaxLoadingCount) {
      loadingCount++;
      return;
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future;
    try {
      // The tile may have scrolled away while this load waited.
      checkStop();
    } catch (_) {
      _releaseSlot();
      rethrow;
    }
  }

  static void _releaseSlot() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      loadingCount--;
    }
  }

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    checkStop();
    await _acquireSlot(checkStop);
    try {
      if(url.startsWith("file://")) {
        var file = File(url.substring(7));
        return await file.readAsBytes();
      }
      await for (var progress in ImageDownloader.loadThumbnail(url, sourceKey, cid)) {
        checkStop();
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: progress.currentBytes,
          expectedTotalBytes: progress.totalBytes,
        ));
        if(progress.imageBytes != null) {
          return progress.imageBytes!;
        }
      }
      throw "Error: Empty response body.";
    }
    catch(e) {
      checkStop();
      if (fallbackToLocalCover && sourceKey != null && cid != null) {
        final localComic = LocalManager().find(
          cid!,
          ComicType.fromKey(sourceKey!),
        );
        if (localComic != null) {
          var file = localComic.coverFile;
          if (await file.exists()) {
            var data = await file.readAsBytes();
            if (data.isNotEmpty) {
              return data;
            }
          }
        }
      }
      if (url.startsWith('file://') && e is FileSystemException) {
        throw ImageLoadingPermanentException(e.toString());
      }
      rethrow;
    }
    finally {
      _releaseSlot();
    }
  }

  @override
  Future<CachedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => url + (sourceKey ?? "") + (cid ?? "");

  @override
  String get diskCacheKey =>
      ImageDownloader.thumbnailCacheKey(url, sourceKey, cid);

  @override
  String? get fallbackUrl => url;
}
