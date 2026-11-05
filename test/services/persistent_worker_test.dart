import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_ho_tro_nguoi_khiem_thi/services/persistent_worker.dart';

int Function(int) counter(int initial) {
  var value = initial;
  return (delta) {
    if (delta < 0) throw ArgumentError('negative request');
    value += delta;
    return value;
  };
}

int Function(int) slowCounter(int initial) => (delay) {
      sleep(Duration(milliseconds: delay));
      return initial + delay;
    };

int Function(int) brokenFactory(int _) => throw StateError('startup failed');

void main() {
  test('State is retained across requests and request errors are recoverable',
      () async {
    final worker = PersistentWorker<int, int, int>();
    addTearDown(worker.close);
    await worker.start(1, counter);
    expect(await worker.run(2), 3);
    expect(await worker.run(4), 7);
    await expectLater(worker.run(-1), throwsStateError);
    expect(await worker.run(1), 8);
  });

  test('Busy requests are rejected and close drains the current request',
      () async {
    final worker = PersistentWorker<int, int, int>();
    await worker.start(10, slowCounter);
    final running = worker.run(40);
    await expectLater(worker.run(1), throwsStateError);
    final closing = worker.close();
    await expectLater(worker.run(1), throwsStateError);
    expect(await running, 50);
    await closing;
    await worker.close();
    expect(worker.isStarted, isFalse);
  });

  test('Startup failure is reported and all ports can be closed', () async {
    final worker = PersistentWorker<int, int, int>();
    await expectLater(worker.start(0, brokenFactory), throwsStateError);
    await worker.close();
    expect(worker.isStarted, isFalse);
  });

  test('Close during startup waits for the worker to exit', () async {
    final worker = PersistentWorker<int, int, int>();
    final starting = worker.start(0, counter);
    final closing = worker.close();
    await starting;
    await closing;
    expect(worker.isStarted, isFalse);
  });

  test('A closed worker cannot be restarted', () async {
    final worker = PersistentWorker<int, int, int>();
    await worker.close();
    await expectLater(worker.start(0, counter), throwsStateError);
  });
}
