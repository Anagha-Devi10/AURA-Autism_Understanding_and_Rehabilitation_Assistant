import 'dart:typed_data';
import 'dart:html' as html;

Future<String> saveFile(Uint8List bytes, String filename) async {
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    print('PDF downloaded: $filename');
    return url;
  } catch (e) {
    print('Error downloading file: $e');
    rethrow;
  }
}
