import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/audio/audio_engine.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_service.dart';
import 'package:txvziwm/widgets/player_bar.dart';

/// 音量条的百分比提示：拖动与「快捷键/菜单调音量」两种入口都必须看得见数值。
///
/// 回归背景：提示原先仅在拖动（`_dragValue != null`）时出现，用菜单 ⌘↑/⌘↓ 调音量
/// 时滑块位置会同步，但看不到调整后的数值。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SilentEngine engine;
  late PlayerService player;

  setUp(() {
    engine = _SilentEngine();
    player = PlayerService(engine, playQueue: PlayQueue());
  });

  tearDown(() => player.dispose());

  Future<void> pumpBar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerBar(player: player, theme: ThemeData(), onSeek: (_) {}),
        ),
      ),
    );
  }

  Finder percent() => find.textContaining('%');

  testWidgets('快捷键调音量：显示百分比提示，约 1.2s 后自动隐藏', (tester) async {
    await player.setVolume(0.3); // 基准音量（此时 UI 未挂载，不该弹提示）
    await pumpBar(tester);
    expect(percent(), findsNothing);

    await player.adjustVolume(0.1); // 菜单 ⌘↑
    await tester.pump();

    expect(find.text('40%'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(percent(), findsNothing);
  });

  testWidgets('连续按快捷键：提示重新计时并显示最新数值', (tester) async {
    await player.setVolume(0.3);
    await pumpBar(tester);

    await player.adjustVolume(0.1);
    await tester.pump(const Duration(milliseconds: 800));
    await player.adjustVolume(0.1); // 第二次按下：应重新计时
    await tester.pump();

    expect(find.text('50%'), findsOneWidget);

    // 距第二次按键 800ms：仍在提示期内（说明计时被重置，未沿用第一次的截止点）
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('50%'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    expect(percent(), findsNothing);
  });

  testWidgets('音量调到底（0.0）：显示 0%', (tester) async {
    await player.setVolume(0.05);
    await pumpBar(tester);

    await player.adjustVolume(-0.1); // 菜单 ⌘↓
    await tester.pump();

    expect(find.text('0%'), findsOneWidget);
  });
}

/// 最小假引擎：这些用例只关心音量通路，其余成员按 no-op / 空值处理。
class _SilentEngine implements AudioEngine {
  double volume = 1.0;

  @override
  String? get loadedPath => null;

  @override
  bool get isPlaying => false;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => null;

  @override
  Stream<Duration> get positionStream => Stream<Duration>.empty();

  @override
  Stream<Duration?> get durationStream => Stream<Duration?>.empty();

  @override
  Stream<bool> get playingStream => Stream<bool>.empty();

  @override
  Stream<void> get completionStream => Stream<void>.empty();

  @override
  Stream<AudioEngineError> get errorStream => Stream<AudioEngineError>.empty();

  @override
  Future<void> load(String path, {Duration? initialPosition}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> release() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async => this.volume = volume;

  @override
  Future<void> setLoopSingle(bool loop) async {}

  @override
  Future<void> dispose() async {}
}
