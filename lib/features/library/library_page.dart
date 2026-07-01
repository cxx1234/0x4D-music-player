import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/service_locator.dart';

class LibraryPage extends StatefulWidget {
  final bool isInitialized;

  const LibraryPage({super.key, this.isInitialized = false});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<String> _musicFolders = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void didUpdateWidget(LibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInitialized && !oldWidget.isInitialized) {
      _loadFolders();
    }
  }

  void _loadFolders() {
    if (!widget.isInitialized) return;
    final folders = ServiceLocator.settings.musicFolders;
    if (mounted) {
      setState(() {
        _musicFolders = folders;
        _ready = true;
      });
    }
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || !mounted) return;

    await ServiceLocator.settings.addMusicFolder(path);
    setState(() => _musicFolders = ServiceLocator.settings.musicFolders);
  }

  Future<void> _removeFolder(String path) async {
    await ServiceLocator.settings.removeMusicFolder(path);
    setState(() => _musicFolders = ServiceLocator.settings.musicFolders);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_ready) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('你的音乐库', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
          ],
        ),
      );
    }

    if (_musicFolders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('你的音乐库', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '导入音乐文件夹以开始使用',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('导入文件夹'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            children: [
              Text('音乐库', style: theme.textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: _pickFolder,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('导入文件夹'),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _musicFolders.length,
            itemBuilder: (context, index) {
              final folder = _musicFolders[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '移除',
                    onPressed: () => _removeFolder(folder),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
