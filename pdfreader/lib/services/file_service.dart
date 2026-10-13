import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class LoadedFile {
  LoadedFile(this.name, this.bytes);

  final String name;
  final Uint8List bytes;

  String get baseName {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String get mimeType {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  bool get isPdf => mimeType == 'application/pdf';
}

class FileService {
  static Future<LoadedFile?> pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return null;
    return LoadedFile(file.name, await file.readAsBytes());
  }

  static Future<List<LoadedFile>> pickPdfs() =>
      _pickMany(const ['pdf']);

  static Future<List<LoadedFile>> pickImages() =>
      _pickMany(const ['jpg', 'jpeg', 'png']);

  static Future<List<LoadedFile>> _pickMany(List<String> extensions) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    return [
      for (final f in files) LoadedFile(f.name, await f.readAsBytes()),
    ];
  }

  static Future<bool> save(LoadedFile file) async {
    final uri = await FilePicker.saveFile(
      fileName: file.name,
      bytes: file.bytes,
      mimeType: file.mimeType,
    );
    return kIsWeb || uri != null;
  }

  static LoadedFile zip(String name, List<LoadedFile> files) {
    final archive = Archive();
    for (final f in files) {
      archive.addFile(ArchiveFile(f.name, f.bytes.length, f.bytes));
    }
    return LoadedFile(name, ZipEncoder().encodeBytes(archive));
  }
}
