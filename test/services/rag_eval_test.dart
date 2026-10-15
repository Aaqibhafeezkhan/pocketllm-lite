import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pocketllm_lite/features/rag/domain/document.dart';
import 'package:pocketllm_lite/services/document_ingestion_service.dart';
import 'package:pocketllm_lite/services/vector_store_service.dart';

/// Measured keyword-retrieval quality over a small, MIT-licensed corpus.
/// See test/fixtures/rag_eval/README.md. Semantic and hybrid retrieval need an
/// embedding runtime and are intentionally not evaluated here.
void main() {
  late Directory hiveDirectory;
  late VectorStoreService store;
  final documentIds = <String, String>{}; // file name -> document id
  late List<Map<String, dynamic>> questions;

  setUpAll(() async {
    hiveDirectory =
        await Directory.systemTemp.createTemp('pocketllm_rag_eval_');
    Hive.init(hiveDirectory.path);
    store = VectorStoreService();
    final ingestion = DocumentIngestionService();
    final docs = Directory('test/fixtures/rag_eval/docs')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.md'));
    for (final file in docs) {
      final result = await ingestion.ingestFile(file);
      final document = result['document'] as IngestedDocument;
      final chunks = result['chunks'] as List<DocumentChunk>;
      final name = file.uri.pathSegments.last;
      final withFilename = [
        for (final chunk in chunks)
          DocumentChunk(
            id: chunk.id,
            documentId: chunk.documentId,
            content: chunk.content,
            index: chunk.index,
            metadata: {...chunk.metadata, 'filename': name},
          ),
      ];
      await store.storeDocument(
        IngestedDocument(
          id: document.id,
          title: document.title,
          filename: name,
          totalChunks: withFilename.length,
          sizeBytes: document.sizeBytes,
          ingestedAt: document.ingestedAt,
          metadata: const {'retrievalMode': 'keyword'},
        ),
        withFilename,
        null,
      );
      documentIds[name] = document.id;
    }
    questions = (jsonDecode(
      File('test/fixtures/rag_eval/questions.json').readAsStringSync(),
    ) as List)
        .cast<Map<String, dynamic>>();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  bool containsPhrase(DocumentSearchResult result, String phrase) =>
      result.chunk.content
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .contains(phrase.toLowerCase());

  test('corpus and questions are consistent', () {
    expect(documentIds.keys, hasLength(3));
    expect(questions, hasLength(12));
    for (final question in questions) {
      expect(documentIds, contains(question['document']),
          reason: question['id'] as String);
    }
  });

  test('keyword retrieval surfaces the answer chunk (hit@3 and MRR)', () async {
    var hits = 0;
    var reciprocalRankSum = 0.0;
    final misses = <String>[];
    for (final question in questions) {
      final results = await store.searchKeyword(
        queryText: question['question'] as String,
        topK: 3,
      );
      final rank = results.indexWhere(
        (result) => containsPhrase(result, question['answerPhrase'] as String),
      );
      if (rank >= 0) {
        hits++;
        reciprocalRankSum += 1 / (rank + 1);
      } else {
        misses.add(question['id'] as String);
      }
    }
    final hitRate = hits / questions.length;
    final mrr = reciprocalRankSum / questions.length;
    // ignore: avoid_print
    print('rag-eval keyword: hit@3=${hitRate.toStringAsFixed(2)} '
        'mrr=${mrr.toStringAsFixed(2)} misses=$misses');
    expect(hitRate, greaterThanOrEqualTo(0.9), reason: 'misses: $misses');
    expect(mrr, greaterThanOrEqualTo(0.75));
  });

  test('document scoping never leaks chunks from another document', () async {
    final garden = documentIds['garden_notes.md']!;
    final results = await store.searchKeyword(
      queryText: 'tyre pressure chain brake pads sourdough starter',
      topK: 5,
      filterDocId: garden,
    );
    expect(
      results.every((result) => result.chunk.documentId == garden),
      isTrue,
    );
  });

  test('a query with no overlap returns nothing instead of a guess', () async {
    final results = await store.searchKeyword(
      queryText: 'quantum chromodynamics lattice gauge',
      topK: 3,
    );
    expect(results, isEmpty);
  });
}
