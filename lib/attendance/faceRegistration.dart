import 'dart:io';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../localDB/DatabaseHelper.dart';
import 'Recognition.dart';
import 'Recognizer.dart';

class faceRegistration {
  img.Image? image;
  String imagePath = '';
  String f_Name = '';
  String l_Name = '';
  late FaceDetector detector;
  final Recognizer recognizer;
  final DatabaseHelper dbHelper;
  List<Face> faces = [];

  faceRegistration({
    required this.recognizer,
    required this.dbHelper,
    required this.detector,
  });

  // NEW METHOD: Load image from Google Drive URL instead of local path
  Future<bool> loadImageFromUrl(String imageUrl, String staffId, String staffName) async {
    try {
      // Set staff information
      f_Name = staffName;
      l_Name = ''; // You can modify this if you have last name

      if (imageUrl.isEmpty) {
        print('No image URL provided');
        return false;
      }

      // Download image from Google Drive
      return await _downloadAndProcessImage(imageUrl);
    } catch (e) {
      print('Error in loadImageFromUrl: $e');
      return false;
    }
  }

  // NEW METHOD: Download image from Google Drive
  Future<bool> _downloadAndProcessImage(String imageUrl) async {
    try {
      // Convert Google Drive URL to direct download URL
      final directUrl = _getDirectImageUrl(imageUrl);
      print('Downloading image from: $directUrl');

      // Download image bytes
      final response = await http.get(Uri.parse(directUrl));
      if (response.statusCode != 200) {
        print('Failed to download image: ${response.statusCode}');
        return false;
      }

      final bytes = response.bodyBytes;

      // Create temporary file to simulate the original file-based approach
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_face_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Write bytes to temporary file (to keep the original _processImage logic unchanged)
      await tempFile.writeAsBytes(bytes);
      imagePath = tempFile.path;

      print('Image downloaded successfully to: $imagePath');

      // Use the original _processImage method
      return await _processImage();
    } catch (e) {
      print('Error in _downloadAndProcessImage: $e');
      return false;
    }
  }


  // ORIGINAL METHOD - KEEP EXACTLY THE SAME
  Future<bool> _processImage() async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('Image file not found at path: $imagePath');
        return false;
      }

      // Read and decode image
      final bytes = await file.readAsBytes();
      image = img.decodeImage(bytes);
      if (image == null) {
        print('Failed to decode image');
        return false;
      }

      // Detect faces
      final inputImage = InputImage.fromFile(file);
      final detectedFaces = await detector.processImage(inputImage);
      if (detectedFaces.isEmpty) {
        print('No faces detected in image');
        return false;
      }

      // Process faces
      final mergedFaces = _mergeBoundingBoxes(detectedFaces);
      final validFaces = _filterValidFaces(mergedFaces);
      if (validFaces.isEmpty) {
        print('No valid faces after filtering');
        return false;
      }

      return await _performFaceRegistration(validFaces);
    } catch (e) {
      print('Error in _processImage: $e');
      return false;
    } finally {
      await detector.close();
    }
  }


  // ORIGINAL METHOD - KEEP EXACTLY THE SAME
  Future<bool> _performFaceRegistration(List<Face> faces) async {
    try {
      bool allSuccess = true;

      for (final face in faces) {
        try {
          // Crop face region
          final rect = face.boundingBox;
          final croppedFace = img.copyCrop(
            image!,
            x: rect.left.toInt(),
            y: rect.top.toInt(),
            width: rect.width.toInt(),
            height: rect.height.toInt(),
          );

          // Recognize face
          final recognition = recognizer.recognize(croppedFace, rect);

          // Prepare database record
          final row = {
            DatabaseHelper.columnName: '$f_Name $l_Name',
            DatabaseHelper.columnEmbedding:
            recognition.embedding.map((e) => e.toString()).join(','),
          };

          // Insert into database
          final insertedId = await dbHelper.insert(row);
          if (insertedId <= 0) {
            print('Failed to insert face record');
            allSuccess = false;
          }
        } catch (e) {
          print('Error processing face: $e');
          allSuccess = false;
        }
      }

      return allSuccess;
    } catch (e) {
      print('Error in _performFaceRegistration: $e');
      return false;
    }
  }

  // ORIGINAL METHOD - KEEP EXACTLY THE SAME
  List<Face> _mergeBoundingBoxes(List<Face> faces) {
    final mergedFaces = <Face>[];
    final rects = faces.map((face) => face.boundingBox).toList();

    while (rects.isNotEmpty) {
      var baseRect = rects.removeAt(0);

      for (var i = rects.length - 1; i >= 0; i--) {
        final rect = rects[i];
        if (_isOverlapping(baseRect, rect) || _isAdjacent(baseRect, rect)) {
          baseRect = baseRect.expandToInclude(rect);
          rects.removeAt(i);
        }
      }

      mergedFaces.add(Face(
        boundingBox: baseRect,
        landmarks: faces.first.landmarks,
        contours: faces.first.contours,
        // Copy other necessary face properties
      ));
    }

    return mergedFaces;
  }


  // ORIGINAL METHOD - KEEP EXACTLY THE SAME
  bool _isOverlapping(Rect rect1, Rect rect2) {
    return rect1.overlaps(rect2);
  }

  // ORIGINAL METHOD - KEEP EXACTLY THE SAME
  bool _isAdjacent(Rect rect1, Rect rect2) {
    return rect1.right >= rect2.left &&
        rect1.left <= rect2.right &&
        rect1.bottom >= rect2.top &&
        rect1.top <= rect2.bottom;
  }

  // ORIGINAL METHOD - KEEP EXACTLY THE SAME
  List<Face> _filterValidFaces(List<Face> faces) {
    return faces.where((face) {
      final rect = face.boundingBox;
      // Minimum face size constraints
      return rect.width > 50 &&
          rect.height > 50 &&
          // Add other validation criteria as needed
          _hasRequiredLandmarks(face);
    }).toList();
  }

  // ORIGINAL METHOD - KEEP EXACTLY THE SAME
  bool _hasRequiredLandmarks(Face face) {
    // Implement your landmark validation logic
    return true; // Placeholder
  }

  // NEW METHOD: Convert Google Drive URL to direct download URL
  String _getDirectImageUrl(String driveUrl) {
    final regExp = RegExp(r'file/d/([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(driveUrl);
    if (match != null && match.groupCount >= 1) {
      return 'https://drive.google.com/uc?export=download&id=${match.group(1)}';
    }
    return driveUrl;
  }

  // ORIGINAL METHOD - KEEP EXACTLY THE SAME
  Future<void> dispose() async {
    await detector.close();
  }
}
