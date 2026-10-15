import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/widgets/m3_app_bar.dart';
import '../../../services/document_ingestion_service.dart';
import '../../../services/shared_content.dart';
import '../../chat/presentation/providers/chat_provider.dart';
import '../../chat/presentation/providers/models_provider.dart';
import '../../rag/providers/rag_provider.dart';
import '../providers/share_provider.dart';

/// Shown when another app shares text, a link or documents to PocketLLM.
///
/// Nothing is processed until the user picks an action, nothing is stored
/// unless they choose Save, and the copied files are deleted when they leave.
class ShareReceiverScreen extends ConsumerStatefulWidget {
  const ShareReceiverScreen({super.key});

  @override
  ConsumerState<ShareReceiverScreen> createState() =>
      _ShareReceiverScreenState();
}

class _ShareReceiverScreenState extends ConsumerState<ShareReceiverScreen> {
  static const _maxPromptChars = 24000;

  final TextEditingController _question = TextEditingController();
  bool _busy = false;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _close({bool discard = true}) async {
    if (discard) await ref.read(shareProvider.notifier).clear();
    if (mounted) context.go('/chat');
  }

  /// Reads the shared material into prompt text. Text files are read as UTF-8
  /// (Latin-1 fallback); PDFs go through the same extractor as the knowledge
  /// base. Nothing is stored.
  Future<String> _materialize(SharedContent content) async {
    final buffer = StringBuffer();
    if (content.hasText) {
      buffer.writeln('Shared text:\n${content.text!.trim()}\n');
    }
    for (final file in content.files) {
      setState(() => _status = 'Reading ${file.name}…');
      String text;
      if (file.kind == SharedFileKind.pdf) {
        final result = await DocumentIngestionService().ingestFile(file.file);
        final chunks = (result['chunks'] as List).cast<dynamic>();
        text = chunks.map((chunk) => chunk.content as String).join('\n\n');
      } else {
        final bytes = await file.file.readAsBytes();
        try {
          text = utf8.decode(bytes);
        } on FormatException {
          text = latin1.decode(bytes);
        }
      }
      buffer.writeln('File "${file.name}":\n${text.trim()}\n');
    }
    final all = buffer.toString();
    return all.length <= _maxPromptChars
        ? all
        : '${all.substring(0, _maxPromptChars)}\n[Truncated to the first '
            '$_maxPromptChars characters]';
  }

  Future<bool> _ensureModel() async {
    final models = await ref.read(unifiedModelsProvider.future);
    if (models.isNotEmpty) return true;
    if (!mounted) return false;
    setState(() => _status = null);
    final setUp = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No model ready'),
        content: const Text(
          'Shared content is answered by a real model, and none is set up '
          'yet. Download an on-device model or connect a server first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Set up a model'),
          ),
        ],
      ),
    );
    if (setUp == true && mounted) context.push('/settings/model-catalog');
    return false;
  }

  Future<void> _sendToModel(SharedContent content, String instruction) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Preparing…';
    });
    try {
      if (!await _ensureModel()) return;
      final material = await _materialize(content);
      final prompt = '$instruction\n\n$material';
      final notifier = ref.read(chatProvider.notifier);
      notifier.newChat();
      await ref.read(shareProvider.notifier).clear();
      if (!mounted) return;
      context.go('/chat');
      await notifier.sendMessage(prompt);
    } on DocumentParseError catch (error) {
      setState(() => _error = error.message);
    } on FileSystemException catch (error) {
      setState(
          () => _error = 'Could not read the shared file: ${error.message}');
    } catch (error) {
      setState(() => _error = 'Something went wrong: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _saveToKnowledge(SharedContent content) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Saving to your knowledge base…';
    });
    try {
      final rag = ref.read(ragDocumentsProvider.notifier);
      var saved = 0;
      for (final file in content.files) {
        await rag.ingestFile(file.file);
        saved++;
      }
      if (content.hasText && content.files.isEmpty) {
        final dir = await Directory.systemTemp.createTemp('pocketllm_share_');
        final note = File(p.join(dir.path, 'shared-text.txt'));
        await note.writeAsString(content.text!.trim());
        await rag.ingestFile(note);
        await dir.delete(recursive: true);
        saved++;
      }
      final problem = ref.read(ragDocumentsProvider).error;
      if (problem != null) {
        setState(() => _error = 'Could not save: $problem');
        return;
      }
      await ref.read(shareProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved == 1
                ? 'Saved to your knowledge base.'
                : 'Saved $saved items to your knowledge base.',
          ),
        ),
      );
      context.go('/document-manager');
    } catch (error) {
      setState(() => _error = 'Could not save: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = ref.watch(shareProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: M3AppBar(
          title: 'Shared with PocketLLM',
          onBack: _close,
        ),
        body: content == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Nothing is waiting. Share text, a link or a document '
                    'from another app and choose PocketLLM.',
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (content.hasText || content.files.isNotEmpty)
                    _PreviewCard(content: content),
                  if (content.rejected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card.filled(
                      color: colors.errorContainer,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Not used',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.onErrorContainer,
                              ),
                            ),
                            for (final item in content.rejected)
                              Text(
                                '${item.name}: ${item.reason}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onErrorContainer,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (content.isEmpty)
                    Text(
                      'There is nothing PocketLLM can read in this share.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else ...[
                    if (content.isLinkOnly)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'This is only a link. PocketLLM does not open web '
                          'pages on its own, so the model would see just the '
                          'address. Paste the page text or share it as a '
                          'document to work with its contents.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      key: const Key('share-summarize'),
                      onPressed: _busy
                          ? null
                          : () => _sendToModel(
                                content,
                                'Summarize the following shared content. '
                                'Be concise and note anything unclear.',
                              ),
                      icon: const Icon(Icons.summarize_rounded),
                      label: const Text('Summarize'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('share-question'),
                      controller: _question,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'Ask a question about it',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(content),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      key: const Key('share-ask'),
                      onPressed: _busy ? null : () => _ask(content),
                      icon: const Icon(Icons.question_answer_rounded),
                      label: const Text('Ask'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('share-save'),
                      onPressed: _busy || content.isLinkOnly
                          ? null
                          : () => _saveToKnowledge(content),
                      icon: const Icon(Icons.library_add_rounded),
                      label: const Text('Save to knowledge base'),
                    ),
                  ],
                  if (_status != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_status!)),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const Key('share-error'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Nothing is saved unless you choose Save. Shared files '
                    'are deleted when you leave this screen.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
      ),
    );
  }

  void _ask(SharedContent content) {
    final question = _question.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'Type a question first.');
      return;
    }
    _sendToModel(
      content,
      'Answer this question using only the shared content below. If the '
      'content does not contain the answer, say so.\n\nQuestion: $question',
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final SharedContent content;
  const _PreviewCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String excerpt(String value) =>
        value.length <= 600 ? value : '${value.substring(0, 600)}…';
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.subject != null && content.subject!.trim().isNotEmpty)
              Text(content.subject!, style: theme.textTheme.titleMedium),
            if (content.hasText) ...[
              const SizedBox(height: 8),
              Text(
                excerpt(content.text!.trim()),
                key: const Key('share-preview-text'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (content.links.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final link in content.links.take(3))
                Text(
                  link,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
            for (final file in content.files)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  file.kind == SharedFileKind.pdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.description_outlined,
                ),
                title: Text(file.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(_formatSize(file.sizeBytes)),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }
}
