import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:uuid/uuid.dart';

import '../features/rag/domain/document.dart';
import 'context_budget_manager.dart';

class DocumentParseError implements Exception {
  final String message;
  final Object? cause;

  const DocumentParseError(this.message, [this.cause]);

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class _ExtractedPage {
  final int number;
  final String text;
  const _ExtractedPage(this.number, this.text);
}

class DocumentIngestionService {
  final Uuid _uuid;
  final ContextBudgetManager _tokenizer;

  DocumentIngestionService({
    Uuid uuid = const Uuid(),
    ContextBudgetManager? tokenizer,
  })  : _uuid = uuid,
        _tokenizer = tokenizer ?? ContextBudgetManager();

  Future<List<_ExtractedPage>> _extractPages(
    File file,
    String extension,
  ) async {
    try {
      switch (extension) {
        case '.txt':
        case '.md':
        case '.csv':
          return [_ExtractedPage(1, _decodeText(await file.readAsBytes()))];
        case '.pdf':
          final bytes = await file.readAsBytes();
          final document = PdfDocument(inputBytes: bytes);
          try {
            final extractor = PdfTextExtractor(document);
            return List.generate(
              document.pages.count,
              (index) => _ExtractedPage(
                index + 1,
                extractor.extractText(
                  startPageIndex: index,
                  endPageIndex: index,
                ),
              ),
              growable: false,
            );
          } finally {
            document.dispose();
          }
        default:
          throw DocumentParseError('Unsupported file type: $extension');
      }
    } on DocumentParseError {
      rethrow;
    } catch (error) {
      throw DocumentParseError('Could not extract document text.', error);
    }
  }

  /// Decodes UTF-8 (with or without a BOM) and falls back to Latin-1 so legacy
  /// Windows exports do not fail with an opaque extraction error.
  String _decodeText(List<int> bytes) {
    var start = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      start = 3;
    }
    final body = start == 0 ? bytes : bytes.sublist(start);
    try {
      return utf8.decode(body);
    } on FormatException {
      return latin1.decode(body);
    }
  }

  List<DocumentChunk> _chunkPages(
    String documentId,
    List<_ExtractedPage> pages, {
    bool paged = true,
    int targetTokens = 450,
    int overlapTokens = 75,
  }) {
    if (targetTokens <= 0 ||
        overlapTokens < 0 ||
        overlapTokens >= targetTokens) {
      throw ArgumentError('Chunk token settings are invalid.');
    }
    final chunks = <DocumentChunk>[];
    for (final page in pages) {
      final paragraphs = page.text
          .replaceAll('\r\n', '\n')
          .split(RegExp(r'\n\s*\n|(?<=[.!?])\s+(?=[A-Z0-9])'))
          .map((part) => part.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      var cursor = 0;
      while (cursor < paragraphs.length) {
        final selected = <String>[];
        var tokens = 0;
        var index = cursor;
        while (index < paragraphs.length) {
          final paragraphTokens = _tokenizer.estimateTokens(paragraphs[index]);
          if (selected.isNotEmpty && tokens + paragraphTokens > targetTokens) {
            break;
          }
          selected.add(paragraphs[index]);
          tokens += paragraphTokens;
          index++;
        }
        if (selected.isEmpty) {
          selected.add(paragraphs[cursor]);
          index = cursor + 1;
          tokens = _tokenizer.estimateTokens(paragraphs[cursor]);
        }
        final content = selected.join('\n\n');
        chunks.add(
          DocumentChunk(
            id: _uuid.v4(),
            documentId: documentId,
            content: content,
            index: chunks.length,
            // Only paginated formats have real page numbers. Plain text is
            // cited by excerpt number so the model never claims "page 1".
            metadata: {
              if (paged) 'page': page.number else 'section': chunks.length + 1,
              'tokenCount': tokens,
              'citation': paged
                  ? 'Page ${page.number}'
                  : 'Section ${chunks.length + 1}',
            },
          ),
        );

        var retainedTokens = 0;
        var nextCursor = index;
        while (nextCursor > cursor + 1 && retainedTokens < overlapTokens) {
          nextCursor--;
          retainedTokens += _tokenizer.estimateTokens(paragraphs[nextCursor]);
        }
        cursor = nextCursor > cursor ? nextCursor : index;
      }
    }
    return chunks;
  }

  Future<Map<String, dynamic>> ingestFile(File file) async {
    if (!await file.exists()) {
      throw const DocumentParseError('The selected document no longer exists.');
    }
    final extension = p.extension(file.path).toLowerCase();
    final filename = p.basename(file.path);
    final pages = await _extractPages(file, extension);
    if (pages.every((page) => page.text.trim().isEmpty)) {
      throw const DocumentParseError(
        'No selectable text was found. Scanned PDFs require OCR before indexing.',
      );
    }

    final documentId = _uuid.v4();
    final chunks = _chunkPages(documentId, pages, paged: extension == '.pdf');
    final document = IngestedDocument(
      id: documentId,
      title: p.basenameWithoutExtension(filename),
      filename: filename,
      totalChunks: chunks.length,
      sizeBytes: await file.length(),
      ingestedAt: DateTime.now(),
      metadata: {
        'format': extension.replaceFirst('.', ''),
        'pageCount': pages.length,
        'schemaVersion': 2,
      },
    );
    return {'document': document, 'chunks': chunks};
  }
}
