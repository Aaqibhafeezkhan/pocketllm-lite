# RAG evaluation corpus

Small, original documents written for this repository and released under the
repository's MIT license, so they can be redistributed freely. They contain no
real people, no third-party text and no personal data.

- `docs/*.md`: three short documents on unrelated topics.
- `questions.json`: 12 questions with the document and the exact phrase that a
  correct retrieval must surface in the top results.
- `test/services/rag_eval_test.dart`: ingests the documents with the real
  ingestion service, indexes them with the real vector store, and measures
  hit rate at 3 and mean reciprocal rank for **keyword** retrieval, plus
  document isolation. Semantic and hybrid modes need an embedding runtime and
  are not covered here.

The thresholds in the test guard against regressions in chunking and keyword
ranking. They are not a quality claim about semantic retrieval or any model.

To add a case, append to `questions.json` with the document file name and a
distinctive `answerPhrase` that appears verbatim in that document.
