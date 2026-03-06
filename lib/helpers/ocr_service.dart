import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'text_parser.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class OcrService {
  static Future<Map<String, dynamic>> scanImage(String imagePath) async {
    var status = await Permission.photos.status;

    if (!status.isGranted) {
      if (Platform.isAndroid) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.storage,
        ].request();

        if (!statuses[Permission.photos]!.isGranted &&
            !statuses[Permission.storage]!.isGranted) {
          return {};
        }
      }
    }

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final InputImage inputImage = InputImage.fromFilePath(imagePath);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      String fullText = recognizedText.text;

      return TextParser.parse(fullText);
    } catch (e) {
      return {};
    } finally {
      textRecognizer.close();
    }
  }
}
