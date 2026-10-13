import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../services/pdf_tools.dart';
import '../widgets/common.dart';
import 'result_page.dart';

const _color = Color(0xFFF39C12);

class ImagesToPdfPage extends StatefulWidget {
  const ImagesToPdfPage({super.key});

  @override
  State<ImagesToPdfPage> createState() => _ImagesToPdfPageState();
}

class _ImagesToPdfPageState extends State<ImagesToPdfPage> {
  final List<LoadedFile> _images = [];
  bool _a4 = true;
  double _margin = 20;

  Future<void> _add() async {
    final picked = await FileService.pickImages();
    if (picked.isNotEmpty) setState(() => _images.addAll(picked));
  }

  Future<void> _convert() async {
    final bytes = await runBusy(
      context,
      () => PdfTools.imagesToPdf(_images, a4: _a4, margin: _margin),
      message: 'Convertendo imagens...',
    );
    if (bytes == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          title: 'Imagem para PDF',
          files: [LoadedFile('imagens.pdf', bytes)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Imagem para PDF'),
        actions: [
          if (_images.isNotEmpty)
            IconButton(
                tooltip: 'Adicionar mais',
                icon: const Icon(Icons.add_photo_alternate),
                onPressed: _add),
        ],
      ),
      body: _images.isEmpty
          ? PickPrompt(
              icon: Icons.add_photo_alternate,
              color: _color,
              title: 'Imagem para PDF',
              description:
                  'Converta imagens JPG e PNG em um PDF. Ajuste a ordem e as margens.',
              buttonLabel: 'Selecionar imagens',
              onPick: _add,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('A4')),
                          ButtonSegment(
                              value: false, label: Text('Tamanho da imagem')),
                        ],
                        selected: {_a4},
                        onSelectionChanged: (s) =>
                            setState(() => _a4 = s.first),
                      ),
                      if (_a4)
                        SizedBox(
                          width: 260,
                          child: Row(children: [
                            Text('Margem ${_margin.round()}'),
                            Expanded(
                              child: Slider(
                                value: _margin,
                                max: 60,
                                onChanged: (v) => setState(() => _margin = v),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _images.length,
                    onReorderItem: (from, to) => setState(() {
                      _images.insert(to, _images.removeAt(from));
                    }),
                    itemBuilder: (_, i) {
                      final img = _images[i];
                      return Card(
                        key: ObjectKey(img),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(img.bytes,
                                width: 56, height: 56, fit: BoxFit.cover),
                          ),
                          title:
                              Text(img.name, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Página ${i + 1}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _images.removeAt(i)),
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
      bottomNavigationBar: _images.isEmpty
          ? null
          : ActionBar(
              label: 'Converter ${_images.length} imagem(ns)',
              color: _color,
              onPressed: _convert,
            ),
    );
  }
}
