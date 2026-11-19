import 'package:flutter/material.dart';

import 'song_info_data.dart';
import 'song_info_loader.dart';
import 'song_info_view.dart';

/// 打开「歌曲信息」对话框。
///
/// 入口只传歌曲 id（不传 `Song` 实体）：数据一律经 [loadSongInfo] 现取，
/// 将来换成独立窗口时入口不变，只换容器。见 `docs/UI-Rules.md` §18。
Future<void> showSongInfoDialog(BuildContext context, int songId) async {
  final data = await loadSongInfo(songId);
  if (!context.mounted || data == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) => SongInfoDialog(data: data),
  );
}

/// 信息面板的对话框容器（`elevation: 0` + 边线：不引入 Material 阴影）。
class SongInfoDialog extends StatelessWidget {
  const SongInfoDialog({super.key, required this.data});

  final SongInfoData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      elevation: 0,
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: SongInfoView(
        data: data,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
