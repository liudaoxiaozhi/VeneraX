import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/image_provider/base_image_provider.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';

class _ImageFile implements File {
  _ImageFile(this.read);

  final Future<Uint8List> Function() read;

  @override
  Future<Uint8List> readAsBytes() => read();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() => expect(CachedImageProvider.loadingCount, 0));

  testWidgets('holds eight slots until reads finish and queues the next read', (
    tester,
  ) async {
    final reads = <Completer<Uint8List>>[];
    final events = StreamController<ImageChunkEvent>.broadcast();
    addTearDown(events.close);
    await IOOverrides.runZoned(() async {
      final loads = List.generate(
        9,
        (i) => CachedImageProvider('file://cover-$i').load(events, () {}),
      );
      await tester.pump();
      final initialReads = reads.length;
      final initialCount = CachedImageProvider.loadingCount;
      reads.first.complete(Uint8List.fromList([1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final afterRelease = reads.length;
      for (final read in reads.skip(1)) {
        read.complete(Uint8List.fromList([1]));
      }
      await tester.pump();
      await Future.wait(loads);
      expect(initialReads, 8);
      expect(initialCount, 8);
      expect(afterRelease, 9);
    }, createFile: (_) => _ImageFile(() {
      final read = Completer<Uint8List>();
      reads.add(read);
      return read.future;
    }));
  });

  testWidgets('a freed slot goes to the queued read without a delay', (
    tester,
  ) async {
    final reads = <Completer<Uint8List>>[];
    final events = StreamController<ImageChunkEvent>.broadcast();
    addTearDown(events.close);
    await IOOverrides.runZoned(() async {
      final loads = List.generate(
        9,
        (i) => CachedImageProvider('file://cover-$i').load(events, () {}),
      );
      await tester.pump();
      reads.first.complete(Uint8List.fromList([1]));
      // No time passes: the slot is handed over, not found by polling.
      await tester.pump();
      expect(reads.length, 9);
      for (final read in reads.skip(1)) {
        read.complete(Uint8List.fromList([1]));
      }
      await tester.pump();
      await Future.wait(loads);
    }, createFile: (_) => _ImageFile(() {
      final read = Completer<Uint8List>();
      reads.add(read);
      return read.future;
    }));
  });

  testWidgets('a load cancelled while queued passes its slot on', (
    tester,
  ) async {
    final reads = <Completer<Uint8List>>[];
    final events = StreamController<ImageChunkEvent>.broadcast();
    addTearDown(events.close);
    final stopped = StateError('stopped');
    var stopQueued = false;
    await IOOverrides.runZoned(() async {
      final loads = List.generate(
        8,
        (i) => CachedImageProvider('file://cover-$i').load(events, () {}),
      );
      final cancelled = expectLater(
        CachedImageProvider('file://cancelled').load(events, () {
          if (stopQueued) throw stopped;
        }),
        throwsA(same(stopped)),
      );
      final next = CachedImageProvider('file://next').load(events, () {});
      await tester.pump();
      expect(reads.length, 8);
      stopQueued = true;
      reads.first.complete(Uint8List.fromList([1]));
      await tester.pump();
      await cancelled;
      // The cancelled load never read; the one behind it got the slot.
      expect(reads.length, 9);
      for (final read in reads.skip(1)) {
        read.complete(Uint8List.fromList([1]));
      }
      await tester.pump();
      await Future.wait([...loads, next]);
    }, createFile: (_) => _ImageFile(() {
      final read = Completer<Uint8List>();
      reads.add(read);
      return read.future;
    }));
  });

  test('a cancelled load does not start reading or acquire a slot', () async {
    var reads = 0;
    final events = StreamController<ImageChunkEvent>.broadcast();
    addTearDown(events.close);
    final stopped = StateError('stopped');
    await IOOverrides.runZoned(() async {
      await expectLater(
        const CachedImageProvider('file://cover').load(events, () => throw stopped),
        throwsA(same(stopped)),
      );
      expect(reads, 0);
    }, createFile: (_) => _ImageFile(() async {
      reads++;
      return Uint8List.fromList([1]);
    }));
  });

  test('missing local files report a permanent error and release their slot', () async {
    final events = StreamController<ImageChunkEvent>.broadcast();
    addTearDown(events.close);
    await IOOverrides.runZoned(() async {
      await expectLater(
        const CachedImageProvider('file://missing').load(events, () {}),
        throwsA(isA<ImageLoadingPermanentException>()),
      );
    }, createFile: (_) => _ImageFile(() async {
      throw const FileSystemException('File not found', 'missing');
    }));
  });
}
