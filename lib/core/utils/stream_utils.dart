import 'dart:async';

extension SwitchMapExtension<T> on Stream<T> {
  /// Igual que `switchMap` de Rx: por cada evento se cancela el flujo interno
  /// anterior y se escucha el nuevo.
  Stream<R> switchMap<R>(Stream<R> Function(T value) mapper) {
    late StreamController<R> controller;
    StreamSubscription<T>? outer;
    StreamSubscription<R>? inner;
    var outerDone = false;

    controller = StreamController<R>(
      onListen: () {
        outer = listen(
          (value) {
            inner?.cancel();
            inner = mapper(value).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                inner = null;
                if (outerDone) controller.close();
              },
            );
          },
          onError: controller.addError,
          onDone: () {
            outerDone = true;
            if (inner == null) controller.close();
          },
        );
      },
      onPause: () {
        outer?.pause();
        inner?.pause();
      },
      onResume: () {
        outer?.resume();
        inner?.resume();
      },
      onCancel: () async {
        await inner?.cancel();
        await outer?.cancel();
      },
    );
    return controller.stream;
  }
}

/// Combina una lista de flujos y emite la lista de los últimos valores
/// cuando todos han emitido al menos una vez.
Stream<List<T>> combineLatestList<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) return Stream.value(<T>[]);
  late StreamController<List<T>> controller;
  final subscriptions = <StreamSubscription<T>>[];
  final values = List<T?>.filled(streams.length, null);
  final hasValue = List<bool>.filled(streams.length, false);
  var completed = 0;

  controller = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subscriptions.add(
          streams[i].listen(
            (value) {
              values[i] = value;
              hasValue[i] = true;
              if (hasValue.every((v) => v)) {
                controller.add(values.cast<T>().toList(growable: false));
              }
            },
            onError: controller.addError,
            onDone: () {
              completed++;
              if (completed == streams.length) controller.close();
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    },
  );
  return controller.stream;
}
