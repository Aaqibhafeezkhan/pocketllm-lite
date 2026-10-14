import 'package:flutter/material.dart';

/// Secondary chat actions that used to be four separate app-bar icons.
enum ChatMenuAction { chatSettings, mediaGallery, appSettings, unloadModel }

class ChatOverflowMenu extends StatelessWidget {
  /// Whether a local model is currently held in memory (adds an unload item).
  final bool modelLoaded;
  final ValueChanged<ChatMenuAction> onSelected;

  const ChatOverflowMenu({
    super.key,
    required this.modelLoaded,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<ChatMenuAction>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: ChatMenuAction.chatSettings,
          child: ListTile(
            leading: Icon(Icons.tune_rounded),
            title: Text('Chat settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: ChatMenuAction.mediaGallery,
          child: ListTile(
            leading: Icon(Icons.photo_library_outlined),
            title: Text('Media in this chat'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: ChatMenuAction.appSettings,
          child: ListTile(
            leading: Icon(Icons.settings_rounded),
            title: Text('App settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (modelLoaded)
          PopupMenuItem(
            value: ChatMenuAction.unloadModel,
            child: ListTile(
              leading:
                  Icon(Icons.power_settings_new_rounded, color: colors.error),
              title: const Text('Unload model from memory'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}
