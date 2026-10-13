import 'package:flutter_test/flutter_test.dart';
import 'package:pdfreader/services/pdf_tools.dart';

void main() {
  test('parseRanges interpreta intervalos', () {
    expect(PdfTools.parseRanges('1-3, 5', 10), [
      [1, 2, 3],
      [5],
    ]);
    expect(() => PdfTools.parseRanges('0-20', 10), throwsA(isA<PdfToolException>()));
    expect(() => PdfTools.parseRanges('abc', 10), throwsA(isA<PdfToolException>()));
  });
}
