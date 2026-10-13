import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../services/pdf_tools.dart';
import '../widgets/common.dart';
import 'result_page.dart';

const _color = Color(0xFFE5322D);

class MergePage extends StatefulWidget {
  const MergePage({super.key});

  @override
  State<MergePage> createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  final List<(LoadedFile, int)> _files = []; // arquivo + nº de páginas

  Future<void> _add() async {
    final picked = await FileService.pickPdfs();
    if (picked.isEmpty || !mounted) return;
    final loaded = await runBusy(context, () async {
      return [for (final f in picked) (f, await PdfTools.pageCount(f.bytes))];
    }, message: 'Lendo arquivos...');
    if (loaded != null) setState(() => _files.addAll(loaded));
  }

  Future<void> _merge() async {
    final bytes = await runBusy(
      context,
      () => PdfTools.merge([for (final f in _files) f.$1]),
      message: 'Juntando PDFs...',
    );
    if (bytes == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          title: 'Juntar PDF',
          files: [LoadedFile('pdf_unido.pdf', bytes)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _files.fold<int>(0, (s, f) => s + f.$2);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Juntar PDF'),
        actions: [
          if (_files.isNotEmpty)
            IconButton(
                tooltip: 'Adicionar mais',
                icon: const Icon(Icons.add),
                onPressed: _add),
        ],
      ),
      body: _files.isEmpty
          ? PickPrompt(
              icon: Icons.merge_type,
              color: _color,
              title: 'Juntar PDF',
              description:
                  'Combine vários PDFs em um só, na ordem que você quiser.',
              buttonLabel: 'Selecionar PDFs',
              onPick: _add,
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Arraste pela alça (≡) para mudar a ordem.'),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _files.length,
                    onReorderItem: (from, to) => setState(() {
                      _files.insert(to, _files.removeAt(from));
                    }),
                    itemBuilder: (_, i) {
                      final (file, pages) = _files[i];
                      return Card(
                        key: ObjectKey(_files[i]),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _color.withValues(alpha: 0.12),
                            child: Text('${i + 1}',
                                style: const TextStyle(color: _color)),
                          ),
                          title: Text(file.name,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text('$pages página(s)'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _files.removeAt(i)),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Icon(Icons.drag_handle),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _files.isEmpty
          ? null
          : ActionBar(
              label: 'Juntar ${_files.length} PDFs ($total pág.)',
              color: _color,
              onPressed: _files.length < 2 ? null : _merge,
            ),
    );
  }
}
