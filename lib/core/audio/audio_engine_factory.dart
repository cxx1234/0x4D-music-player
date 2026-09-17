import 'audio_engine.dart';
import 'audioplayers_engine.dart';
import 'just_audio_engine.dart';

/// 可用的播放引擎实现。
///
/// 迁移期间保留两个实现：`audioplayers` 是目标（引擎无队列，队列完全由
/// `PlayQueue` / `PlayerService` 持有），`justAudio` 是同时可用的对照物。
/// 详见 `docs/AudioEngine-Migration.md`。
enum AudioEngineKind {
  /// audioplayers 6.x（单曲）。
  audioplayers,

  /// just_audio 单曲模式（**不具备** gapless —— 那是它持有队列时才有的能力）。
  justAudio,
}

/// 应用当前使用的引擎。切换实现只需改这一处（并同步 `pubspec.yaml` 依赖）。
const AudioEngineKind currentAudioEngineKind = AudioEngineKind.audioplayers;

/// 创建播放引擎实例。
Future<AudioEngine> createAudioEngine([AudioEngineKind? kind]) async {
  switch (kind ?? currentAudioEngineKind) {
    case AudioEngineKind.audioplayers:
      return AudioplayersEngine();
    case AudioEngineKind.justAudio:
      return JustAudioEngine.create();
  }
}
