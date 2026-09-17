import 'audio_engine.dart';
import 'audioplayers_engine.dart';

/// 应用使用的播放引擎。
///
/// 当前只有一个实现（audioplayers 单曲）：引擎不持队列，队列语义全部在
/// `PlayerService` —— 详见 `docs/AudioEngine-Migration.md`。
/// 将来若要换实现，只改这里。
AudioEngine createAudioEngine() => AudioplayersEngine();
