import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/hud_service.dart';
import 'package:txvziwm/core/services/menu_service.dart';
import 'package:txvziwm/core/services/play_queue.dart';
import 'package:txvziwm/core/services/playback_feedback_service.dart';
import 'package:txvziwm/core/services/player_service.dart';
import 'package:txvziwm/core/services/sleep_timer_service.dart';

import 'helpers/fake_audio_engine.dart';

/// macOS 原生菜单桥接：通道入站动作的分发 + 出站状态推送（含睡眠定时）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.jerryc.txvziwm/menu');
  const codec = StandardMethodCodec();

  late FakeAudioEngine engine;
  late PlayerService player;
  late SleepTimerService sleepTimer;
  late HudService hud;
  late MenuService menu;

  setUp(() {
    engine = FakeAudioEngine();
    player = PlayerService(engine, playQueue: PlayQueue());
    // 步长调小：用例里要靠它验证"倒计时 tick 不会重复推通道"。
    sleepTimer = SleepTimerService(
      player,
      tickInterval: const Duration(milliseconds: 20),
    );
    hud = HudService();
    menu = MenuService.attach(
      player,
      PlaybackFeedbackService(player, hud, sleepTimer),
      sleepTimer,
    );
    // 出站方向给个空 handler：否则每次 _push() 都会打一条
    // MissingPluginException 警告（只是噪音，不影响断言）。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    menu.dispose();
    sleepTimer.dispose();
    hud.dispose();
    player.dispose();
  });

  /// 模拟原生菜单发来的动作（原生 → Dart 的入站消息）。
  Future<void> sendMenuAction(Object action, [Object? value]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(
            MethodCall('menuAction', {'action': action, 'value': value}),
          ),
          (_) {},
        );
  }

  test('原生菜单设定分钟数（int）→ 启动倒计时', () async {
    await sendMenuAction('sleepTimer', 30);
    expect(sleepTimer.mode, SleepTimerMode.duration);
    expect(sleepTimer.remaining, const Duration(minutes: 30));
    expect(hud.message?.text, '睡眠定时 · 30 分钟');
  });

  test('原生菜单「播完当前曲目 / 播完当前播放列表 / 取消」', () async {
    await sendMenuAction('sleepTimer', 'endOfTrack');
    expect(sleepTimer.mode, SleepTimerMode.endOfTrack);

    await sendMenuAction('sleepTimer', 'endOfQueue');
    expect(sleepTimer.mode, SleepTimerMode.endOfQueue);

    await sendMenuAction('sleepTimer', 'cancel');
    expect(sleepTimer.isActive, isFalse);
    expect(hud.message?.text, '已取消睡眠定时');
  });

  test('分钟数为非法值时忽略（不改动已有定时）', () async {
    await sendMenuAction('sleepTimer', 15);
    await sendMenuAction('sleepTimer', 0);
    await sendMenuAction('sleepTimer', 'bogus');
    expect(sleepTimer.mode, SleepTimerMode.duration);
    expect(sleepTimer.remaining, const Duration(minutes: 15));
  });

  test('原生菜单 openAbout（帮助 › 关于本软件）→ 触发注入的回调', () async {
    var called = 0;
    menu.openAbout = () => called++;
    await sendMenuAction('openAbout');
    expect(called, 1);
  });

  test('推送状态带上睡眠定时（供原生勾选），且倒计时 tick 不重复推通道', () async {
    final payloads = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'updateMenuState') {
            payloads.add((call.arguments as Map).cast<Object?, Object?>());
          }
          return null;
        });

    await sendMenuAction('sleepTimer', 30);
    await Future<void>.delayed(Duration.zero); // 让 unawaited 的推送落地

    expect(payloads.last['sleepTimerMode'], 'duration');
    expect(payloads.last['sleepTimerMinutes'], 30);

    // 倒计时每秒（这里 20ms）都在改 remaining，但不该重复推通道。
    final count = payloads.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(payloads.length, count, reason: '只按"模式 + 设定分钟数"去重');

    await sendMenuAction('sleepTimer', 'cancel');
    await Future<void>.delayed(Duration.zero);
    expect(payloads.last['sleepTimerMode'], 'off');
    expect(payloads.last['sleepTimerMinutes'], 0);
  });
}
