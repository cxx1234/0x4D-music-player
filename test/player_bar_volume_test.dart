import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/player_service.dart';
import 'package:txvziwm/widgets/player_bar.dart';

import 'helpers/silent_audio_engine.dart';

/// 音量条的百分比提示：拖动与「快捷键/菜单调音量」两种入口都必须看得见数值。
///
/// 回归背景：提示原先仅在拖动（`_dragValue != null`）时出现，用菜单 ⌘↑/⌘↓ 调音量
/// 时滑块位置会同步，但看不到调整后的数值。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SilentAudioEngine engine;
  late PlayerService player;

  setUp(() {
    engine = SilentAudioEngine();
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
