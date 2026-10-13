import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../services/file_service.dart';
import '../services/pdf_tools.dart';
import '../widgets/common.dart';

/// Modos da barra de edição. [text] é nosso (carimba texto no PDF);
/// os demais são anotações nativas do SfPdfViewer.
enum EditMode {
  read('Ler', Icons.pan_tool_alt_outlined, PdfAnnotationMode.none),
  highlight('Destacar', Icons.highlight, PdfAnnotationMode.highlight),
  underline('Sublinhar', Icons.format_underline, PdfAnnotationMode.underline),
  strike('Riscar', Icons.format_strikethrough, PdfAnnotationMode.strikethrough),
  squiggly('Ondulado', Icons.waves, PdfAnnotationMode.squiggly),
  note('Nota', Icons.sticky_note_2_outlined, PdfAnnotationMode.stickyNote),
  text('Texto', Icons.text_fields, PdfAnnotationMode.none);

  const EditMode(this.label, this.icon, this.annotationMode);
  final String label;
  final IconData icon;
  final PdfAnnotationMode annotationMode;
}

const _palette = <Color>[
  Colors.yellow,
  Colors.lightGreen,
  Colors.lightBlue,
  Colors.pinkAccent,
  Colors.orange,
  Colors.red,
  Colors.black,
];

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, this.file});

  final LoadedFile? file;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  final _controller = PdfViewerController();
  final _undo = UndoHistoryController();
  final _searchController = TextEditingController();

  LoadedFile? _file;
  Uint8List? _bytes;
  int _version = 0; // força recarregar o viewer quando os bytes mudam
  EditMode _mode = EditMode.read;
  Color _textColor = Colors.black;
  Annotation? _selected;
  bool _searching = false;
  PdfTextSearchResult _searchResult = PdfTextSearchResult();
  int _page = 1, _pageCount = 0;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    if (widget.file != null) _load(widget.file!);
  }

  @override
  void dispose() {
    _searchResult.removeListener(_refresh);
    _controller.dispose();
    _undo.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _load(LoadedFile file) {
    setState(() {
      _file = file;
      _bytes = file.bytes;
      _version++;
      _dirty = false;
    });
  }

  Future<void> _pick() async {
    final file = await FileService.pickPdf();
    if (file != null) _load(file);
  }

  void _setMode(EditMode mode) {
    setState(() => _mode = mode);
    _controller.annotationMode = mode.annotationMode;
  }

  void _setColor(Color color) {
    final s = _controller.annotationSettings;
    switch (_mode) {
      case EditMode.highlight:
        s.highlight.color = color;
      case EditMode.underline:
        s.underline.color = color;
      case EditMode.strike:
        s.strikethrough.color = color;
      case EditMode.squiggly:
        s.squiggly.color = color;
      case EditMode.note:
        s.stickyNote.color = color;
      case EditMode.text:
        _textColor = color;
      case EditMode.read:
        break;
    }
    _selected?.color = color;
    setState(() {});
  }

  Color get _currentColor {
    final s = _controller.annotationSettings;
    return switch (_mode) {
      EditMode.highlight => s.highlight.color,
      EditMode.underline => s.underline.color,
      EditMode.strike => s.strikethrough.color,
      EditMode.squiggly => s.squiggly.color,
      EditMode.note => s.stickyNote.color,
      EditMode.text => _textColor,
      EditMode.read => _selected?.color ?? Colors.transparent,
    };
  }

  Future<Uint8List> _currentBytes() async =>
      Uint8List.fromList(await _controller.saveDocument());

  Future<void> _onTap(PdfGestureDetails details) async {
    if (_mode != EditMode.text || details.pageNumber < 1) return;
    final result = await showDialog<(String, double, bool)>(
      context: context,
      builder: (_) => const _TextDialog(),
    );
    if (result == null || result.$1.trim().isEmpty || !mounted) return;
    final page = _controller.pageNumber;
    final newBytes = await runBusy(context, () async {
      return PdfTools.addText(
        await _currentBytes(),
        pageNumber: details.pageNumber,
        position: details.pagePosition,
        text: result.$1,
        fontSize: result.$2,
        bold: result.$3,
        color: _textColor,
      );
    }, message: 'Adicionando texto...');
    if (newBytes == null) return;
    setState(() {
      _bytes = newBytes;
      _version++;
      _dirty = true;
      _page = page;
    });
  }

  Future<void> _download() async {
    final file = _file;
    if (file == null) return;
    final bytes = await runBusy(context, _currentBytes, message: 'Gerando PDF...');
    if (bytes == null) return;
    final name = _dirty || _undo.value.canUndo
        ?'${file.baseName}_editado.pdf'
        : file.name;
    final ok = await FileService.save(LoadedFile(name, bytes));
    if (ok && mounted) showMessage(context, 'PDF salvo como "$name"');
  }

  void _search(String text) {
    _searchResult.removeListener(_refresh);
    _searchResult = _controller.searchText(text)..addListener(_refresh);
    setState(() {});
  }

  void _closeSearch() {
    _searchResult
      ..removeListener(_refresh)
      ..clear();
    _searchController.clear();
    setState(() => _searching = false);
  }

  Future<void> _goToPage() async {
    final ctrl = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ir para página'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 – $_pageCount'),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
              child: const Text('Ir')),
        ],
      ),
    );
    if (n != null && n >= 1 && n <= _pageCount) _controller.jumpToPage(n);
  }

  PreferredSizeWidget _appBar() {
    if (_searching) {
      final r = _searchResult;
      return AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: _closeSearch),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
              hintText: 'Buscar no documento', border: InputBorder.none),
          onSubmitted: _search,
        ),
        actions: [
          if (r.hasResult)
            Center(
                child: Text('${r.currentInstanceIndex}/${r.totalInstanceCount}')),
          IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: r.hasResult ? r.previousInstance : null),
          IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: r.hasResult ? r.nextInstance : null),
        ],
      );
    }
    return AppBar(
      title: Text(_file?.name ?? 'Ler e editar PDF',
          overflow: TextOverflow.ellipsis),
      actions: _bytes == null
          ? null
          : [
              IconButton(
                tooltip: 'Buscar',
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _searching = true),
              ),
              ValueListenableBuilder(
                valueListenable: _undo,
                builder: (_, value, _) => Row(children: [
                  IconButton(
                    tooltip: 'Desfazer',
                    icon: const Icon(Icons.undo),
                    onPressed: value.canUndo ? _undo.undo : null,
                  ),
                  IconButton(
                    tooltip: 'Refazer',
                    icon: const Icon(Icons.redo),
                    onPressed: value.canRedo ? _undo.redo : null,
                  ),
                ]),
              ),
              IconButton(
                tooltip: 'Baixar PDF',
                icon: const Icon(Icons.download),
                onPressed: _download,
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'open':
                      _pick();
                    case 'page':
                      _goToPage();
                    case 'zoomIn':
                      _controller.zoomLevel = (_controller.zoomLevel + 0.25).clamp(1, 3);
                    case 'zoomOut':
                      _controller.zoomLevel = (_controller.zoomLevel - 0.25).clamp(1, 3);
                    case 'clear':
                      _controller.removeAllAnnotations();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('Abrir outro PDF')),
                  PopupMenuItem(value: 'page', child: Text('Ir para página')),
                  PopupMenuItem(value: 'zoomIn', child: Text('Aumentar zoom')),
                  PopupMenuItem(value: 'zoomOut', child: Text('Diminuir zoom')),
                  PopupMenuItem(
                      value: 'clear', child: Text('Remover todas as anotações')),
                ],
              ),
            ],
    );
  }

  Widget _toolbar() {
    final theme = Theme.of(context);
    final showColors = _mode != EditMode.read || _selected != null;
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showColors)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final c in _palette)
                      GestureDetector(
                        onTap: () => _setColor(c),
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: _currentColor.toARGB32() == c.toARGB32() ? 3 : 1,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    if (_selected != null) ...[
                      const VerticalDivider(),
                      TextButton.icon(
                        onPressed: () {
                          _controller.removeAnnotation(_selected!);
                          setState(() => _selected = null);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Excluir anotação'),
                      ),
                    ],
                  ],
                ),
              ),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final m in EditMode.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _ModeButton(
                        mode: m,
                        selected: m == _mode,
                        onTap: () => _setMode(m),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    return Scaffold(
      appBar: _appBar(),
      body: bytes == null
          ? PickPrompt(
              icon: Icons.chrome_reader_mode,
              color: const Color(0xFFE5322D),
              title: 'Ler e editar PDF',
              description:
                  'Leia, pesquise, destaque, sublinhe, adicione notas e textos e baixe o PDF editado.',
              buttonLabel: 'Selecionar PDF',
              onPick: _pick,
            )
          : Stack(
              children: [
                SfPdfViewer.memory(
                  bytes,
                  key: ValueKey(_version),
                  controller: _controller,
                  undoController: _undo,
                  initialPageNumber: _page,
                  canShowPasswordDialog: true,
                  onTap: _onTap,
                  onDocumentLoaded: (d) => setState(() {
                    _pageCount = d.document.pages.count;
                    _controller.annotationMode = _mode.annotationMode;
                  }),
                  onDocumentLoadFailed: (d) =>
                      showMessage(context, '${d.error}: ${d.description}'),
                  onPageChanged: (d) => setState(() => _page = d.newPageNumber),
                  onAnnotationAdded: (_) => _dirty = true,
                  onAnnotationSelected: (a) => setState(() => _selected = a),
                  onAnnotationDeselected: (_) =>
                      setState(() => _selected = null),
                ),
                if (_pageCount > 0)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: GestureDetector(
                      onTap: _goToPage,
                      child: Chip(label: Text('$_page / $_pageCount')),
                    ),
                  ),
                if (_mode == EditMode.text)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: Chip(
                      avatar: Icon(Icons.touch_app, size: 18),
                      label: Text('Toque na página para inserir texto'),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: bytes == null ? null : _toolbar(),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton(
      {required this.mode, required this.selected, required this.onTap});

  final EditMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        width: 72,
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(mode.icon, color: fg),
            const SizedBox(height: 2),
            Text(mode.label, style: TextStyle(fontSize: 12, color: fg)),
          ],
        ),
      ),
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog();

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _text = TextEditingController();
  double _size = 14;
  bool _bold = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar texto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Texto'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Tamanho'),
            Expanded(
              child: Slider(
                value: _size,
                min: 8,
                max: 48,
                divisions: 40,
                label: _size.round().toString(),
                onChanged: (v) => setState(() => _size = v),
              ),
            ),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _bold,
            title: const Text('Negrito'),
            onChanged: (v) => setState(() => _bold = v ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_text.text, _size, _bold)),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
