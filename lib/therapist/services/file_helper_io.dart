import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> saveFile(Uint8List bytes, String filename) async {
  try {
    final directory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    print('PDF saved to: ${file.path}');
    return file.path;
  } catch (e) {
    print('Error saving file: $e');
    rethrow;
  }
}
