import '../../l10n/app_localizations.dart';
import 'shell_controller.dart';

/// 导航项展示文案（enum 本身不持有 UI 文案）。
extension NavigationItemL10n on NavigationItem {
  String label(AppLocalizations l10n) => switch (this) {
    NavigationItem.library => l10n.navLibrary,
    NavigationItem.albums => l10n.navAlbums,
    NavigationItem.artists => l10n.navArtists,
    NavigationItem.playlists => l10n.navPlaylists,
    NavigationItem.settings => l10n.navSettings,
  };
}
