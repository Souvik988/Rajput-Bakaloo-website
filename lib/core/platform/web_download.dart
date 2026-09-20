import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// WEB PORT: browser file-handoff helpers (package:web JS interop).
///
/// Only reachable from code paths already guarded by kIsWeb — the same
/// operations are meaningless outside a browser.
class WebDownload {
  WebDownload._();

  /// Triggers the browser's "save file" flow for [bytes] as [fileName]
  /// (blob object URL + temporary anchor click). Used for order invoices,
  /// where the mobile flow writes the bytes to the app's temp directory
  /// and opens them with the system viewer instead.
  static Future<void> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/pdf',
  }) async {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}
