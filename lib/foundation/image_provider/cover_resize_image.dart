import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Decodes an image no larger than it takes to cover a [width] x [height]
/// pixel box, which is all a `BoxFit.cover` tile ever shows.
///
/// Comic tiles used to decode covers at full size; sources that use a whole
/// page as the cover put several megabytes per tile into the image cache.
/// [ResizeImage] can only fit an image inside a box, which would leave a
/// cover wider than its tile short of the tile's height, so this scales by
/// the larger of the two ratios instead. The aspect ratio is kept and the
/// image is never enlarged.
class CoverResizeImage extends ImageProvider<CoverResizeImageKey> {
  const CoverResizeImage(
    this.imageProvider, {
    required this.width,
    required this.height,
  });

  final ImageProvider<Object> imageProvider;

  /// Target box in physical pixels.
  final int width;

  final int height;

  /// Wraps [provider] for a tile of logical [size] at [devicePixelRatio]. The
  /// decode size is rounded up to 64 pixel steps so small layout changes, such
  /// as resizing a desktop window, keep reusing the decoded image. Returns
  /// [provider] itself when the size is unknown.
  static ImageProvider<Object> forTile(
    ImageProvider<Object> provider,
    Size size,
    double devicePixelRatio,
  ) {
    if (!size.width.isFinite || !size.height.isFinite || size.isEmpty) {
      return provider;
    }
    int bucket(double logical) =>
        math.max(1, (logical * devicePixelRatio / 64).ceil()) * 64;
    return CoverResizeImage(
      provider,
      width: bucket(size.width),
      height: bucket(size.height),
    );
  }

  /// The decode size of an image of [srcWidth] x [srcHeight] that has to
  /// cover a [width] x [height] box.
  @visibleForTesting
  static ui.TargetImageSize targetSize(
    int srcWidth,
    int srcHeight,
    int width,
    int height,
  ) {
    if (srcWidth <= 0 || srcHeight <= 0) {
      return const ui.TargetImageSize();
    }
    // Whichever side needs the larger scale decides it; only that side is
    // given, so the decoder derives the other from the aspect ratio. Compared
    // in integers to keep float rounding off the edge.
    if (width * srcHeight >= height * srcWidth) {
      return width >= srcWidth
          ? const ui.TargetImageSize()
          : ui.TargetImageSize(width: width);
    }
    return height >= srcHeight
        ? const ui.TargetImageSize()
        : ui.TargetImageSize(height: height);
  }

  @override
  ImageStreamCompleter loadImage(
    CoverResizeImageKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeCover(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      return decode(
        buffer,
        getTargetSize: (srcWidth, srcHeight) =>
            targetSize(srcWidth, srcHeight, width, height),
      );
    }

    final completer = imageProvider.loadImage(key._providerKey, decodeCover);
    // Same as ResizeImage: the inner provider evicts its own key on failure,
    // but the cache holds this one.
    completer.addEphemeralErrorListener((Object error, StackTrace? stack) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    return completer;
  }

  @override
  Future<CoverResizeImageKey> obtainKey(ImageConfiguration configuration) {
    Completer<CoverResizeImageKey>? completer;
    SynchronousFuture<CoverResizeImageKey>? result;
    imageProvider.obtainKey(configuration).then((Object key) {
      final value = CoverResizeImageKey._(key, width, height);
      if (completer == null) {
        // The inner key resolved synchronously.
        result = SynchronousFuture<CoverResizeImageKey>(value);
      } else {
        completer.complete(value);
      }
    });
    if (result != null) {
      return result!;
    }
    completer = Completer<CoverResizeImageKey>();
    return completer.future;
  }

  @override
  bool operator ==(Object other) {
    return other is CoverResizeImage &&
        other.imageProvider == imageProvider &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(imageProvider, width, height);

  @override
  String toString() => 'CoverResizeImage($imageProvider, $width×$height)';
}

@immutable
class CoverResizeImageKey {
  const CoverResizeImageKey._(this._providerKey, this._width, this._height);

  final Object _providerKey;
  final int _width;
  final int _height;

  @override
  bool operator ==(Object other) {
    return other is CoverResizeImageKey &&
        other._providerKey == _providerKey &&
        other._width == _width &&
        other._height == _height;
  }

  @override
  int get hashCode => Object.hash(_providerKey, _width, _height);
}
