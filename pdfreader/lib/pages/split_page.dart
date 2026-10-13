import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../services/pdf_tools.dart';
import '../widgets/common.dart';
import 'result_page.dart';

const _color = Color(0xFF16A085);

enum SplitMode { ranges, everyPage, extract }

class SplitPage extends StatefulWidget {
  const SplitPage({super.key});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  LoadedFile? _file;
  int _pageCount = 0;
  SplitMode _mode = SplitMode.ranges;
  final _ranges = TextEditingController();

  @override
  void dispose() {
    _ranges.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await FileService.pickPdf();
    if (file == null || !mounted) return;
    final count = await runBusy(context, () => PdfTools.pageCount(file.bytes));
    if (count == null) return;
    setState(() {
      _file = file;
      _pageCount = count;
      _ranges.text = count > 1 ? '1-${(count / 2).ceil()}, ${(count / 2).ceil() + 1}-$count' : '1';
    });
  }

  Future<void> _split() async {
    final file = _file!;
    final files = await runBusy(context, () async {
      if (_mode == SplitMode.everyPage) {
        final ranges = [for (var i = 1; i <= _pageCount; i++) [i]];
        final out = await PdfTools.split(file.bytes, ranges);
        return [
          for (var i = 0; i < out.length; i++)
            LoadedFile('${file.baseName}_pagina_${i + 1}.pdf', out[i]),
        ];
      }
      final ranges = PdfTools.parseRanges(_ranges.text, _pageCount);
      if (_mode == SplitMode.extract) {
        final out = await PdfTools.split(
            file.bytes, [ranges.expand((r) => r).toList()]);
        return [LoadedFile('${file.baseName}_extraido.pdf', out.first)];
      }
      final out = await PdfTools.split(file.bytes, ranges);
      return [
        for (var i = 0; i < out.length; i++)
          LoadedFile(
              '${file.baseName}_${ranges[i].first}-${ranges[i].last}.pdf',
              out[i]),
      ];
    }, message: 'Dividindo PDF...');
    if (files == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          title: 'Dividir PDF',
          files: files,
          zipName: '${file.baseName}_dividido.zip',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return Scaffold(
      appBar: AppBar(title: const Text('Dividir PDF')),
      body: file == null
          ? PickPrompt(
              icon: Icons.call_split,
              color: _color,
              title: 'Dividir PDF',
              description:
                  'Separe intervalos de páginas ou extraia cada página em um PDF independente.',
              buttonLabel: 'Selecionar PDF',
              onPick: _pick,
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf,
                            color: _color),
                        title: Text(file.name),
                        subtitle: Text('$_pageCount página(s)'),
                        trailing: TextButton(
                            onPressed: _pick, child: const Text('Trocar')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<SplitMode>(
                      segments: const [
                        ButtonSegment(
                            value: SplitMode.ranges,
                            label: Text('Intervalos'),
                            icon: Icon(Icons.view_week)),
                        ButtonSegment(
                            value: SplitMode.everyPage,
                            label: Text('Cada página'),
                            icon: Icon(Icons.filter_none)),
                        ButtonSegment(
                            value: SplitMode.extract,
                            label: Text('Extrair'),
                            icon: Icon(Icons.content_cut)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                    const SizedBox(height: 20),
                    if (_mode == SplitMode.everyPage)
                      Text(
                          'Serão gerados $_pageCount PDFs, um para cada página.')
                    else ...[
                      TextField(
                        controller: _ranges,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _mode == SplitMode.ranges
                              ? 'Intervalos (um PDF por intervalo)'
                              : 'Páginas a extrair (em um único PDF)',
                          hintText: 'Ex.: 1-3, 5, 8-10',
                          helperText: 'Páginas de 1 a $_pageCount',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      bottomNavigationBar: file == null
          ? null
          : ActionBar(label: 'Dividir PDF', color: _color, onPressed: _split),
    );
  }
}
