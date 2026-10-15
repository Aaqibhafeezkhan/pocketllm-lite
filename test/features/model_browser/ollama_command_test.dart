import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/features/model_browser/domain/ollama_command.dart';

void main() {
  test('builds a pull command with the quantization tag', () {
    expect(
      ollamaRunCommand('bartowski/Llama-3.2-1B-Instruct-GGUF', 'Q4_K_M'),
      'ollama run hf.co/bartowski/Llama-3.2-1B-Instruct-GGUF:Q4_K_M',
    );
  });

  test('omits the tag when the quantization is unknown or absent', () {
    expect(ollamaRunCommand('a/b', 'Unknown'), 'ollama run hf.co/a/b');
    expect(ollamaRunCommand('a/b', null), 'ollama run hf.co/a/b');
    expect(ollamaRunCommand('a/b', ' '), 'ollama run hf.co/a/b');
  });

  test('refuses ids and tags that could inject shell syntax', () {
    for (final bad in [
      'owner/repo; rm -rf /',
      'owner/repo && curl evil',
      r'owner/$(id)',
      'owner/repo\nother',
      'just-a-name',
      '../etc/passwd',
      'a/b/c',
    ]) {
      expect(ollamaRunCommand(bad, 'Q4_K_M'), isNull, reason: bad);
    }
    expect(
      ollamaRunCommand('a/b', 'Q4;reboot'),
      'ollama run hf.co/a/b',
      reason: 'an unsafe tag is dropped, never passed through',
    );
  });
}
