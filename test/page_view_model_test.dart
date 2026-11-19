import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/viewmodels/page_view_model.dart';

class _TestViewModel extends PageViewModel {
  int latest = 0;

  void start(Stream<int> stream) {
    trackStream(stream, (value) {
      latest = value;
      safeNotify();
    });
  }
}

void main() {
  test('trackStream 转发数据，dispose 后取消订阅且不再通知', () async {
    final controller = StreamController<int>.broadcast();
    final viewModel = _TestViewModel()..start(controller.stream);
    var notified = 0;
    viewModel.addListener(() => notified++);

    controller.add(1);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.latest, 1);
    expect(notified, 1);
    expect(controller.hasListener, isTrue);

    viewModel.dispose();
    expect(controller.hasListener, isFalse);

    controller.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.latest, 1);
    expect(notified, 1);

    await controller.close();
  });
}
