import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart' as rx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'file_service.dart';

class PageRef {
  PageRef(this.pageNumber, [this.rotation = rx.PdfPageRotation.none]);

  final int pageNumber;
  rx.PdfPageRotation rotation;
}

enum NumberPosition {
  bottomCenter('Rodapé centro'),
  bottomRight('Rodapé direita'),
  bottomLeft('Rodapé esquerda'),
  topCenter('Topo centro'),
  topRight('Topo direita'),
  topLeft('Topo esquerda');

  const NumberPosition(this.label);
  final String label;
}

class PdfToolException implements Exception {
  PdfToolException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Todas as operações de PDF do app.
///
/// Manipulação de páginas (juntar, dividir, organizar, desbloquear, PDF→imagem)
/// usa o PDFium via pdfrx, que preserva o conteúdo original sem perdas.
/// Inserção de conteúdo (marca d'água, números, senha, imagens) usa o Syncfusion.
class PdfTools {
  static Future<rx.PdfDocument> open(
    Uint8List bytes, {
    String sourceName = 'doc',
    rx.PdfPasswordProvider? passwordProvider,
  }) {
    return rx.PdfDocument.openData(
      bytes,
      sourceName: '$sourceName-${DateTime.now().microsecondsSinceEpoch}',
      passwordProvider: passwordProvider,
    );
  }

  static Future<int> pageCount(Uint8List bytes) async {
    final doc = await open(bytes);
    try {
      return doc.pages.length;
    } finally {
      doc.dispose();
    }
  }

  // ---------------------------------------------------------------- páginas

  static Future<Uint8List> merge(List<LoadedFile> files) async {
    final docs = <rx.PdfDocument>[];
    final out = await rx.PdfDocument.createNew(sourceName: 'merge');
    try {
      for (final f in files) {
        docs.add(await open(f.bytes, sourceName: f.name));
      }
      out.pages = [for (final d in docs) ...d.pages];
      return await out.encodePdf();
    } finally {
      out.dispose();
      for (final d in docs) {
        d.dispose();
      }
    }
  }

  /// Gera um PDF novo com as páginas indicadas, na ordem e rotação dadas.
  static Future<Uint8List> rebuild(
    Uint8List bytes,
    List<PageRef> pages, {
    rx.PdfPasswordProvider? passwordProvider,
  }) async {
    if (pages.isEmpty) {
      throw PdfToolException('O PDF precisa ter pelo menos uma página.');
    }
    final src = await open(bytes, passwordProvider: passwordProvider);
    final out = await rx.PdfDocument.createNew(sourceName: 'rebuild');
    try {
      out.pages = [
        for (final p in pages) src.pages[p.pageNumber - 1].rotatedTo(p.rotation),
      ];
      return await out.encodePdf(removeSecurity: true);
    } finally {
      out.dispose();
      src.dispose();
    }
  }

  /// Converte "1-3, 5, 8-10" em [[1,2,3],[5],[8,9,10]].
  static List<List<int>> parseRanges(String input, int pageCount) {
    final ranges = <List<int>>[];
    for (final part in input.split(RegExp(r'[,;]'))) {
      final s = part.trim();
      if (s.isEmpty) continue;
      final m = RegExp(r'^(\d+)\s*(?:-\s*(\d+))?$').firstMatch(s);
      if (m == null) throw PdfToolException('Intervalo inválido: "$s"');
      final a = int.parse(m.group(1)!);
      final b = m.group(2) == null ? a : int.parse(m.group(2)!);
      if (a < 1 || b < 1 || a > pageCount || b > pageCount) {
        throw PdfToolException('"$s" fora do documento (1–$pageCount).');
      }
      ranges.add(a <= b
          ? [for (var i = a; i <= b; i++) i]
          : [for (var i = a; i >= b; i--) i]);
    }
    if (ranges.isEmpty) throw PdfToolException('Informe ao menos um intervalo.');
    return ranges;
  }

  static Future<List<Uint8List>> split(
    Uint8List bytes,
    List<List<int>> ranges,
  ) async {
    final src = await open(bytes);
    try {
      final results = <Uint8List>[];
      for (final r in ranges) {
        final out = await rx.PdfDocument.createNew(sourceName: 'split');
        try {
          out.pages = [for (final n in r) src.pages[n - 1]];
          results.add(await out.encodePdf(removeSecurity: true));
        } finally {
          out.dispose();
        }
      }
      return results;
    } finally {
      src.dispose();
    }
  }

  static Future<Uint8List> unlock(Uint8List bytes, String password) async {
    var asked = false;
    final doc = await open(
      bytes,
      passwordProvider: () {
        if (asked) return null;
        asked = true;
        return password;
      },
    ).catchError((Object _) => throw PdfToolException('Senha incorreta.'));
    try {
      return await doc.encodePdf(removeSecurity: true);
    } finally {
      doc.dispose();
    }
  }

  static Future<List<LoadedFile>> toImages(
    LoadedFile file, {
    double dpi = 150,
  }) async {
    final doc = await open(file.bytes, sourceName: file.name);
    try {
      final images = <LoadedFile>[];
      final scale = dpi / 72;
      for (final page in doc.pages) {
        final img = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          width: (page.width * scale).round(),
          height: (page.height * scale).round(),
          backgroundColor: 0xffffffff,
        );
        if (img == null) continue;
        final uiImage = await img.createImage();
        img.dispose();
        final data = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        uiImage.dispose();
        images.add(LoadedFile(
          '${file.baseName}_pagina_${page.pageNumber}.png',
          data!.buffer.asUint8List(),
        ));
      }
      return images;
    } finally {
      doc.dispose();
    }
  }

  static Future<String> extractText(Uint8List bytes) async {
    final doc = await open(bytes);
    try {
      final buffer = StringBuffer();
      for (final page in doc.pages) {
        final text = await page.loadText();
        buffer
          ..writeln('===== Página ${page.pageNumber} =====')
          ..writeln(text?.fullText.trim() ?? '')
          ..writeln();
      }
      return buffer.toString();
    } finally {
      doc.dispose();
    }
  }

  static Uint8List textFile(String text) =>
      Uint8List.fromList(utf8.encode(text));

  // --------------------------------------------------------------- conteúdo

  static sf.PdfDocument _loadSf(Uint8List bytes) {
    try {
      return sf.PdfDocument(inputBytes: bytes);
    } catch (_) {
      throw PdfToolException(
          'Não foi possível abrir o PDF. Se ele tiver senha, use "Desbloquear PDF" antes.');
    }
  }

  static Future<Uint8List> _saveSf(sf.PdfDocument doc) async {
    try {
      return Uint8List.fromList(await doc.save());
    } finally {
      doc.dispose();
    }
  }

  static sf.PdfColor _color(ui.Color c) => sf.PdfColor(
        (c.r * 255).round(),
        (c.g * 255).round(),
        (c.b * 255).round(),
      );

  static Future<Uint8List> watermark(
    Uint8List bytes, {
    required String text,
    double fontSize = 60,
    double opacity = 0.25,
    ui.Color color = const ui.Color(0xFFE5322D),
    bool diagonal = true,
  }) {
    final doc = _loadSf(bytes);
    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, fontSize,
        style: sf.PdfFontStyle.bold);
    final textSize = font.measureString(text);
    final brush = sf.PdfSolidBrush(_color(color));
    for (var i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final size = page.getClientSize();
      final g = page.graphics;
      final state = g.save();
      g.setTransparency(opacity);
      g.translateTransform(size.width / 2, size.height / 2);
      if (diagonal) {
        g.rotateTransform(-math.atan2(size.height, size.width) * 180 / math.pi);
      }
      g.drawString(
        text,
        font,
        brush: brush,
        bounds: ui.Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2,
            textSize.width, textSize.height),
      );
      g.restore(state);
    }
    return _saveSf(doc);
  }

  static Future<Uint8List> addPageNumbers(
    Uint8List bytes, {
    NumberPosition position = NumberPosition.bottomCenter,
    bool withTotal = false,
    int startAt = 1,
    double fontSize = 11,
  }) {
    final doc = _loadSf(bytes);
    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, fontSize);
    final total = doc.pages.count + startAt - 1;
    const margin = 24.0;
    for (var i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final size = page.getClientSize();
      final n = i + startAt;
      final label = withTotal ? 'Página $n de $total' : '$n';
      final t = font.measureString(label);
      final y = switch (position) {
        NumberPosition.topCenter ||
        NumberPosition.topLeft ||
        NumberPosition.topRight =>
          margin,
        _ => size.height - margin - t.height,
      };
      final x = switch (position) {
        NumberPosition.bottomLeft || NumberPosition.topLeft => margin,
        NumberPosition.bottomRight ||
        NumberPosition.topRight =>
          size.width - margin - t.width,
        _ => (size.width - t.width) / 2,
      };
      page.graphics.drawString(label, font,
          brush: sf.PdfBrushes.black,
          bounds: ui.Rect.fromLTWH(x, y, t.width + 1, t.height));
    }
    return _saveSf(doc);
  }

  /// Escreve [text] na página [pageNumber] (1-based) a partir de [position],
  /// em coordenadas da página (pontos, origem no canto superior esquerdo).
  static Future<Uint8List> addText(
    Uint8List bytes, {
    required int pageNumber,
    required ui.Offset position,
    required String text,
    double fontSize = 14,
    ui.Color color = const ui.Color(0xFF000000),
    bool bold = false,
  }) {
    final doc = _loadSf(bytes);
    final page = doc.pages[pageNumber - 1];
    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, fontSize,
        style: bold ? sf.PdfFontStyle.bold : sf.PdfFontStyle.regular);
    final size = font.measureString(text);
    page.graphics.drawString(text, font,
        brush: sf.PdfSolidBrush(_color(color)),
        bounds: ui.Rect.fromLTWH(
            position.dx, position.dy, size.width + 2, size.height + 2));
    return _saveSf(doc);
  }

  static Future<Uint8List> protect(Uint8List bytes, String password) {
    final doc = _loadSf(bytes);
    doc.security
      ..algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit
      ..userPassword = password
      ..ownerPassword = password;
    return _saveSf(doc);
  }

  static Future<Uint8List> imagesToPdf(
    List<LoadedFile> images, {
    bool a4 = true,
    double margin = 20,
  }) {
    final doc = sf.PdfDocument();
    for (final img in images) {
      final bitmap = sf.PdfBitmap(img.bytes);
      final landscape = bitmap.width > bitmap.height;
      final section = doc.sections!.add();
      final settings = section.pageSettings;
      if (a4) {
        settings.size = sf.PdfPageSize.a4;
        settings.orientation = landscape
            ? sf.PdfPageOrientation.landscape
            : sf.PdfPageOrientation.portrait;
        settings.margins.all = margin;
      } else {
        settings.size = ui.Size(bitmap.width.toDouble(), bitmap.height.toDouble());
        settings.margins.all = 0;
      }
      final page = section.pages.add();
      final area = page.getClientSize();
      final scale = math.min(area.width / bitmap.width, area.height / bitmap.height);
      final w = bitmap.width * scale, h = bitmap.height * scale;
      page.graphics.drawImage(
        bitmap,
        ui.Rect.fromLTWH((area.width - w) / 2, (area.height - h) / 2, w, h),
      );
    }
    return _saveSf(doc);
  }
}
