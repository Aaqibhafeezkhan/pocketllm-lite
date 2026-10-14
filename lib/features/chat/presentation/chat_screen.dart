import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import 'providers/chat_provider.dart';
import 'providers/models_provider.dart';

import 'widgets/chat_body.dart';
import 'widgets/chat_input.dart';
import 'widgets/chat_overflow_menu.dart';
import 'widgets/model_picker_chip.dart';
import 'dialogs/chat_settings_dialog.dart';
import 'screens/chat_history_screen.dart';
import '../../media/presentation/screens/media_gallery_screen.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../../../providers/model_manager_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    final state = ref.read(modelManagerProvider);
    if (state.activeLoadedId != null) {
      ref.read(modelManagerProvider.notifier).unloadActiveModel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.onError,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Memory Pressure Alert: Local model unloaded from RAM to prevent application crash.',
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedModel = ref.watch(
      chatProvider.select((s) => s.selectedModel),
    );
    final modelsAsync = ref.watch(unifiedModelsProvider);
    final localState = ref.watch(modelManagerProvider);
    final activeLoadedId = localState.activeLoadedId;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    void haptic() {
      if (ref.read(storageServiceProvider).getSetting(
            AppConstants.hapticFeedbackKey,
            defaultValue: true,
          )) {
        HapticFeedback.selectionClick();
      }
    }

    return Scaffold(
      appBar: M3AppBar(
        title: '',
        automaticallyImplyLeading: false,
        titleWidget: modelsAsync.when(
          data: (models) {
            // Keep the selection valid when the model list changes.
            if (models.isNotEmpty &&
                !models.any((m) => m.id == selectedModel)) {
              final fallback = models.first.id;
              Future.microtask(
                () => ref.read(chatProvider.notifier).setModel(fallback),
              );
            }
            return ModelPickerChip(
              models: models,
              selectedId: selectedModel,
              activeLoadedId: activeLoadedId,
              onGetModels: () => context.push('/settings/model-catalog'),
              onSelected: (newModel) {
                if (newModel == selectedModel) return;
                ref.read(chatProvider.notifier).setModel(newModel);
                final activeId = ref.read(modelManagerProvider).activeLoadedId;
                if (activeId != null && activeId != newModel) {
                  ref.read(modelManagerProvider.notifier).unloadActiveModel();
                }
              },
            );
          },
          loading: () => const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, s) => Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar:
                  Icon(Icons.error_outline_rounded, color: colorScheme.error),
              label: const Text('Models unavailable'),
              tooltip: 'Open model setup',
              onPressed: () => context.push('/settings/model-catalog'),
            ),
          ),
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final chatState = ref.watch(chatProvider);
              final lastTps = chatState.lastTps;
              final lastTtftMs = chatState.lastTtftMs;
              final isGenerating = chatState.isGenerating;

              if (isGenerating && lastTps != null && lastTps > 0) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Tooltip(
                    message:
                        'Approximate live output rate based on rendered text',
                    child: Text(
                      '≈${lastTps.toStringAsFixed(1)} t/s'
                      '${lastTtftMs != null ? ' · ${lastTtftMs}ms' : ''}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {
              haptic();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChatHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: () {
              haptic();
              ref.read(chatProvider.notifier).newChat();
            },
          ),
          ChatOverflowMenu(
            modelLoaded: activeLoadedId != null,
            onSelected: (action) {
              haptic();
              switch (action) {
                case ChatMenuAction.chatSettings:
                  showDialog<void>(
                    context: context,
                    builder: (context) => const ChatSettingsDialog(),
                  );
                case ChatMenuAction.mediaGallery:
                  final sessionId = ref.read(chatProvider).currentSessionId;
                  if (sessionId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No media yet for this chat.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final session = ref
                      .read(storageServiceProvider)
                      .getChatSession(sessionId);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MediaGalleryScreen(
                        chatId: sessionId,
                        chatTitle: session?.title ?? 'Chat',
                      ),
                    ),
                  );
                case ChatMenuAction.appSettings:
                  context.push('/settings');
                case ChatMenuAction.unloadModel:
                  ref.read(modelManagerProvider.notifier).unloadActiveModel();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local model unloaded from memory.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Expanded(child: ChatBody()),
          const ChatInput(),
        ],
      ),
    );
  }
}
