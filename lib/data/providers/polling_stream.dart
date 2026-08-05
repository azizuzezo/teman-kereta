import 'dart:async';

/// Turns a one-shot `fetch` into a broadcast [Stream] that re-fetches every
/// [interval] while at least one listener is subscribed, and stops polling
/// once the last listener cancels. Used by providers backed by feeds that
/// must be pulled over HTTP (GTFS-Realtime, REST) rather than pushed.
class PollingBroadcaster<T> {
  PollingBroadcaster({
    required this._fetch,
    required Duration interval,
    required this._onError,
  }) : _interval = interval {
    _controller = StreamController<T>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final Future<T> Function() _fetch;
  final Duration _interval;
  final void Function(Object error, StackTrace stackTrace) _onError;
  late final StreamController<T> _controller;
  Timer? _timer;
  bool _fetching = false;

  Stream<T> get stream => _controller.stream;

  void _start() {
    unawaited(_tick());
    _timer = Timer.periodic(_interval, (_) => unawaited(_tick()));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_fetching || _controller.isClosed) {
      return;
    }
    _fetching = true;
    try {
      final value = await _fetch();
      if (!_controller.isClosed) {
        _controller.add(value);
      }
    } on Object catch (error, stackTrace) {
      _onError(error, stackTrace);
    } finally {
      _fetching = false;
    }
  }

  Future<void> dispose() async {
    _stop();
    await _controller.close();
  }
}
