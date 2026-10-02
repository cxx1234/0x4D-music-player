import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
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

    // 队列必须非空：睡眠定时有一条「队列被清空 → 自动取消」的安全网，空队列会在
    // 第一个 tick 就把定时取消掉（额外推一次 'off'）。
    // 也必须在 mock 注册**之后**：否则这次推送会因通道未就绪而失败，而失败会
    // 清掉快照让下次重推（见 [_push] 的 catchError），于此处多出一条重复推送。
    await player.playFromList([_song(1)]);
    await sendMenuAction('sleepTimer', 30);
    await Future<void>.delayed(Duration.zero); // 让 unawaited 的推送落地

    expect(payloads.last['sleepTimerMode'], 'duration');
    expect(payloads.last['sleepTimerMinutes'], 30);

    // 倒计时每秒（这里 20ms）都在改 remaining，但不该推进新状态。
    // 断言用「新增条数 ≤ 1」而不是「条数不变」：若前面某次推送因通道未就绪失败，
    // 失败重试会补推一条**内容相同**的（见下一个用例）。
    final count = payloads.length;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      payloads.length - count,
      lessThanOrEqualTo(1),
      reason: '倒计时 tick 不得推进新状态；实际推送序列：$payloads',
    );
    expect(payloads.last['sleepTimerMode'], 'duration');
    expect(payloads.last['sleepTimerMinutes'], 30);

    await sendMenuAction('sleepTimer', 'cancel');
    await Future<void>.delayed(Duration.zero);
    expect(payloads.last['sleepTimerMode'], 'off');
    expect(payloads.last['sleepTimerMinutes'], 0);
  });

  test('推送失败后不缓存快照：同一状态也会重推', () async {
    var attempts = 0;
    var failing = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'updateMenuState') {
            attempts++;
            if (failing) throw MissingPluginException('通道未就绪');
          }
          return null;
        });

    await player.playFromList([_song(1)]);
    await Future<void>.delayed(Duration.zero);
    final failed = attempts;
    expect(failed, greaterThan(0), reason: '这几条推送都失败了（模拟启动早期）');

    failing = false;
    // 再触发一次「播放器通知」，但**不改变任何参与去重的字段**。若失败那次被
    // 当成已推送（缓存了快照），这里会静默 return，菜单就永远停在原生默认值上。
    // ignore: invalid_use_of_protected_member
    player.notifyListeners();
    await Future<void>.delayed(Duration.zero);
    expect(attempts, greaterThan(failed), reason: '失败后必须重推');
  });
}

/// 只用来让队列非空（睡眠定时的「队列被清空 → 自动取消」安全网需要）。
Song _song(int id) => Song(
  id: id,
  title: 'Song $id',
  filePath: '/music/$id.mp3',
  fileName: 'Song $id.mp3',
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2026, 1, 1),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
  durationMs: 180000,
);
