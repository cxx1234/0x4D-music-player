import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Manages macOS Security-Scoped Bookmarks via a native MethodChannel.
///
/// On macOS with App Sandbox enabled, reading files outside the app's
/// container requires a security-scoped bookmark obtained from an
/// `NSOpenPanel`.  This service creates, resolves, and manages those
/// bookmarks so folder access survives app restarts.
///
/// On non-macOS platforms all calls are no-ops.
class SandboxService {
  static const _channel = MethodChannel('com.jerryc.txvziwm/sandbox');

  /// Creates a security-scoped bookmark for [path] and returns it as a
  /// base64-encoded string.
  ///
  /// The bookmark must be persisted (e.g. in settings) and later passed
  /// to [resolveBookmark] to restore access after an app restart.
  Future<String> createBookmark(String path) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'createBookmark',
        path,
      );
      return result ?? '';
    } on MissingPluginException {
      // Not running on macOS — bookmarking is not needed.
      return '';
    }
  }

  /// Resolves a previously created [base64Bookmark] and starts accessing the
  /// security-scoped resource.  Returns the file path on success, or `null`
  /// if the bookmark is invalid / stale / cannot be accessed.
  Future<String?> resolveBookmark(String base64Bookmark) async {
    try {
      return await _channel.invokeMethod<String>(
        'resolveBookmark',
        base64Bookmark,
      );
    } on PlatformException catch (e) {
      // STALE / RESOLVE_FAILED / ACCESS_FAILED — the bookmark can't be
      // restored. Log the reason so callers can decide whether to ask the
      // user to re-authorize the folder.
      AppLogger.warning(
        'Sandbox',
        'Failed to resolve bookmark: ${e.code} - ${e.message}',
        e,
      );
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
