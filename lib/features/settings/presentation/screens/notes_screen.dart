import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/m3_empty_state.dart';

/// Lists, reads, edits and deletes notes (including those created by the
/// `notes` tool after the user confirmed it). Notes are stored locally and are
/// part of encrypted backups.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  List<Map<String, dynamic>> _notes = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final notes = ref.read(storageServiceProvider).getLocalNotes().toList()
      ..sort((left, right) {
        String stamp(Map<String, dynamic> note) =>
            (note['updatedAt'] ?? note['createdAt'] ?? '') as String;
        return stamp(right).compareTo(stamp(left));
      });
    setState(() => _notes = notes);
  }

  Future<void> _edit(Map<String, dynamic> note) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _NoteEditor(note: note)),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Map<String, dynamic> note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"${note['title']}" will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(storageServiceProvider)
        .deleteLocalNote(note['id'] as String);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: M3AppBar(
        title: 'Notes',
        subtitle: 'Saved on this device and included in backups',
        onBack: () => context.pop(),
      ),
      body: _notes.isEmpty
          ? const M3EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'No notes yet',
              description: 'When you allow the assistant to save a note, it '
                  'appears here where you can read, edit or delete it.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: _notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Card.outlined(
                  child: ListTile(
                    minVerticalPadding: 12,
                    title: Text(
                      note['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      note['content'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () => _edit(note),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Note actions',
                      onSelected: (value) async {
                        if (value == 'copy') {
                          await Clipboard.setData(
                            ClipboardData(text: note['content'] as String),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Note copied.')),
                          );
                        } else if (value == 'delete') {
                          await _delete(note);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'copy', child: Text('Copy text')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NoteEditor extends ConsumerStatefulWidget {
  final Map<String, dynamic> note;
  const _NoteEditor({required this.note});

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.note['title'] as String);
  late final TextEditingController _content =
      TextEditingController(text: widget.note['content'] as String);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(storageServiceProvider).updateLocalNote(
            id: widget.note['id'] as String,
            title: _title.text,
            content: _content.text,
          );
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError {
      setState(() {
        _saving = false;
        _error = 'A note needs both a title and some text.';
      });
    } on StateError catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: M3AppBar(
        title: 'Edit note',
        onBack: () => Navigator.pop(context, false),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _content,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: 'Note',
              alignLabelWithHint: true,
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
