import Cocoa
import FlutterMacOS
import MediaPlayer

/// Native macOS counterpart of `lib/core/audio/macos_media_controls.dart`.
///
/// Bridges:
/// - MethodChannel `flutter_music/media_controls` (Dart → Native):
///   `setup` / `updateNowPlaying` / `clearNowPlaying`
/// - EventChannel `flutter_music/media_controls_events` (Native → Dart):
///   `play` / `pause` / `toggle` / `next` / `previous` / `seek`
public class MediaControlsPlugin: NSObject, FlutterPlugin {
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_music/media_controls",
      binaryMessenger: registrar.messenger
    )
    let eventChannel = FlutterEventChannel(
      name: "flutter_music/media_controls_events",
      binaryMessenger: registrar.messenger
    )
    let instance = MediaControlsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setup":
      setupRemoteCommands()
      result(nil)
    case "updateNowPlaying":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "BAD_ARGS", message: "Expected a map", details: nil))
        return
      }
      updateNowPlaying(args)
      result(nil)
    case "clearNowPlaying":
      clearNowPlaying()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Remote commands

  private func setupRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()

    // Clear any previously registered targets so re-setup is idempotent.
    center.playCommand.removeTarget(nil)
    center.pauseCommand.removeTarget(nil)
    center.togglePlayPauseCommand.removeTarget(nil)
    center.nextTrackCommand.removeTarget(nil)
    center.previousTrackCommand.removeTarget(nil)
    center.changePlaybackPositionCommand.removeTarget(nil)

    center.playCommand.addTarget { [weak self] _ in
      self?.sendEvent("play")
      return .success
    }
    center.pauseCommand.addTarget { [weak self] _ in
      self?.sendEvent("pause")
      return .success
    }
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.sendEvent("toggle")
      return .success
    }
    center.nextTrackCommand.addTarget { [weak self] _ in
      self?.sendEvent("next")
      return .success
    }
    center.previousTrackCommand.addTarget { [weak self] _ in
      self?.sendEvent("previous")
      return .success
    }
    center.changePlaybackPositionCommand.isEnabled = true
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      self?.sendEvent("seek", ["positionMs": Int(event.positionTime * 1000)])
      return .success
    }
  }

  private func sendEvent(_ event: String, _ args: [String: Any] = [:]) {
    var payload: [String: Any] = ["event": event]
    for (key, value) in args { payload[key] = value }
    eventSink?(payload)
  }

  // MARK: - Now Playing info

  private func updateNowPlaying(_ args: [String: Any]) {
    var info: [String: Any] = [:]

    info[MPMediaItemPropertyTitle] = args["title"] as? String
    if let artist = args["artist"] as? String {
      info[MPMediaItemPropertyArtist] = artist
    }
    if let album = args["album"] as? String {
      info[MPMediaItemPropertyAlbumTitle] = album
    }
    if let durationMs = args["durationMs"] as? Int, durationMs > 0 {
      info[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
    }
    if let positionMs = args["positionMs"] as? Int, positionMs >= 0 {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(positionMs) / 1000.0
    }
    let isPlaying = (args["isPlaying"] as? Bool) ?? false
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

    if let path = args["coverFilePath"] as? String,
       FileManager.default.fileExists(atPath: path),
       let image = NSImage(contentsOfFile: path) {
      info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
        boundsSize: image.size
      ) { _ in image }
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func clearNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }
}

extension MediaControlsPlugin: FlutterStreamHandler {
  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
