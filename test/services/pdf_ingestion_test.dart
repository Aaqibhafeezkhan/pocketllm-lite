import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pocketllm_lite/features/rag/domain/document.dart';
import 'package:pocketllm_lite/services/document_ingestion_service.dart';

/// Builds a PDF with one distinct sentence per page.
Future<File> _buildPdf(Directory directory, List<String> pages) async {
  final document = pw.Document();
  for (final text in pages) {
    document.addPage(
      pw.Page(build: (_) => pw.Center(child: pw.Text(text))),
    );
  }
  final file = File('${directory.path}/fixture.pdf');
  await file.writeAsBytes(await document.save());
  return file;
}

class _FakePdfBackend implements PdfTextBackend {
  final List<String> pages;
  _FakePdfBackend(this.pages);

  @override
  List<String> extractPages(List<int> bytes) => pages;
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pocketllm-pdf-');
  });

  tearDown(() => directory.delete(recursive: true));

  test('pages are extracted in order with real page citations', () async {
    final file = await _buildPdf(directory, [
      'Alpha page discusses quantization formats.',
      'Beta page describes retrieval and citations.',
      'Gamma page covers backups and encryption.',
    ]);

    final result = await DocumentIngestionService().ingestFile(file);
    final document = result['document'] as IngestedDocument;
    final chunks = result['chunks'] as List<DocumentChunk>;

    expect(document.metadata['pageCount'], 3);
    expect(document.metadata['format'], 'pdf');
    final byPage = {
      for (final chunk in chunks) chunk.metadata['page'] as int: chunk.content,
    };
    expect(byPage.keys.toSet(), {1, 2, 3});
    expect(byPage[1], contains('quantization'));
    expect(byPage[2], contains('retrieval'));
    expect(byPage[3], contains('encryption'));
    // A page's text must never leak into another page's citation.
    expect(byPage[1], isNot(contains('retrieval')));
    expect(chunks.every((chunk) => chunk.metadata['section'] == null), isTrue);
  });

  test('the PDF engine can be swapped without touching chunking', () async {
    final file = await _buildPdf(directory, ['ignored by the fake backend']);

    final result = await DocumentIngestionService(
      pdfBackend: _FakePdfBackend(['First page text.', 'Second page text.']),
    ).ingestFile(file);

    final chunks = result['chunks'] as List<DocumentChunk>;
    expect(chunks.map((c) => c.metadata['page']), [1, 2]);
    expect(chunks.first.content, 'First page text.');
  });

  test('a PDF without selectable text asks for OCR instead of indexing nothing',
      () async {
    final file = await _buildPdf(directory, ['text']);
    await expectLater(
      DocumentIngestionService(
        pdfBackend: _FakePdfBackend(['', '   ']),
      ).ingestFile(file),
      throwsA(
        isA<DocumentParseError>().having(
          (error) => error.message,
          'message',
          contains('Scanned PDFs require OCR'),
        ),
      ),
    );
  });

  test('malformed PDF bytes fail with a structured parse error', () async {
    final file = File('${directory.path}/broken.pdf');
    await file.writeAsBytes(List<int>.generate(256, (i) => i));
    await expectLater(
      DocumentIngestionService().ingestFile(file),
      throwsA(isA<DocumentParseError>()),
    );
  });
}
