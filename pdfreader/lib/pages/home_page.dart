import 'package:flutter/material.dart';

import 'images_to_pdf_page.dart';
import 'merge_page.dart';
import 'organize_page.dart';
import 'single_tool_page.dart';
import 'split_page.dart';
import 'viewer_page.dart';

class _Tool {
  const _Tool(this.title, this.description, this.icon, this.color, this.page);

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final WidgetBuilder page;
}

final _tools = <_Tool>[
  _Tool('Ler e editar PDF', 'Leia, destaque, anote, escreva e baixe.',
      Icons.chrome_reader_mode, const Color(0xFFE5322D), (_) => const ViewerPage()),
  _Tool('Juntar PDF', 'Combine vários PDFs em um só.', Icons.merge_type,
      const Color(0xFFE5322D), (_) => const MergePage()),
  _Tool('Dividir PDF', 'Separe páginas ou intervalos.', Icons.call_split,
      const Color(0xFF16A085), (_) => const SplitPage()),
  for (final m in OrganizeMode.values)
    _Tool(m.title, m.description, m.icon, m.color,
        (_) => OrganizePage(mode: m)),
  _Tool('Imagem para PDF', 'Converta JPG e PNG em PDF.',
      Icons.add_photo_alternate, const Color(0xFFF39C12),
      (_) => const ImagesToPdfPage()),
  for (final t in SingleTool.values)
    _Tool(t.title, t.description, t.icon, t.color,
        (_) => SingleToolPage(tool: t)),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text('PDF Reader'),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Todas as ferramentas para trabalhar com PDF em um só lugar. '
                'Tudo é processado no seu dispositivo — nada é enviado para a internet.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 170,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _tools.length,
              itemBuilder: (context, i) => _ToolCard(tool: _tools[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: tool.page)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tool.icon, color: tool.color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(tool.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  tool.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
