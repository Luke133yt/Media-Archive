import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

Future<void> installWindowsUpdate(
  Uri url,
  String fileName,
  ValueChanged<double?> onProgress,
) async {
  if (!Platform.isWindows) {
    throw UnsupportedError(
        'Installazione automatica supportata solo su Windows.');
  }
  final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  if (!safeName.toLowerCase().endsWith('.exe')) {
    throw const FormatException(
        'Il file della release non è un installer Windows.');
  }

  final client = http.Client();
  try {
    final response = await client
        .send(http.Request('GET', url))
        .timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw HttpException('Download HTTP ${response.statusCode}.');
    }
    final file =
        File('${Directory.systemTemp.path}${Platform.pathSeparator}$safeName');
    final sink = file.openWrite();
    var received = 0;
    final total = response.contentLength ?? -1;
    try {
      await for (final chunk
          in response.stream.timeout(const Duration(minutes: 5))) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : null);
      }
      await sink.close();
    } catch (_) {
      await sink.close();
      rethrow;
    }
    if (received == 0) {
      throw const FormatException('Il pacchetto scaricato è vuoto.');
    }

    await Process.start(
      file.path,
      const [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/SP-',
        '/CLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  } finally {
    client.close();
  }
}
