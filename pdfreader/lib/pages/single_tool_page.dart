import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../services/pdf_tools.dart';
import '../widgets/common.dart';
import 'result_page.dart';

enum SingleTool {
  watermark('Marca d\'água', 'Carimbe um texto sobre todas as páginas do PDF.',
      Icons.branding_watermark, Color(0xFF2980B9)),
  pageNumbers('Numerar páginas', 'Adicione números de página com facilidade.',
      Icons.format_list_numbered, Color(0xFF27AE60)),
  protect('Proteger PDF', 'Criptografe o PDF com uma senha.', Icons.lock,
      Color(0xFF34495E)),
  unlock('Desbloquear PDF', 'Remova a senha de um PDF protegido.',
      Icons.lock_open, Color(0xFF7F8C8D)),
  toImages('PDF para imagem', 'Converta cada página do PDF em uma imagem PNG.',
      Icons.image, Color(0xFFF1C40F)),
  extractText('Extrair texto', 'Copie ou baixe todo o texto do PDF em .txt.',
      Icons.notes, Color(0xFF6C5CE7));

  const SingleTool(this.title, this.description, this.icon, this.color);
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

const _wmColors = <Color>[
  Color(0xFFE5322D),
  Colors.blue,
  Colors.green,
  Colors.grey,
  Colors.black,
];

class SingleToolPage extends StatefulWidget {
  const SingleToolPage({super.key, required this.tool});

  final SingleTool tool;

  @override
  State<SingleToolPage> createState() => _SingleToolPageState();
}

class _SingleToolPageState extends State<SingleToolPage> {
  LoadedFile? _file;
  final _text = TextEditingController(text: 'CONFIDENCIAL');
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _obscure = true;

  // marca d'água
  double _fontSize = 60, _opacity = 0.25;
  Color _wmColor = _wmColors.first;
  bool _diagonal = true;

  // numeração
  NumberPosition _position = NumberPosition.bottomCenter;
  bool _withTotal = false;
  int _startAt = 1;

  // imagens
  double _dpi = 150;

  SingleTool get tool => widget.tool;

  @override
  void dispose() {
    _text.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await FileService.pickPdf();
    if (file != null) setState(() => _file = file);
  }

  Future<void> _run() async {
    final file = _file!;
    final name = file.baseName;
    if (tool == SingleTool.protect) {
      if (_password.text.isEmpty) {
        return showMessage(context, 'Digite uma senha.');
      }
      if (_password.text != _password2.text) {
        return showMessage(context, 'As senhas não coincidem.');
      }
    }
    final out = await runBusy<List<LoadedFile>>(context, () async {
      switch (tool) {
        case SingleTool.watermark:
          return [
            LoadedFile(
                '${name}_marca_dagua.pdf',
                await PdfTools.watermark(file.bytes,
                    text: _text.text,
                    fontSize: _fontSize,
                    opacity: _opacity,
                    color: _wmColor,
                    diagonal: _diagonal)),
          ];
        case SingleTool.pageNumbers:
          return [
            LoadedFile(
                '${name}_numerado.pdf',
                await PdfTools.addPageNumbers(file.bytes,
                    position: _position,
                    withTotal: _withTotal,
                    startAt: _startAt)),
          ];
        case SingleTool.protect:
          return [
            LoadedFile('${name}_protegido.pdf',
                await PdfTools.protect(file.bytes, _password.text)),
          ];
        case SingleTool.unlock:
          return [
            LoadedFile('${name}_desbloqueado.pdf',
                await PdfTools.unlock(file.bytes, _password.text)),
          ];
        case SingleTool.toImages:
          return PdfTools.toImages(file, dpi: _dpi);
        case SingleTool.extractText:
          final text = await PdfTools.extractText(file.bytes);
          return [LoadedFile('$name.txt', PdfTools.textFile(text))];
      }
    });
    if (out == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          title: tool.title,
          files: out,
          zipName: '${name}_imagens.zip',
        ),
      ),
    );
  }

  Widget _passwordField(TextEditingController c, String label) => TextField(
        controller: c,
        obscureText: _obscure,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );

  List<Widget> _options() {
    switch (tool) {
      case SingleTool.watermark:
        return [
          TextField(
            controller: _text,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'Texto da marca'),
          ),
          const SizedBox(height: 16),
          Text('Tamanho da fonte: ${_fontSize.round()}'),
          Slider(
              value: _fontSize,
              min: 20,
              max: 120,
              onChanged: (v) => setState(() => _fontSize = v)),
          Text('Transparência: ${(_opacity * 100).round()}%'),
          Slider(
              value: _opacity,
              min: 0.05,
              max: 1,
              onChanged: (v) => setState(() => _opacity = v)),
          const Text('Cor'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final c in _wmColors)
                ChoiceChip(
                  label: const SizedBox.shrink(),
                  avatar: CircleAvatar(backgroundColor: c),
                  selected: _wmColor == c,
                  onSelected: (_) => setState(() => _wmColor = c),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Diagonal'),
            value: _diagonal,
            onChanged: (v) => setState(() => _diagonal = v),
          ),
        ];
      case SingleTool.pageNumbers:
        return [
          DropdownButtonFormField<NumberPosition>(
            initialValue: _position,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'Posição'),
            items: [
              for (final p in NumberPosition.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (v) => setState(() => _position = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: '$_startAt',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Começar a numeração em'),
            onChanged: (v) => _startAt = int.tryParse(v) ?? 1,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Formato "Página X de Y"'),
            value: _withTotal,
            onChanged: (v) => setState(() => _withTotal = v),
          ),
        ];
      case SingleTool.protect:
        return [
          _passwordField(_password, 'Senha'),
          const SizedBox(height: 16),
          _passwordField(_password2, 'Repita a senha'),
          const SizedBox(height: 8),
          const Text('Criptografia AES 256 bits.'),
        ];
      case SingleTool.unlock:
        return [
          _passwordField(_password, 'Senha atual do PDF'),
        ];
      case SingleTool.toImages:
        return [
          Text('Qualidade: ${_dpi.round()} DPI'),
          Slider(
            value: _dpi,
            min: 72,
            max: 300,
            divisions: 19,
            label: '${_dpi.round()}',
            onChanged: (v) => setState(() => _dpi = v),
          ),
        ];
      case SingleTool.extractText:
        return const [
          Text('O texto de todas as páginas será salvo em um arquivo .txt. '
              'PDFs escaneados (somente imagem) não possuem texto extraível.'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return Scaffold(
      appBar: AppBar(title: Text(tool.title)),
      body: file == null
          ? PickPrompt(
              icon: tool.icon,
              color: tool.color,
              title: tool.title,
              description: tool.description,
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
                        leading: Icon(Icons.picture_as_pdf, color: tool.color),
                        title: Text(file.name),
                        trailing: TextButton(
                            onPressed: _pick, child: const Text('Trocar')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._options(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: file == null
          ? null
          : ActionBar(label: tool.title, color: tool.color, onPressed: _run),
    );
  }
}
