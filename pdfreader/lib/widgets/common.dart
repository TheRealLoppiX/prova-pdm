import 'package:flutter/material.dart';

import '../services/pdf_tools.dart';

Future<T?> runBusy<T>(
  BuildContext context,
  Future<T> Function() task, {
  String message = 'Processando...',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  try {
    return await task();
  } catch (e) {
    final text = e is PdfToolException ? e.message : 'Erro: $e';
    messenger.showSnackBar(SnackBar(content: Text(text)));
    return null;
  } finally {
    navigator.pop();
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Tela vazia inicial de uma ferramenta, com o botão grande de seleção.
class PickPrompt extends StatelessWidget {
  const PickPrompt({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPick,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, size: 44, color: color),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(description,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  textStyle: theme.textTheme.titleMedium,
                ),
                onPressed: onPick,
                icon: const Icon(Icons.upload_file),
                label: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra inferior com o botão de ação principal da ferramenta.
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

Future<String?> askPassword(BuildContext context, {String? title}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? 'PDF protegido por senha'),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Senha'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK')),
      ],
    ),
  );
}
