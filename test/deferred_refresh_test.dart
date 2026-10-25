import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/components.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.notifier, this.onRefresh);

  final ChangeNotifier notifier;

  final VoidCallback onRefresh;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with DeferredRefreshMixin<_Probe> {
  void _changed() => refreshWhenVisible(widget.onRefresh);

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_changed);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('list');
}

void main() {
  testWidgets('refreshes run at once while the page is visible', (
    tester,
  ) async {
    final notifier = ChangeNotifier();
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(home: _Probe(notifier, () => refreshes++)),
    );

    notifier.notifyListeners();
    expect(refreshes, 1);
  });

  testWidgets('a covered page refreshes once when it is shown again', (
    tester,
  ) async {
    final notifier = ChangeNotifier();
    var refreshes = 0;
    void onRefresh() => refreshes++;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: _Probe(notifier, onRefresh),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('reader')),
    );
    await tester.pumpAndSettle();

    // Progress saves while the opaque route is on top.
    notifier.notifyListeners();
    notifier.notifyListeners();
    notifier.notifyListeners();
    expect(refreshes, 0);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(refreshes, 1);

    notifier.notifyListeners();
    expect(refreshes, 2);
  });
}
