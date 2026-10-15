/// Builds the Ollama command that pulls and runs a Hugging Face GGUF.
///
/// Ollama documents `hf.co/{owner}/{repo}[:{quantization}]` as a model name,
/// so a GGUF found on Hugging Face can be served from a computer running
/// Ollama and used from PocketLLM as a remote runtime.
///
/// Returns null when [repoId] is not a plain `owner/repo` identifier, so a
/// malformed or hostile id can never be turned into a shell command.
String? ollamaRunCommand(String repoId, String? quantization) {
  final repo =
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$');
  if (!repo.hasMatch(repoId)) return null;
  final quant = quantization?.trim();
  final validQuant = quant != null &&
      RegExp(r'^[A-Za-z0-9_]+$').hasMatch(quant) &&
      quant != 'Unknown';
  return validQuant
      ? 'ollama run hf.co/$repoId:$quant'
      : 'ollama run hf.co/$repoId';
}
