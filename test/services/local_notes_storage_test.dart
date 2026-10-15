import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pocketllm-notes-');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('tool-created notes persist and are included in encrypted backup data',
      () async {
    final first = StorageService();
    await first.init(testPath: directory.path);
    final note = await first.createLocalNote(
      title: 'Release',
      content: 'Verify production signing.',
    );
    final backup = first.exportBackupData();
    expect(
      (backup['settings'] as Map)[AppConstants.localNotesKey],
      isA<List>(),
    );

    await Hive.close();
    final reopened = StorageService();
    await reopened.init(testPath: directory.path);
    expect(reopened.getLocalNotes().single['id'], note['id']);
    expect(
      reopened.getLocalNotes().single['content'],
      'Verify production signing.',
    );
  });

  test('notes can be edited and deleted, and edits survive a restart',
      () async {
    final storage = StorageService();
    await storage.init(testPath: directory.path);
    final keep = await storage.createLocalNote(title: 'Keep', content: 'one');
    final drop = await storage.createLocalNote(title: 'Drop', content: 'two');

    final updated = await storage.updateLocalNote(
      id: keep['id'] as String,
      title: '  Kept  ',
      content: 'edited',
    );
    expect(updated['title'], 'Kept');
    expect(updated['createdAt'], keep['createdAt']);
    expect(updated['updatedAt'], isNotNull);

    expect(await storage.deleteLocalNote(drop['id'] as String), isTrue);
    expect(await storage.deleteLocalNote(drop['id'] as String), isFalse);

    await Hive.close();
    final reopened = StorageService();
    await reopened.init(testPath: directory.path);
    final notes = reopened.getLocalNotes();
    expect(notes, hasLength(1));
    expect(notes.single['title'], 'Kept');
    expect(notes.single['content'], 'edited');
  });

  test('editing validates input and refuses a missing note', () async {
    final storage = StorageService();
    await storage.init(testPath: directory.path);
    final note = await storage.createLocalNote(title: 'A', content: 'b');

    expect(
      () => storage.updateLocalNote(
        id: note['id'] as String,
        title: ' ',
        content: 'x',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => storage.updateLocalNote(id: 'missing', title: 'x', content: 'y'),
      throwsA(isA<StateError>()),
    );
    expect(storage.getLocalNotes().single['title'], 'A');
  });
}
