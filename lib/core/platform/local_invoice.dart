import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;

import 'package:bakaloo_flutter_app/core/platform/web_download.dart';

/// Invoice "save to device" boundary.
///
/// WEB PORT: on mobile the invoice bytes are written to the app's temporary
/// directory and then handed to the system viewer (open_file). A browser
/// cannot write into the device filesystem — instead the bytes are handed
/// to the browser's own download flow (blob + anchor click), after which
/// "open" is a no-op because the browser has already stored the file.
Future<String> saveInvoiceBytes({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (kIsWeb) {
    await WebDownload.saveBytes(bytes: bytes, fileName: fileName);
    return fileName;
  }
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Opens a previously saved invoice file. See [saveInvoiceBytes] — on web
/// the file is already stored by the browser, so this reports success.
Future<OpenResult> openSavedInvoice(String path) async {
  if (kIsWeb) {
    return OpenResult(type: ResultType.done, message: 'done');
  }
  return OpenFile.open(path);
}
