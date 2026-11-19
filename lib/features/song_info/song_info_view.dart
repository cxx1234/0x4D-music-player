import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/display_format.dart';
import '../../l10n/l10n.dart';
import '../../widgets/cached_album_art.dart';
import 'song_info_data.dart';

/// 歌曲信息面板的纯展示层：只读 [SongInfoData]，不碰数据库 / ServiceLocator。
///
/// 与 `showSongInfoDialog` 分开是为了将来能把它原样搬进独立窗口（另一个
/// engine），见 `docs/UI-Rules.md` §18。
class SongInfoView extends StatefulWidget {
  const SongInfoView({super.key, required this.data, required this.onClose});

  final SongInfoData data;

  /// 面板自己的关闭按钮。独立窗口里传入 `windowManager.close()` 之类的实现。
  final VoidCallback onClose;

  @override
  State<SongInfoView> createState() => _SongInfoViewState();
}

class _SongInfoViewState extends State<SongInfoView> {
  /// 复制成功的勾选回显时长（不弹 HUD：它是全局 overlay，会被对话框盖住）。
  static const Duration _copiedFeedbackDuration = Duration(milliseconds: 1500);

  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.data.filePath));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(_copiedFeedbackDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = widget.data;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return Semantics(
      namesRoute: true,
      label: l10n.songInfoTitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(data: data),
            if (!data.isAvailable)
              _UnavailableBanner(text: l10n.songInfoUnavailable),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      title: l10n.songInfoFileSection,
                      children: [
                        _InfoRow(
                          label: l10n.songInfoFormat,
                          value: data.fileType,
                        ),
                        _InfoRow(
                          label: l10n.songInfoBitrate,
                          value: formatBitrate(data.bitrateBps),
                        ),
                        _InfoRow(
                          label: l10n.songInfoSampleRate,
                          value: formatSampleRate(data.sampleRate),
                        ),
                        _InfoRow(
                          label: l10n.songInfoDuration,
                          value: formatDurationMs(data.durationMs),
                        ),
                        _InfoRow(
                          label: l10n.songInfoFileSize,
                          value: data.fileSize == null
                              ? null
                              : formatFileSize(data.fileSize!),
                        ),
                        _InfoRow(
                          label: l10n.songInfoModifiedAt,
                          value: _formatDate(context, data.modifiedAt),
                        ),
                        _InfoRow(
                          label: l10n.songInfoAddedAt,
                          value: _formatDate(context, data.addedAt),
                        ),
                        _PathRow(
                          label: l10n.songInfoPath,
                          path: data.filePath,
                          copied: _copied,
                          onCopy: _copyPath,
                        ),
                      ],
                    ),
                    _Section(
                      title: l10n.songInfoTagSection,
                      children: [
                        _InfoRow(
                          label: l10n.songInfoTagTitle,
                          value: data.title,
                        ),
                        _InfoRow(
                          label: l10n.songInfoArtist,
                          value: data.artist,
                        ),
                        _InfoRow(label: l10n.songInfoAlbum, value: data.album),
                        _InfoRow(
                          label: l10n.songInfoAlbumArtist,
                          value: data.albumArtist,
                        ),
                        _InfoRow(
                          label: l10n.songInfoYear,
                          value: data.year?.toString(),
                        ),
                        _InfoRow(label: l10n.songInfoGenre, value: data.genre),
                        _InfoRow(
                          label: l10n.songInfoTrackNumber,
                          value: data.trackNumber?.toString(),
                        ),
                        _InfoRow(
                          label: l10n.songInfoDiscNumber,
                          value: data.discNumber?.toString(),
                        ),
                        _InfoRow(
                          label: l10n.songInfoEmbeddedLyrics,
                          value: data.hasEmbeddedLyrics
                              ? l10n.songInfoYes
                              : null,
                        ),
                        _InfoRow(
                          label: l10n.songInfoLyricsFile,
                          value: data.lyricsFilePath,
                        ),
                      ],
                    ),
                    _Section(
                      title: l10n.songInfoPlaybackSection,
                      children: [
                        _InfoRow(
                          label: l10n.songInfoPlayCount,
                          value: data.playCount.toString(),
                        ),
                        _InfoRow(
                          label: l10n.songInfoFavorite,
                          value: data.isFavorite
                              ? l10n.songInfoYes
                              : l10n.songInfoNo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onClose,
                    child: Text(l10n.songInfoClose),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _formatDate(BuildContext context, DateTime? date) {
  if (date == null) return null;
  return MaterialLocalizations.of(context).formatMediumDate(date);
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final SongInfoData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [data.artist, data.album].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedAlbumArt(
            albumArtFilePath: data.albumArtFilePath,
            hasEmbeddedArt: data.hasEmbeddedArt,
            size: 72,
            borderRadius: 8,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableBanner extends StatelessWidget {
  const _UnavailableBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// 一行「标签 + 值」；值为空时整行不占位。
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// 文件路径：可选中，右侧一个复制按钮（复制后短暂变勾）。
class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.label,
    required this.path,
    required this.copied,
    required this.onCopy,
  });

  final String label;
  final String path;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(path, style: theme.textTheme.bodySmall),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: copied ? l10n.songInfoCopied : l10n.songInfoCopyPath,
            icon: Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
