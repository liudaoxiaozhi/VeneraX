part of 'components.dart';

/// Holds back listener-driven refreshes while the page is covered by an
/// opaque route, such as the reader.
///
/// Reading saves progress about once a second, and every save notifies the
/// history listeners; pages left underneath the reader used to re-run their
/// queries and rebuild on each one, on the UI thread the reader needs. Routes
/// covered by an opaque route have their tickers muted, so while that is the
/// case [refreshWhenVisible] only records the request, and the refresh runs
/// once when the page is shown again.
mixin DeferredRefreshMixin<T extends StatefulWidget> on State<T> {
  bool _isVisible = true;

  final _pendingRefreshes = <VoidCallback>{};

  /// Runs [refresh] now if the page is visible, otherwise once it becomes
  /// visible again. Repeated requests with the same callback collapse into one.
  void refreshWhenVisible(VoidCallback refresh) {
    if (!mounted) return;
    if (_isVisible) {
      refresh();
    } else {
      _pendingRefreshes.add(refresh);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depending on TickerMode here is what calls this again when the
    // covering route goes away.
    _isVisible = TickerMode.valuesOf(context).enabled;
    if (_isVisible && _pendingRefreshes.isNotEmpty) {
      final pending = _pendingRefreshes.toList();
      _pendingRefreshes.clear();
      for (final refresh in pending) {
        refresh();
      }
    }
  }
}
