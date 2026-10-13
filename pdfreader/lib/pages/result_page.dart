import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../widgets/common.dart';
import 'viewer_page.dart';

/// Tela final de toda ferramenta: baixar o(s) arquivo(s) ou abrir no editor.
class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.title,
    required this.files,
    this.zipName = 'arquivos.zip',
  });

  final String title;
  final List<LoadedFile> files;
  final String zipName;

  Future<void> _download(BuildContext context, LoadedFile file) async {
    final ok = await FileService.save(file);
    if (ok && context.mounted) showMessage(context, '"${file.name}" salvo!');
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final single = files.length == 1;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(Icons.check_circle, size: 72, color: Colors.green.shade600),
              const SizedBox(height: 12),
              Text(
                single
                    ? 'Seu arquivo está pronto!'
                    : '${files.length} arquivos prontos!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (!single) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18)),
                  onPressed: () =>
                      _download(context, FileService.zip(zipName, files)),
                  icon: const Icon(Icons.folder_zip),
                  label: Text('Baixar tudo ($zipName)'),
                ),
                const SizedBox(height: 16),
              ],
              for (final f in files)
                Card(
                  child: ListTile(
                    leading: Icon(
                      f.isPdf
                          ? Icons.picture_as_pdf
                          : f.mimeType.startsWith('image')
                              ? Icons.image
                              : Icons.description,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(f.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(_size(f.bytes.length)),
                    trailing: Wrap(
                      children: [
                        if (f.isPdf)
                          IconButton(
                            tooltip: 'Abrir / editar',
                            icon: const Icon(Icons.visibility),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ViewerPage(file: f)),
                            ),
                          ),
                        IconButton(
                          tooltip: 'Baixar',
                          icon: const Icon(Icons.download),
                          onPressed: () => _download(context, f),
                        ),
                      ],
                    ),
                  ),
                ),
              if (single) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18)),
                  onPressed: () => _download(context, files.first),
                  icon: const Icon(Icons.download),
                  label: const Text('Baixar'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.home),
                label: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
