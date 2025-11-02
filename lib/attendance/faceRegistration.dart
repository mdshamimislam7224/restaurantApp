import 'dart:io';
import 'dart:ui';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../localDB/DBHelper.dart';
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

  Future<bool> loadImagePath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      imagePath = prefs.getString('savedImagePath') ?? '';
      f_Name = prefs.getString('firstName') ?? '';
      l_Name = prefs.getString('lastName') ?? '';

      if (imagePath.isEmpty) {
        print('No saved image path found');
        return false;
      }

      return await _processImage();
    } catch (e) {
      print('Error in loadImagePath: $e');
      return false;
    }
  }

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

  bool _isOverlapping(Rect rect1, Rect rect2) {
    return rect1.overlaps(rect2);
  }

  bool _isAdjacent(Rect rect1, Rect rect2) {
    return rect1.right >= rect2.left &&
        rect1.left <= rect2.right &&
        rect1.bottom >= rect2.top &&
        rect1.top <= rect2.bottom;
  }

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

  bool _hasRequiredLandmarks(Face face) {
    // Implement your landmark validation logic
    return true; // Placeholder
  }

  Future<void> dispose() async {
    await detector.close();
  }
}