import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/m3_app_bar.dart';

class LocalModelHelpScreen extends StatelessWidget {
  const LocalModelHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(
        title: 'GGUF Local Model Help',
        subtitle: 'Understand offline local execution',
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // GGUF Overview Card
          _buildInfoCard(
            context: context,
            icon: Icons.memory_rounded,
            title: 'What is GGUF & Cactus?',
            description:
                'GGUF is the file format used by llama.cpp and Ollama. The on-device runtime in this build (Cactus) does not read GGUF: it loads its own bundle format (a config.txt plus *.weights files), which the Model Store downloads for you, including Whisper for speech. GGUF files from Hugging Face are meant for Ollama or any OpenAI-compatible server that PocketLLM connects to.',
          ),
          const SizedBox(height: 20),

          // stand-alone llama.cpp vs Ollama connection
          _buildSectionHeader(theme, 'Comparison: Standalone Local vs Ollama'),
          const SizedBox(height: 12),
          _buildComparisonTable(context),
          const SizedBox(height: 24),

          // Custom GGUF File Picker instructions
          _buildInfoCard(
            context: context,
            icon: Icons.file_open_rounded,
            title: 'How to Import Custom GGUF Models?',
            description:
                '1. For on-device use, open the Model Store and download a model: those bundles are the format the runtime loads.\n'
                '2. To use a GGUF from Hugging Face, copy its Ollama command from the model page and run it on the computer that hosts Ollama.\n'
                '3. Then add that Ollama server in Settings so PocketLLM can chat with it.\n'
                '4. A GGUF imported onto the phone is stored but not loadable by the built-in runtime.',
          ),
          const SizedBox(height: 20),

          // Optimizing parameters
          _buildInfoCard(
            context: context,
            icon: Icons.tune_rounded,
            title: 'Optimizer Settings & Hardware Tips',
            description:
                '• Context Window: Higher values consume more memory. Use the smallest context that fits your task and the model/runtime limit; no one value is ideal for every phone.\n'
                '• Quantization and model size: Smaller files often need less memory, but architecture and runtime support still matter.\n'
                '• Device conditions: Monitor free RAM, storage, battery, and temperature. PocketLLM does not claim a GPU or NPU path unless runtime evidence identifies it.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            verticalInside: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(1.4),
          },
          children: [
            // Header Row
            TableRow(
              decoration: BoxDecoration(color: colorScheme.primaryContainer),
              children: [
                _buildTableCell('Feature', theme,
                    isHeader: true, color: colorScheme.onPrimaryContainer),
                _buildTableCell('Standalone (Cactus AI)', theme,
                    isHeader: true, color: colorScheme.onPrimaryContainer),
                _buildTableCell('Ollama Connection', theme,
                    isHeader: true, color: colorScheme.onPrimaryContainer),
              ],
            ),
            // Rows
            TableRow(
              children: [
                _buildTableCell('Setup', theme),
                _buildTableCell(
                    'Download a Cactus-format model from the Model Store (GGUF is not read by this runtime).',
                    theme),
                _buildTableCell(
                    'Requires a reachable Ollama host. Official support covers macOS, Windows, and Linux; Android/Termux is experimental.',
                    theme),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Offline', theme),
                _buildTableCell(
                    'Inference can run offline after a compatible model is available locally.',
                    theme),
                _buildTableCell(
                    'Uses HTTP to the configured host. Same-device loopback can stay local; LAN or remote hosts use a network connection.',
                    theme),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Imports', theme),
                _buildTableCell(
                    'Stores GGUF files, which this runtime cannot load; Ollama serves them instead.',
                    theme),
                _buildTableCell(
                    'Uses models returned by the host API; manage them with current Ollama tools.',
                    theme),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Speed', theme),
                _buildTableCell(
                    'Performance varies by model, quantization, device, and thermal state.',
                    theme),
                _buildTableCell(
                    'Depends on host hardware, model, context, and network path.',
                    theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, ThemeData theme,
      {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: color ?? theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
