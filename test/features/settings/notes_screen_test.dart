import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/settings/presentation/screens/notes_screen.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class _NotesStorage extends StorageService {
  List<Map<String, dynamic>> notes;
  _NotesStorage(this.notes);

  @override
  List<Map<String, dynamic>> getLocalNotes() => List.of(notes);

  @override
  Future<Map<String, dynamic>> updateLocalNote({
    required String id,
    required String title,
    required String content,
  }) async {
    if (title.trim().isEmpty || content.trim().isEmpty) {
      throw ArgumentError('empty');
    }
    final index = notes.indexWhere((note) => note['id'] == id);
    if (index < 0) throw StateError('This note no longer exists.');
    notes[index] = {
      ...notes[index],
      'title': title.trim(),
      'content': content.trim(),
      'updatedAt': '2026-10-15T12:00:00Z',
    };
    return notes[index];
  }

  @override
  Future<bool> deleteLocalNote(String id) async {
    final before = notes.length;
    notes.removeWhere((note) => note['id'] == id);
    return notes.length != before;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _NotesStorage storage, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 640),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const NotesScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final seed = [
    {
      'id': 'a',
      'title': 'Older note',
      'content': 'first body',
      'createdAt': '2026-10-01T10:00:00Z',
    },
    {
      'id': 'b',
      'title': 'Newer note',
      'content': 'second body',
      'createdAt': '2026-10-10T10:00:00Z',
    },
  ];

  testWidgets('empty state explains where notes come from', (tester) async {
    await _pump(tester, _NotesStorage([]));
    expect(find.text('No notes yet'), findsOneWidget);
    expect(find.textContaining('allow the assistant'), findsOneWidget);
  });

  testWidgets('lists newest first and edits a note', (tester) async {
    final storage = _NotesStorage(seed.map(Map<String, dynamic>.of).toList());
    await _pump(tester, storage);

    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(
        titles.indexOf('Newer note'), lessThan(titles.indexOf('Older note')));

    await tester.tap(find.text('Older note'));
    await tester.pumpAndSettle();
    expect(find.text('Edit note'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed'), findsOneWidget);
    expect(find.text('Older note'), findsNothing);
    expect(storage.notes.firstWhere((n) => n['id'] == 'a')['title'], 'Renamed');
  });

  testWidgets('saving an empty title shows an error and keeps the note',
      (tester) async {
    final storage = _NotesStorage(seed.map(Map<String, dynamic>.of).toList());
    await _pump(tester, storage);
    await tester.tap(find.text('Newer note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
        find.text('A note needs both a title and some text.'), findsOneWidget);
    expect(
        storage.notes.firstWhere((n) => n['id'] == 'b')['title'], 'Newer note');
  });

  testWidgets('delete asks for confirmation, then removes the note',
      (tester) async {
    final storage = _NotesStorage(seed.map(Map<String, dynamic>.of).toList());
    await _pump(tester, storage);
    await tester.tap(find.byTooltip('Note actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete note?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.notes, hasLength(2));

    await tester.tap(find.byTooltip('Note actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(storage.notes, hasLength(1));
    expect(find.text('Newer note'), findsNothing);
  });

  testWidgets('fits 360 x 640 at 130% text scale', (tester) async {
    await _pump(
      tester,
      _NotesStorage(seed.map(Map<String, dynamic>.of).toList()),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
