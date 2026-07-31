import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import 'playlist_picker_sheet.dart';

/// 歌曲"更多"菜单项。
List<PopupMenuEntry<String>> songMenuItems(Song song) => [
  const PopupMenuItem(value: 'playlist', child: Text('添加到播放列表')),
  PopupMenuItem(
    value: 'favorite',
    child: Text(song.isFavorite == 1 ? '取消喜欢' : '喜欢'),
  ),
];

/// 处理歌曲"更多"菜单点击。
Future<void> handleSongMenuAction(
  BuildContext context,
  Song song,
  String value,
) async {
  if (value == 'favorite') {
    await ServiceLocator.songRepo.toggleFavorite(song.id);
  } else if (value == 'playlist') {
    await showPlaylistPicker(context, [song]);
  }
}
