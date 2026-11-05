import 'dart:async';
import 'dart:isolate';

typedef WorkerProcessor<Q, R> = R Function(Q request);
typedef WorkerFactory<C, Q, R> = WorkerProcessor<Q, R> Function(
    C configuration);

class _Start<C, Q, R> {
  const _Start(this.replies, this.configuration, this.factory);
  final SendPort replies;
  final C configuration;
  final WorkerFactory<C, Q, R> factory;
}

class _Stop {
  const _Stop();
}

class _Reply {
  const _Reply.success(this.value)
      : error = null,
        stack = null;
  const _Reply.failure(this.error, this.stack) : value = null;
  final Object? value;
  final String? error, stack;
}

void _workerMain<C, Q, R>(_Start<C, Q, R> start) {
  late final WorkerProcessor<Q, R> process;
  try {
    process = start.factory(start.configuration);
  } catch (error, stack) {
    start.replies.send(_Reply.failure(error.toString(), stack.toString()));
    return;
  }
  final commands = ReceivePort();
  start.replies.send(commands.sendPort);
  commands.listen((message) {
    if (message is _Stop) {
      commands.close();
      return;
    }
    try {
      start.replies.send(_Reply.success(process(message as Q)));
    } catch (error, stack) {
      start.replies.send(_Reply.failure(error.toString(), stack.toString()));
    }
  });
}

/// One long-lived worker, one request in flight, and a graceful native-resource
/// handoff: close waits for the current request and worker exit before returning.
class PersistentWorker<C, Q, R> {
  Isolate? _isolate;
  ReceivePort? _messages;
  StreamSubscription<dynamic>? _subscription;
  SendPort? _commands;
  Completer<void>? _ready;
  final _exited = Completer<void>();
  Completer<R>? _pending;
  Future<void>? _starting, _closingFuture;
  bool _closing = false;

  bool get isStarted => _commands != null && !_exited.isCompleted && !_closing;

  Future<void> start(C configuration, WorkerFactory<C, Q, R> factory) {
    if (_closing) return Future.error(StateError('Worker has been closed.'));
    return _starting ??= _start(configuration, factory);
  }

  Future<void> _start(C configuration, WorkerFactory<C, Q, R> factory) async {
    final messages = _messages = ReceivePort();
    final ready = _ready = Completer<void>();
    // A very fast startup failure can arrive before Isolate.spawn completes.
    unawaited(ready.future.catchError((Object _) {}));
    _subscription = messages.listen(_onMessage);
    try {
      _isolate = await Isolate.spawn<_Start<C, Q, R>>(
        _workerMain<C, Q, R>,
        _Start(messages.sendPort, configuration, factory),
        onError: messages.sendPort,
        onExit: messages.sendPort,
        errorsAreFatal: true,
      );
      await ready.future;
    } catch (_) {
      if (_isolate == null && !_exited.isCompleted) _exited.complete();
      rethrow;
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (!(_ready?.isCompleted ?? true)) _ready!.completeError(error, stack);
    final pending = _pending;
    _pending = null;
    if (pending != null) pending.completeError(error, stack);
  }

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      _commands = message;
      if (!(_ready?.isCompleted ?? true)) _ready!.complete();
    } else if (message is _Reply) {
      if (message.error != null) {
        _fail(StateError(message.error!),
            StackTrace.fromString(message.stack ?? ''));
      } else {
        final pending = _pending;
        _pending = null;
        pending?.complete(message.value as R);
      }
    } else if (message == null) {
      if (!_exited.isCompleted) _exited.complete();
      _fail(StateError('Worker exited.'), StackTrace.current);
    } else if (message is List && message.length == 2) {
      _fail(StateError(message[0].toString()),
          StackTrace.fromString(message[1].toString()));
    }
  }

  Future<R> run(Q request) {
    if (!isStarted) return Future.error(StateError('Worker is not ready.'));
    if (_pending != null) return Future.error(StateError('Worker is busy.'));
    final pending = _pending = Completer<R>();
    try {
      _commands!.send(request);
    } catch (error, stack) {
      _pending = null;
      pending.completeError(error, stack);
    }
    return pending.future;
  }

  Future<void> close() {
    _closing = true;
    return _closingFuture ??= _close();
  }

  Future<void> _close() async {
    try {
      await _starting;
    } catch (_) {
      // Startup failure was reported to the caller.
    }
    try {
      await _pending?.future;
    } catch (_) {
      // Request failure was reported to the caller.
    }
    if (_isolate != null && !_exited.isCompleted) {
      _commands?.send(const _Stop());
      await _exited.future;
    }
    await _subscription?.cancel();
    _messages?.close();
    _commands = null;
    _isolate = null;
  }
}
