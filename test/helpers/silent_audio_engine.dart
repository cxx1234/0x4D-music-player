import 'package:txvziwm/core/audio/audio_engine.dart';

/// 最小假引擎：所有成员 no-op / 空流，供只关心上层逻辑（反馈、UI）的测试使用。
///
/// 需要真实队列语义（顺序推进 / 收尾 / 失败跳过 / 睡眠定时钩子）的用例请用
/// `helpers/fake_audio_engine.dart` 里那个带完成/报错驱动的 FakeAudioEngine。
class SilentAudioEngine implements AudioEngine {
  /// 最后一次 `setVolume` 的值（仅供需要断言的用例读取）。
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
