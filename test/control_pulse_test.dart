import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/playback_feedback_service.dart';
import 'package:txvziwm/core/services/player_service.dart';
import 'package:txvziwm/widgets/control_pulse.dart';
import 'package:txvziwm/widgets/player_controls.dart';

import 'helpers/silent_audio_engine.dart';

/// 控件脉冲：外部操作（快捷键 / 媒体键）时，屏幕上的对应按钮也要有反馈。
void main() {
  late ValueNotifier<PlaybackPulse?> pulses;

  setUp(() => pulses = ValueNotifier<PlaybackPulse?>(null));
  tearDown(() => pulses.dispose());

  Future<void> pumpPulse(WidgetTester tester, PlaybackAction action) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ControlPulse(
              pulses: pulses,
              action: action,
              builder: (context, pulsing) => Text(pulsing ? 'pulsing' : 'idle'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('匹配动作：亮起，脉冲时长走完自动复位', (tester) async {
    await pumpPulse(tester, PlaybackAction.next);
    expect(find.text('idle'), findsOneWidget);

    pulses.value = const PlaybackPulse(seq: 1, action: PlaybackAction.next);
    await tester.pump();
    expect(find.text('pulsing'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('pulsing'), findsOneWidget, reason: '脉冲期间不应提前复位');

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('idle'), findsOneWidget);
  });

  testWidgets('不匹配的动作不触发', (tester) async {
    await pumpPulse(tester, PlaybackAction.next);

    pulses.value = const PlaybackPulse(
      seq: 1,
      action: PlaybackAction.playPause,
    );
    await tester.pump();
    expect(find.text('idle'), findsOneWidget);

    // 反向确认：同一个 notifier 换成匹配动作时才响应。
    pulses.value = const PlaybackPulse(seq: 2, action: PlaybackAction.next);
    await tester.pump();
    expect(find.text('pulsing'), findsOneWidget);
  });

  testWidgets('连续同动作：每次都重新播放（seq 变化）', (tester) async {
    await pumpPulse(tester, PlaybackAction.next);

    pulses.value = const PlaybackPulse(seq: 1, action: PlaybackAction.next);
    await tester.pump(const Duration(milliseconds: 100));

    // 第二次按下：动画尚未走完就重新开始，仍处于 pulsing。
    pulses.value = const PlaybackPulse(seq: 2, action: PlaybackAction.next);
    await tester.pump();
    expect(find.text('pulsing'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('pulsing'), findsOneWidget, reason: '重新计时，未到 180ms');

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('idle'), findsOneWidget);
  });

  testWidgets('PlayerControls：脉冲只点亮对应按钮，结束后复原', (tester) async {
    // 真 PlayerService 构造时会挂一个周期 Timer（位置落盘看门狗），
    // 必须在测试体内 dispose 掉，否则收尾的 !timersPending 断言会炸。
    final player = PlayerService(SilentAudioEngine());
    final theme = ThemeData();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PlayerControls(player: player, theme: theme, pulses: pulses),
          ),
        ),
      ),
    );

    Color? backgroundOf(IconData icon) => tester
        .widget<IconButton>(find.widgetWithIcon(IconButton, icon))
        .style
        ?.backgroundColor
        ?.resolve(const <WidgetState>{});

    expect(backgroundOf(Icons.skip_next_rounded), Colors.transparent);

    pulses.value = const PlaybackPulse(seq: 1, action: PlaybackAction.next);
    await tester.pump();

    expect(
      backgroundOf(Icons.skip_next_rounded),
      theme.colorScheme.primaryContainer,
    );
    expect(
      backgroundOf(Icons.skip_previous_rounded),
      Colors.transparent,
      reason: '只亮被按下的那个方向',
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(backgroundOf(Icons.skip_next_rounded), Colors.transparent);

    player.dispose();
  });
}
