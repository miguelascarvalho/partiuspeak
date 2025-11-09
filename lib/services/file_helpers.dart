import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileHelpers {
  static Future<Directory> getAppDocumentsDir() async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<File> writeToFile(String fileName, String content) async {
    final dir = await getAppDocumentsDir();
    final file = File('${dir.path}/$fileName');
    return file.writeAsString(content);
  }

  static Future<String?> readFromFile(String fileName) async {
    try {
      final dir = await getAppDocumentsDir();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }
}
