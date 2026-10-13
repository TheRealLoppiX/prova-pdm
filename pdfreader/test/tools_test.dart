import "dart:ui";
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' as rx;
import 'package:pdfreader/services/file_service.dart';
import 'package:pdfreader/services/pdf_tools.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

Future<Uint8List> makePdf(int pages, String tag) async {
  final d = sf.PdfDocument();
  for (var i = 0; i < pages; i++) {
    d.pages.add().graphics.drawString('$tag page ${i + 1}',
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 20));
  }
  final b = Uint8List.fromList(await d.save());
  d.dispose();
  return b;
}

void main() {
  setUpAll(() async => await rx.pdfrxInitialize());

  test('operações', () async {
    final a = await makePdf(3, 'A'), b = await makePdf(2, 'B');
    final merged = await PdfTools.merge([LoadedFile('a.pdf', a), LoadedFile('b.pdf', b)]);
    expect(await PdfTools.pageCount(merged), 5);
    final parts = await PdfTools.split(merged, PdfTools.parseRanges('1-2, 5', 5));
    expect([for (final p in parts) await PdfTools.pageCount(p)], [2, 1]);
    final re = await PdfTools.rebuild(merged, [PageRef(5, rx.PdfPageRotation.clockwise90), PageRef(1)]);
    final txt = await PdfTools.extractText(re);
    expect(txt.indexOf('B page 2') < txt.indexOf('A page 1'), true);
    final wm = await PdfTools.watermark(a, text: 'SECRETO');
    expect(await PdfTools.extractText(wm), contains('SECRETO'));
    final num = await PdfTools.addPageNumbers(a, withTotal: true);
    expect(await PdfTools.extractText(num), contains('Página 3 de 3'));
    final t = await PdfTools.addText(a, pageNumber: 2, position: const Offset(50, 300), text: 'Olá');
    expect(await PdfTools.extractText(t), contains('Olá'));
    final prot = await PdfTools.protect(a, '1234');
    expect(() => PdfTools.unlock(prot, 'errada'), throwsA(isA<PdfToolException>()));
    final un = await PdfTools.unlock(prot, '1234');
    expect(await PdfTools.pageCount(un), 3);
    print('OK');
  });
}
