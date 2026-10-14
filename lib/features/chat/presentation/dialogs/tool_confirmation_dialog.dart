import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../services/tool_calling_service.dart';

/// Asks the user to approve one tool call.
///
/// The dialog states what the tool will do, whether anything leaves the
/// device and where it goes, and shows the exact arguments the model chose,
/// so an injected or mistaken value is visible before it is acted on.
class ToolConfirmationDialog extends StatelessWidget {
  final ToolDefinition tool;
  final ParsedToolCall call;

  const ToolConfirmationDialog({
    super.key,
    required this.tool,
    required this.call,
  });

  /// Shows the dialog and resolves to `true` only on an explicit approval.
  static Future<bool> show(
    BuildContext context, {
    required ToolDefinition tool,
    required ParsedToolCall call,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ToolConfirmationDialog(tool: tool, call: call),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final prettyArguments = const JsonEncoder.withIndent('  ').convert(
      call.arguments,
    );
    final leavesDevice = tool.requiresNetwork && tool.networkHost != null;

    return AlertDialog(
      icon: Icon(
        leavesDevice ? Icons.public_rounded : Icons.security_rounded,
        color: leavesDevice ? colors.tertiary : colors.primary,
      ),
      title: Text('Allow ${tool.name}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tool.description),
            const SizedBox(height: 12),
            if (tool.dataSent != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      leavesDevice
                          ? Icons.north_east_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tool.dataSent!,
                        key: const Key('tool-confirmation-data-sent'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('Risk: ${tool.riskLevel.name}',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text('Arguments chosen by the model',
                style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            SelectableText(
              prettyArguments,
              key: const Key('tool-confirmation-arguments'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Deny'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow once'),
        ),
      ],
    );
  }
}
