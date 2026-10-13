import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../services/file_service.dart';
import '../services/pdf_tools.dart';
import '../widgets/common.dart';
import 'result_page.dart';

enum OrganizeMode {
  organize('Organizar PDF', 'Reordene (arraste), gire e exclua páginas.',
      Icons.dashboard_customize, Color(0xFFF07F1A)),
  rotate('Girar PDF', 'Gire páginas individuais ou todas de uma vez.',
      Icons.rotate_right, Color(0xFF8E44AD)),
  remove('Remover páginas', 'Toque nas páginas que deseja excluir.',
      Icons.delete_sweep, Color(0xFFC0392B));

  const OrganizeMode(this.title, this.description, this.icon, this.color);
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

class OrganizePage extends StatefulWidget {
  const OrganizePage({super.key, required this.mode});

  final OrganizeMode mode;

  @override
  State<OrganizePage> createState() => _OrganizePageState();
}

class _OrganizePageState extends State<OrganizePage> {
  LoadedFile? _file;
  String? _password;
  PdfDocument? _doc;
  List<PageRef> _pages = [];
  final Set<int> _marked = {}; // páginas marcadas para remoção (modo remove)

  OrganizeMode get mode => widget.mode;

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  Future<String?> _passwordProvider() async {
    final pw = await askPassword(context);
    _password = pw;
    return pw;
  }

  Future<void> _pick() async {
    final file = await FileService.pickPdf();
    if (file == null || !mounted) return;
    final doc = await runBusy(
      context,
      () => PdfTools.open(file.bytes,
          sourceName: file.name, passwordProvider: _passwordProvider),
      message: 'Abrindo PDF...',
    );
    if (doc == null) return;
    _doc?.dispose();
    setState(() {
      _file = file;
      _doc = doc;
      _pages = [
        for (final p in doc.pages) PageRef(p.pageNumber, p.rotation),
      ];
      _marked.clear();
    });
  }

  void _rotate(PageRef p, {bool clockwise = true}) => setState(() {
        p.rotation = clockwise ? p.rotation.rotateCW90 : p.rotation.rotateCCW90;
      });

  void _rotateAll({bool clockwise = true}) => setState(() {
        for (final p in _pages) {
          p.rotation =
              clockwise ? p.rotation.rotateCW90 : p.rotation.rotateCCW90;
        }
      });

  void _move(int from, int to) {
    if (from == to) return;
    setState(() {
      final item = _pages.removeAt(from);
      _pages.insert(to, item);
    });
  }

  Future<void> _apply() async {
    final file = _file!;
    final pages = mode == OrganizeMode.remove
        ? _pages.where((p) => !_marked.contains(p.pageNumber)).toList()
        : _pages;
    final pw = _password;
    final bytes = await runBusy(
      context,
      () => PdfTools.rebuild(file.bytes, pages,
          passwordProvider: pw == null ? null : () => pw),
    );
    if (bytes == null || !mounted) return;
    final suffix = switch (mode) {
      OrganizeMode.organize => 'organizado',
      OrganizeMode.rotate => 'girado',
      OrganizeMode.remove => 'paginas_removidas',
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          title: mode.title,
          files: [LoadedFile('${file.baseName}_$suffix.pdf', bytes)],
        ),
      ),
    );
  }

  Widget _thumb(int index) {
    final p = _pages[index];
    final marked = _marked.contains(p.pageNumber);
    final scheme = Theme.of(context).colorScheme;
    final card = Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: marked ? Colors.red : scheme.outlineVariant,
          width: marked ? 3 : 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: PdfPageView(
                    document: _doc,
                    pageNumber: p.pageNumber,
                    rotationOverride: p.rotation,
                    decoration: const BoxDecoration(color: Colors.white),
                  ),
                ),
                if (marked)
                  Container(
                    color: Colors.red.withValues(alpha: 0.25),
                    child: const Icon(Icons.delete_forever,
                        size: 48, color: Colors.red),
                  ),
              ],
            ),
          ),
          Container(
            color: scheme.surfaceContainerHighest,
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('${p.pageNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (mode != OrganizeMode.remove)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Girar',
                    icon: const Icon(Icons.rotate_right, size: 20),
                    onPressed: () => _rotate(p),
                  ),
                if (mode == OrganizeMode.organize)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Excluir',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _pages.removeAt(index)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (mode == OrganizeMode.remove) {
      return GestureDetector(
        onTap: () => setState(() =>
            marked ? _marked.remove(p.pageNumber) : _marked.add(p.pageNumber)),
        child: card,
      );
    }
    if (mode == OrganizeMode.rotate) {
      return GestureDetector(onTap: () => _rotate(p), child: card);
    }

    // Modo organizar: arrastar e soltar para reordenar.
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => _move(d.data, index),
      builder: (context, candidate, _) => LayoutBuilder(
        builder: (context, box) => LongPressDraggable<int>(
          data: index,
          feedback: SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: Opacity(opacity: 0.85, child: card),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: candidate.isNotEmpty
                  ? Border.all(color: mode.color, width: 3)
                  : null,
            ),
            child: card,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDoc = _doc != null;
    final remaining = mode == OrganizeMode.remove
        ? _pages.length - _marked.length
        : _pages.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(mode.title),
        actions: [
          if (hasDoc && mode != OrganizeMode.remove) ...[
            IconButton(
              tooltip: 'Girar todas à esquerda',
              icon: const Icon(Icons.rotate_left),
              onPressed: () => _rotateAll(clockwise: false),
            ),
            IconButton(
              tooltip: 'Girar todas à direita',
              icon: const Icon(Icons.rotate_right),
              onPressed: _rotateAll,
            ),
          ],
          if (hasDoc)
            IconButton(
              tooltip: 'Trocar arquivo',
              icon: const Icon(Icons.file_open),
              onPressed: _pick,
            ),
        ],
      ),
      body: !hasDoc
          ? PickPrompt(
              icon: mode.icon,
              color: mode.color,
              title: mode.title,
              description: mode.description,
              buttonLabel: 'Selecionar PDF',
              onPick: _pick,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    mode == OrganizeMode.organize
                        ? 'Segure e arraste uma página para mudar a ordem.'
                        : mode.description,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 0.68,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _thumb(i),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: !hasDoc
          ? null
          : ActionBar(
              label: '${mode.title} ($remaining pág.)',
              color: mode.color,
              onPressed: remaining == 0 ? null : _apply,
            ),
    );
  }
}
