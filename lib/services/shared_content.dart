import 'dart:io';

import 'package:path/path.dart' as p;

/// A file the Android layer copied out of another app's share intent into this
/// app's private cache. Everything here is untrusted until validated.
class RawSharedFile {
  final String path;
  final String name;
  final String? mimeType;
  final int sizeBytes;

  /// Set by the platform layer when it refused or failed to copy the item.
  final String? error;

  const RawSharedFile({
    required this.path,
    required this.name,
    this.mimeType,
    required this.sizeBytes,
    this.error,
  });

  factory RawSharedFile.fromMap(Map<Object?, Object?> map) => RawSharedFile(
        path: (map['path'] as String?) ?? '',
        name: (map['name'] as String?) ?? 'shared-file',
        mimeType: map['mimeType'] as String?,
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        error: map['error'] as String?,
      );
}

class RawShare {
  final String? text;
  final String? subject;
  final List<RawSharedFile> files;

  const RawShare({this.text, this.subject, this.files = const []});

  factory RawShare.fromMap(Map<Object?, Object?> map) => RawShare(
        text: map['text'] as String?,
        subject: map['subject'] as String?,
        files: [
          for (final item in (map['files'] as List<Object?>? ?? const []))
            if (item is Map) RawSharedFile.fromMap(item),
        ],
      );
}

enum SharedFileKind { text, pdf }

class AcceptedSharedFile {
  final File file;
  final String name;
  final SharedFileKind kind;
  final int sizeBytes;

  const AcceptedSharedFile({
    required this.file,
    required this.name,
    required this.kind,
    required this.sizeBytes,
  });
}

class RejectedSharedItem {
  final String name;
  final String reason;
  const RejectedSharedItem(this.name, this.reason);
}

/// The validated result of a share: what may be processed, and what was
/// refused with a reason the user can read.
class SharedContent {
  final String? text;
  final String? subject;
  final List<String> links;
  final List<AcceptedSharedFile> files;
  final List<RejectedSharedItem> rejected;

  const SharedContent({
    this.text,
    this.subject,
    this.links = const [],
    this.files = const [],
    this.rejected = const [],
  });

  bool get hasText => text != null && text!.trim().isNotEmpty;
  bool get isEmpty => !hasText && files.isEmpty;

  /// A share that is only a link (nothing to read without fetching it).
  bool get isLinkOnly =>
      files.isEmpty && links.length == 1 && (text ?? '').trim() == links.single;
}

/// Validation rules for shared material. Pure Dart so they are unit tested.
///
/// Guarantees:
/// - only types the app can really process are accepted;
/// - size and count are bounded;
/// - a path outside the app's own share inbox is never accepted, so a crafted
///   share cannot point the app at unrelated files;
/// - only http(s) links are surfaced.
class SharedContentPolicy {
  static const maxTextChars = 200 * 1024;
  static const maxFileBytes = 25 * 1024 * 1024;
  static const maxFiles = 5;

  static const _textMimes = {
    'text/plain',
    'text/markdown',
    'text/x-markdown',
    'text/csv',
    'text/comma-separated-values',
  };
  static const _textExtensions = {'.txt', '.md', '.markdown', '.csv'};

  /// Directory the platform layer copies shared files into.
  final String inboxPath;

  const SharedContentPolicy({required this.inboxPath});

  SharedContent validate(RawShare raw) {
    final rejected = <RejectedSharedItem>[];
    final accepted = <AcceptedSharedFile>[];

    var text = raw.text;
    if (text != null && text.length > maxTextChars) {
      rejected.add(const RejectedSharedItem(
        'Shared text',
        'The text is longer than 200 KB. Share a file instead.',
      ));
      text = null;
    }

    if (raw.files.length > maxFiles) {
      rejected.add(RejectedSharedItem(
        'Extra files',
        'Only the first $maxFiles files are used.',
      ));
    }

    for (final item in raw.files.take(maxFiles)) {
      if (item.error != null) {
        rejected.add(RejectedSharedItem(item.name, item.error!));
        continue;
      }
      if (!_isInside(inboxPath, item.path)) {
        rejected.add(RejectedSharedItem(
          item.name,
          'The file was not copied into the share inbox, so it was ignored.',
        ));
        continue;
      }
      if (item.sizeBytes <= 0) {
        rejected.add(RejectedSharedItem(item.name, 'The file is empty.'));
        continue;
      }
      if (item.sizeBytes > maxFileBytes) {
        rejected.add(RejectedSharedItem(
          item.name,
          'The file is larger than 25 MB.',
        ));
        continue;
      }
      final kind = _classify(item.name, item.mimeType);
      if (kind == null) {
        rejected.add(RejectedSharedItem(
          item.name,
          'Unsupported type (${item.mimeType ?? 'unknown'}). PocketLLM reads '
          'PDF, TXT, Markdown and CSV.',
        ));
        continue;
      }
      accepted.add(AcceptedSharedFile(
        file: File(item.path),
        name: item.name,
        kind: kind,
        sizeBytes: item.sizeBytes,
      ));
    }

    return SharedContent(
      text: text,
      subject: raw.subject,
      links: extractLinks(text ?? ''),
      files: accepted,
      rejected: rejected,
    );
  }

  static SharedFileKind? _classify(String name, String? mimeType) {
    final mime = mimeType?.toLowerCase().split(';').first.trim();
    final extension = p.extension(name).toLowerCase();
    if (mime == 'application/pdf' || extension == '.pdf') {
      // A mislabelled file (PDF mime with a text extension) is still refused
      // later by the PDF parser; here we only gate by declared type.
      return SharedFileKind.pdf;
    }
    if (mime != null && _textMimes.contains(mime)) return SharedFileKind.text;
    // Generic or missing MIME types fall back to the extension, but never an
    // executable or archive type.
    if ((mime == null ||
            mime == 'application/octet-stream' ||
            mime == 'text/*') &&
        _textExtensions.contains(extension)) {
      return SharedFileKind.text;
    }
    return null;
  }

  static bool _isInside(String root, String candidate) {
    if (candidate.isEmpty) return false;
    final normalizedRoot = p.normalize(p.absolute(root));
    final normalized = p.normalize(p.absolute(candidate));
    return p.isWithin(normalizedRoot, normalized);
  }

  /// Distinct http(s) URLs in [text], in order, without trailing punctuation.
  static List<String> extractLinks(String text) {
    final matches =
        RegExp(r'https?://[^\s<>"]+', caseSensitive: false).allMatches(text);
    final links = <String>[];
    for (final match in matches) {
      var url = match.group(0)!;
      url = url.replaceAll(RegExp(r'[).,;:!?\]}]+$'), '');
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        continue;
      }
      if (!links.contains(url)) links.add(url);
    }
    return links;
  }
}
