import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Same "Tải xuống"/MediaStore save pattern as
/// `core/export/excel_export_service.dart`, reused here for the backup
/// JSON file instead of an Excel workbook — see that file's doc comment
/// for why a native call is needed at all instead of just `path_provider`.
const _downloadsChannel = MethodChannel('com.huluca.sochitieu/downloads');

/// Encodes [payload] as pretty JSON, saves it into the public "Tải xuống"
/// folder (falling back to the app's own external directory if that native
/// call fails), and opens the share sheet so it can also be sent straight
/// to Drive/Zalo/email. Returns where it landed, for a confirmation message.
Future<String> saveBackupFile(Map<String, dynamic> payload, String filename) async {
  final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));

  String savedLocation;
  if (Platform.isAndroid) {
    try {
      final result = await _downloadsChannel.invokeMethod<String>('saveToDownloads', {
        'fileName': filename,
        'mimeType': 'application/json',
        'bytes': bytes,
      });
      savedLocation = result ?? 'Tải xuống/$filename';
    } catch (_) {
      savedLocation = await _saveToAppDirectory(bytes, filename);
    }
  } else {
    savedLocation = await _saveToAppDirectory(bytes, filename);
  }

  final tempDir = await getTemporaryDirectory();
  final shareFile = File('${tempDir.path}/$filename');
  await shareFile.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(shareFile.path)], text: 'Sổ Thu Chi — sao lưu $filename');

  return savedLocation;
}

Future<String> _saveToAppDirectory(List<int> bytes, String filename) async {
  Directory dir;
  try {
    dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
  } catch (_) {
    dir = await getTemporaryDirectory();
  }
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
