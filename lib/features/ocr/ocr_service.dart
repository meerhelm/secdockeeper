import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<String?> recognize(File file, {String? mimeType}) async {
    if (!isSupported) return null;
    if (mimeType != null && !mimeType.startsWith('image/')) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFile(file);
      final result = await recognizer.processImage(input);
      final text = result.text.trim();
      if (text.isEmpty) return null;
      return text;
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
