import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/image_provider/cover_resize_image.dart';

void main() {
  (int?, int?) target(int srcWidth, int srcHeight, int width, int height) {
    final size = CoverResizeImage.targetSize(
      srcWidth,
      srcHeight,
      width,
      height,
    );
    return (size.width, size.height);
  }

  test('a tall cover is scaled to the tile width', () {
    // Page used as a cover: 1200x1700 into a 320x384 tile decodes 320x454.
    expect(target(1200, 1700, 320, 384), (320, null));
  });

  test('a wide cover still fills the tile height', () {
    // Fitting by width alone would leave it 180 pixels tall and blurry; this
    // decodes 683x384.
    expect(target(1600, 900, 320, 384), (null, 384));
  });

  test('a cover smaller than the tile is never enlarged', () {
    expect(target(200, 280, 320, 384), (null, null));
  });

  test('an unknown size decodes as is', () {
    expect(target(0, 0, 320, 384), (null, null));
  });

  test('tile sizes round up to 64 pixel steps', () {
    final inner = MemoryImage(kTransparentImage);
    final a = CoverResizeImage.forTile(inner, const Size(98, 136), 2.75);
    final b = CoverResizeImage.forTile(inner, const Size(100, 138), 2.75);
    expect(a, isA<CoverResizeImage>());
    expect((a as CoverResizeImage).width, 320);
    expect(a.height, 384);
    // A slightly different layout reuses the same decoded image.
    expect(a, b);
  });

  testWidgets('decodes the image at the reduced size', (tester) async {
    final image = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 40, 80),
        Paint()..color = const Color(0xFF336699),
      );
      final source = await recorder.endRecording().toImage(40, 80);
      final png = await source.toByteData(format: ui.ImageByteFormat.png);
      source.dispose();
      final provider = CoverResizeImage(
        MemoryImage(png!.buffer.asUint8List()),
        width: 10,
        height: 10,
      );
      final completer = Completer<ImageInfo>();
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (info, _) => completer.complete(info),
              onError: completer.completeError,
            ),
          );
      return completer.future;
    });
    expect(image!.image.width, 10);
    expect(image.image.height, 20);
  });

  test('an unbounded tile leaves the provider alone', () {
    final inner = MemoryImage(kTransparentImage);
    expect(
      CoverResizeImage.forTile(inner, const Size(double.infinity, 136), 2),
      same(inner),
    );
  });
}

final kTransparentImage = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
