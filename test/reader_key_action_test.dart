import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/pages/reader/reader.dart';

void main() {
  ReaderKeyAction? press(
    LogicalKeyboardKey key, {
    bool shift = false,
    bool repeat = false,
  }) => readerKeyAction(key, shift: shift, repeat: repeat);

  test('page turner keys move a screen either way', () {
    expect(press(LogicalKeyboardKey.pageDown), ReaderKeyAction.nextScreen);
    expect(press(LogicalKeyboardKey.space), ReaderKeyAction.nextScreen);
    expect(press(LogicalKeyboardKey.pageUp), ReaderKeyAction.previousScreen);
    expect(
      press(LogicalKeyboardKey.space, shift: true),
      ReaderKeyAction.previousScreen,
    );
  });

  test('held page turner keys keep turning', () {
    expect(
      press(LogicalKeyboardKey.pageDown, repeat: true),
      ReaderKeyAction.nextScreen,
    );
    expect(
      press(LogicalKeyboardKey.space, shift: true, repeat: true),
      ReaderKeyAction.previousScreen,
    );
  });

  test('jump keys act on the first press only', () {
    expect(press(LogicalKeyboardKey.home), ReaderKeyAction.firstPage);
    expect(press(LogicalKeyboardKey.end), ReaderKeyAction.lastPage);
    expect(
      press(LogicalKeyboardKey.bracketLeft),
      ReaderKeyAction.previousChapter,
    );
    expect(press(LogicalKeyboardKey.bracketRight), ReaderKeyAction.nextChapter);
    for (final key in [
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.bracketLeft,
      LogicalKeyboardKey.bracketRight,
    ]) {
      expect(press(key, repeat: true), isNull);
    }
  });

  test('arrow keys are left to the reading mode', () {
    for (final key in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ]) {
      expect(press(key), isNull);
    }
  });
}
