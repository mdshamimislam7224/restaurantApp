import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:restaurant_inventory/attendance/ui/HomeScreen.dart';
import 'package:restaurant_inventory/attendance/ui/model_class/ApiServiceAttendance.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../ForTestClass.dart';
import '../Inernet_Check/InternetCheckCallback.dart';
import '../Inernet_Check/Internet_check.dart';
import '../Location/LocationService.dart';
import '../alertDialog/customdialog.dart';
import '../attendance/Recognition.dart';
import '../attendance/Recognizer.dart';
import '../localDB/DatabaseHelper.dart';
import '../main.dart';
import '../sharedPref/SharedPrefsHelper.dart';

class RecognitionScreen extends StatefulWidget {
  const RecognitionScreen({Key? key}) : super(key: key);

  @override
  _RecognitionScreen createState() => _RecognitionScreen();
}
class _RecognitionScreen extends State<RecognitionScreen> implements InternetCheckCallback {
  dynamic controller;
  bool isBusy = false;
  bool isRecognized = false;
  bool isRecognizedTimeCheck = false;
  bool isErrorRecognizedTimeCheck = false;
  bool isErrorRecognized = false;
  final Internet_check _internetCheck = Internet_check();
  SharedPrefsHelper sharedPrefsHelper = SharedPrefsHelper();
  Completer<void>? _locationCompleter;
  String? username;
  String? _imagePath;
  String? _officialID;
  bool _isPunching = false;
  late Size size;
  bool _isDisposed = false;
  final ApiServiceAttendance _apiService = ApiServiceAttendance();
  int successCounter = 0;
  late CameraDescription description = cameras[1];
  CameraLensDirection camDirec = CameraLensDirection.front;
  late List<Recognition> recognitions = [];
  late Recognition recognition;
  int frameSkipCount = 0;
  final LocationService _locationService = LocationService();

  Timer? _locationUpdateTimer;
  Timer? _recognitionTimer;
  bool dataSendChecker = false;
  customDialog? customdialog;
  String? latitude;
  String? longitude;
  String deviceName = '';
  String deviceModel = '';
  bool isConnected = false;
  String errorMessage = '';

  // Performance optimization variables
  late FaceDetector detector;
  late Recognizer recognizer;
  DateTime _lastRecognitionTime = DateTime.now();
  final Duration _minRecognitionInterval = Duration(seconds: 1);
  final Stopwatch _performanceStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      customdialog = customDialog(context);
      customdialog!.showLoading("Checking permissions...");
    });

    Future.microtask(() async {
      final allGranted = await _checkPermissions();
      if (allGranted) {
        await _initializeApp();
      } else {
        customdialog?.dismiss();
        showToast("Please grant all permissions to use this app.",Colors.red);
      }
    });
  }

  Future<void> _initializeApp() async {
    _performanceStopwatch.start();

    // Optimized face detector configuration
    detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate, // Better accuracy
        enableLandmarks: false, // Disabled for performance
        enableContours: false,  // Disabled for performance
        enableClassification: false, // Disabled for performance
        minFaceSize: 0.15, // Increased for better quality
      ),
    );

    recognizer = Recognizer();

    // Load model asynchronously
    await recognizer.loadModel();
    // Wait a moment to ensure database is fully initialized
    await Future.delayed(Duration(milliseconds: 100));
    // Check database status
    _checkDatabaseStatus();

    final locationSuccess = await fetchLocation();
    if (locationSuccess) {
      print('Location fetched successfully');
      final cameraInitialized = await initializeCamera();
      if (cameraInitialized) {
        if (Navigator.canPop(context)) {
          customdialog?.dismiss();
        }
        _loadImageFromPrefs();
        _getDeviceInfo();
      }
    } else {
      if (mounted && Navigator.canPop(context)) {
        customdialog?.dismiss();
        showToast("Could not fetch location after multiple attempts",Colors.red);
      }
    }

    _logPerformance('App Initialization', _performanceStopwatch);
  }

  void _checkDatabaseStatus() async {
    final allRows = await recognizer.dbHelper.queryAllRows();
    print("Database has ${allRows.length} registered faces");
    for (final row in allRows) {
      print("Registered: ${row[DatabaseHelper.columnName]}");
    }
  }
  Future<bool> _checkPermissions() async {
    try {
      final List<Permission> permissions = [
        Permission.camera,
        Permission.location,
      ];

      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          permissions.addAll([
            Permission.photos,
            Permission.videos,
          ]);
        } else {
          permissions.add(Permission.storage);
        }
      } else if (Platform.isIOS) {
        permissions.add(Permission.photos);
      }

      for (var permission in permissions) {
        final status = await permission.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          final result = await permission.request();
          if (!result.isGranted) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print("Permission check error: $e");
      return false;
    }
  }

  Future<bool> initializeCamera() async {
    final stopwatch = Stopwatch()..start();

    controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      // Add this for Android to disable mirroring
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : null,
    );

    try {
      await controller.initialize();

      // Disable mirroring for front camera
      if (camDirec == CameraLensDirection.front) {
        await controller.setDescription(description);
      }

      if (!mounted) return false;

      controller.startImageStream((image) {
        if (!isBusy && mounted) {
          isBusy = true;
          Future.microtask(() => doFaceDetectionOnFrame(image));
        }
      });
      _incrementSuccessCounter();
      _logPerformance('Camera Initialization', stopwatch);
      return true;
    } catch (e) {
      print("Camera initialization error: $e");
      return false;
    }
  }

  Future<bool> fetchLocation() async {
    int retryCount = 0;
    const int maxRetries = 12;
    const Duration retryDelay = Duration(seconds: 5);

    Future<bool> tryFetchLocation() async {
      try {
        await _requestLocationPermission();
        await _startLocationService();

        if (latitude != null && longitude != null) {
          _incrementSuccessCounter();
          return true;
        }

        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay);
          return await tryFetchLocation();
        }
        return false;
      } catch (e) {
        print("Location fetching error: $e");
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay);
          return await tryFetchLocation();
        }
        return false;
      }
    }

    return await tryFetchLocation();
  }

  Future<void> _requestLocationPermission() async {
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
    _startLocationService();
  }

  Future<void> _startLocationService() async {
    await _locationService.startLocationUpdates(context, onSuccess: (locationData) {
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          latitude = locationData.latitude.toString();
          longitude = locationData.longitude.toString();
        });
        print("latitude: $latitude, Longitude: $longitude");
        _locationService.stopLocationUpdates();

        if (!dataSendChecker && customdialog != null && Navigator.canPop(context)) {
          Future.delayed(Duration(milliseconds: 5), () {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // customdialog?.dismiss();
              }
            });
          });
        }
      }
    });
  }

  void _incrementSuccessCounter() {
    successCounter++;
    if (successCounter == 2) {
      if (customdialog != null) {
        // Dismiss dialog if needed
      }
    }
  }

  Future<void> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        setState(() {
          deviceName = androidInfo.device;
          deviceModel = androidInfo.model;
          print("Android Device Name:$deviceName, Device Model:$deviceModel");
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        setState(() {
          deviceName = iosInfo.name;
          deviceModel = iosInfo.model;
          print("Device Name:$deviceName, Device Model:$deviceModel");
        });
      }
    } catch (e) {
      print('Failed to get device information: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Cancel all timers
    _recognitionTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _locationCompleter?.complete();

    // Dispose resources properly
    controller?.stopImageStream();
    controller?.dispose();
    detector.close();
    recognizer.dispose();
    _locationService.stopLocationUpdates();

    // Clear large data
    recognitions.clear();
    _scanResults = null;

    _performanceStopwatch.stop();

    super.dispose();
  }

  dynamic _scanResults;

  Future<void> doFaceDetectionOnFrame(CameraImage image) async {
    final stopwatch = Stopwatch()..start();

    // Reduce frame skipping for smoother canvas updates
    frameSkipCount++;
    if (frameSkipCount % 2 != 0) { // Process every 2nd frame instead of 6th
      isBusy = false;
      return;
    }

    try {
      final InputImage inputImage = getInputImage(image);
      final List<Face> faces = await detector.processImage(inputImage);

      // Update canvas immediately with detected faces
      if (faces.isNotEmpty) {
        // Update recognition results immediately for smooth canvas rendering
        if (mounted) {
          setState(() {
            // Keep existing recognition data but update face positions
            if (recognitions.isNotEmpty && faces.length == 1) {
              recognitions[0].location = faces.first.boundingBox;
            } else if (recognitions.isEmpty) {
              // Create temporary recognition for smooth canvas
              // Recognition(name, location, embedding, distance)
              recognitions = [
                Recognition(
                  "Detecting...",
                  faces.first.boundingBox,
                  [],
                  1.0,
                )
              ];
            }
            _scanResults = recognitions;
          });
        }

        // Only perform full recognition on good quality faces
        if (faces.length == 1 && _isGoodQualityFace(faces.first)) {
          await performFaceRecognitionOptimized(faces, image);
        }
      } else {
        // Clear previous results if no face detected
        if (recognitions.isNotEmpty) {
          recognitions.clear();
          if (mounted) {
            setState(() {
              _scanResults = recognitions;
            });
          }
        }
      }
    } catch (e) {
      print("Face detection error: $e");
    } finally {
      isBusy = false;
    }

    _logPerformance('Face Detection', stopwatch);
  }

// Optimized recognition that doesn't block canvas updates
  Future<void> performFaceRecognitionOptimized(List<Face> faces, CameraImage image) async {
    // Throttle full recognition, but not canvas updates
    final now = DateTime.now();
    if (now.difference(_lastRecognitionTime) < Duration(milliseconds: 500)) {
      // Still update face position even if skipping recognition
      return;
    }
    _lastRecognitionTime = now;

    // Early return if already processing recognition
    if (isRecognizedTimeCheck || isErrorRecognizedTimeCheck) {
      return;
    }

    try {
      final croppedFace = await _getOptimizedCroppedFace(faces.first, image);
      if (croppedFace == null) {
        return;
      }

      recognition = recognizer.recognize(croppedFace, faces.first.boundingBox);

      print("Recognition - Name: ${recognition.name}, Distance: ${recognition.distance}");

      // Update UI with recognition results
      if (mounted) {
        setState(() {
          recognitions = [recognition];
          _scanResults = recognitions;
        });
      }

      // Handle recognition
      await _handleRecognitionWithThreshold(recognition);

    } catch (e) {
      print("Recognition error: $e");
    }
  }

  // Check if face is good quality for recognition
  bool _isGoodQualityFace(Face face) {
    final rect = face.boundingBox;

    // Check face size (should be reasonably large)
    if (rect.width < 100 || rect.height < 100) {
      return false;
    }

    return true;
  }

  Future<img.Image?> _getOptimizedCroppedFace(Face face, CameraImage image) async {
    try {
      final convertedImage = convertYUV420ToImage(image);

      // Only rotate if necessary
      final processedImage = camDirec == CameraLensDirection.front
          ? img.copyRotate(convertedImage, angle: 270)
          : convertedImage;

      final faceRect = face.boundingBox;

      // Add padding to the face crop for better recognition
      final padding = 20;
      final x = (faceRect.left - padding).clamp(0, processedImage.width - 1).toInt();
      final y = (faceRect.top - padding).clamp(0, processedImage.height - 1).toInt();
      final width = (faceRect.width + padding * 2).clamp(1, processedImage.width - x).toInt();
      final height = (faceRect.height + padding * 2).clamp(1, processedImage.height - y).toInt();

      return img.copyCrop(processedImage, x: x, y: y, width: width, height: height);
    } catch (e) {
      print("Face cropping error: $e");
      return null;
    }
  }

  Future<void> _handleRecognitionWithThreshold(Recognition recognition) async {
    // Use a more lenient threshold for better accuracy
    final recognitionThreshold = 1.0; // Adjust this based on your model

    if (recognition.distance > recognitionThreshold) {
      // Face not recognized
      if (!isErrorRecognizedTimeCheck) {
        setState(() {
          username = "Unknown";
          _officialID = "Unknown";
          errorMessage = 'Face not recognized';
          isErrorRecognized = true;
          isErrorRecognizedTimeCheck = true;
        });

        _recognitionTimer = Timer(Duration(seconds: 2), () {
          if (!_isDisposed && mounted) {
            setState(() {
              isErrorRecognized = false;
              isErrorRecognizedTimeCheck = false;
            });
          }
        });
      }
      return;
    } else {
      // Face recognized - get user info
      username = recognition.name;
      _officialID = await sharedPrefsHelper.getOfficialID();

      // Show success message immediately
      setState(() {
        isRecognized = true;
      });

      // Call sendData to check permissions via API
      await _punchAttendance("IN");
    }
  }

  // Performance logging
  void _logPerformance(String operation, Stopwatch stopwatch) {
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed > 100) {
      print('PERFORMANCE: $operation took ${elapsed}ms');
    }
    stopwatch.reset();
  }

  img.Image convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yRowStride = cameraImage.planes[0].bytesPerRow;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;
    final image = img.Image(width: width, height: height);

    for (var w = 0; w < width; w++) {
      for (var h = 0; h < height; h++) {
        final uvIndex = uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final index = h * width + w;
        final yIndex = h * yRowStride + w;

        final y = cameraImage.planes[0].bytes[yIndex];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        image.data!.setPixelR(w, h, yuv2rgb(y, u, v));
      }
    }
    return image;
  }

  int yuv2rgb(int y, int u, int v) {
    var r = (y + v * 1436 / 1024 - 179).round();
    var g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    var b = (y + u * 1814 / 1024 - 227).round();

    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);

    return 0xff000000 | ((b << 16) & 0xff0000) | ((g << 8) & 0xff00) | (r & 0xff);
  }

  InputImage getInputImage(CameraImage cameraImage) {
    try {
      final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw) ??
          (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);

      final actualFormat = Platform.isAndroid && format == InputImageFormat.yuv_420_888
          ? InputImageFormat.nv21
          : format;

      final metadata = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: _getRotation(),
        format: actualFormat,
        bytesPerRow: cameraImage.planes.first.bytesPerRow,
      );

      if (Platform.isAndroid) {
        return InputImage.fromBytes(
          bytes: concatenatePlanes(cameraImage.planes, cameraImage.width, cameraImage.height),
          metadata: metadata,
        );
      } else {
        return InputImage.fromBytes(
          bytes: concatenatePlanes(cameraImage.planes, cameraImage.width, cameraImage.height),
          metadata: metadata,
        );
      }
    } catch (e) {
      print('Error creating InputImage: $e');
      return InputImage.fromBytes(
        bytes: concatenatePlanes(cameraImage.planes, cameraImage.width, cameraImage.height),
        metadata: InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: _getRotation(),
          format: InputImageFormat.nv21,
          bytesPerRow: cameraImage.planes.first.bytesPerRow,
        ),
      );
    }
  }

  Uint8List concatenatePlanes(List<Plane> planes, int width, int height) {
    final Uint8List yBytes = planes[0].bytes;
    final int yRowStride = planes[0].bytesPerRow;

    final Uint8List uBytes = planes[1].bytes;
    final Uint8List vBytes = planes[2].bytes;
    final int uRowStride = planes[1].bytesPerRow;
    final int vRowStride = planes[2].bytesPerRow;

    final int ySize = width * height;
    final int uvWidth = (width + 1) ~/ 2;
    final int uvHeight = (height + 1) ~/ 2;
    final int uvSize = uvWidth * uvHeight * 2;

    final Uint8List nv21Bytes = Uint8List(ySize + uvSize);

    int yOffset = 0;
    int nv21YIndex = 0;
    for (int y = 0; y < height; y++) {
      nv21Bytes.setRange(nv21YIndex, nv21YIndex + width, yBytes.sublist(yOffset, yOffset + width));
      yOffset += yRowStride;
      nv21YIndex += width;
    }

    int uvIndex = ySize;
    int uPlaneOffset = 0;
    int vPlaneOffset = 0;

    for (int y = 0; y < uvHeight; y++) {
      for (int x = 0; x < uvWidth; x++) {
        nv21Bytes[uvIndex++] = vBytes[min(vPlaneOffset + x, vBytes.length - 1)];
        nv21Bytes[uvIndex++] = uBytes[min(uPlaneOffset + x, uBytes.length - 1)];
      }
      uPlaneOffset += uRowStride;
      vPlaneOffset += vRowStride;
    }

    return nv21Bytes;
  }

  InputImageRotation _getRotation() {
    switch (description.sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Widget buildResult() {
    if (_scanResults == null || controller == null || !controller.value.isInitialized) {
      return const Center(child: Text('Camera is not initialized'));
    }
    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = FaceDetectorPainter(imageSize, _scanResults, camDirec);
    return CustomPaint(
      painter: painter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: LayoutBuilder(
            builder: (context, constraints) {
              List<Widget> stackChildren = [];
              size = MediaQuery.of(context).size;

              if (controller != null) {
                stackChildren.add(
                  Positioned(
                    top: 0.0,
                    left: 0.0,
                    width: size.width,
                    height: size.height,
                    child: Container(
                      child: (controller.value.isInitialized)
                          ? ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: size.width,
                              child: Transform(
                                alignment: Alignment.center,
                                // Mirror for front camera
                                transform: Matrix4.identity()
                                  ..scale(
                                    camDirec == CameraLensDirection.front ? -1.0 : 1.0,
                                    1.0,
                                  ),
                                child: CameraPreview(controller),
                              ),
                            ),
                          ),
                        ),
                      )
                          : Container(),
                    ),
                  ),
                );

                stackChildren.add(
                  Positioned(
                    top: 0.0,
                    left: 0.0,
                    width: size.width,
                    height: size.height,
                    child: buildResult(),
                  ),
                );

                if (isRecognized) {
                  stackChildren.add(buildSuccessMessage());
                } else if (isErrorRecognized) {
                  stackChildren.add(buildErrorMessage());
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Stack(
                          children: stackChildren,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildSuccessMessage() {
    bool isLoading = _isPunching;

    return Positioned(
      bottom: 0.0,
      left: 0.0,
      width: size.width,
      child: Container(
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isLoading ? Colors.blueGrey : Colors.blue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Image
                Container(
                  width: 50,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    image: _imagePath != null
                        ? DecorationImage(
                      image: FileImage(File(_imagePath!)),
                      fit: BoxFit.cover,
                    )
                        : null,
                    color: _imagePath == null ? Colors.grey[300] : null,
                  ),
                  child: _imagePath == null
                      ? Icon(Icons.person, size: 30, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Text
                      Text(
                        isLoading
                            ? 'Sending data...'
                            : 'Face recognized!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // User Info
                      Text(
                        'Name: $username',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                        ),
                      ),
                      Text(
                        'ID: $_officialID',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                        ),
                      ),

                      // Loading indicator for punching
                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Sending attendance...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Icon
                if (!isLoading)
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 24.0,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Future<bool> _onWillPop() async {
    // Prevent going back during recognition/punching
    if (_isPunching) {
      showToast("Please wait, processing attendance...", Colors.orange);
      return false;
    }
    return true;
  }

  Widget buildErrorMessage() {
    bool isUnknownFace = username == "Unknown";
    bool isPermissionDenied = errorMessage.contains('Permission Denied') ||
        errorMessage.contains('remote attendance not allowed');

    String title = isUnknownFace ? 'Face Not Recognized'
        : isPermissionDenied ? 'Permission Denied'
        : 'Error';

    String subtitle = errorMessage;

    return Positioned(
      bottom: 0.0,
      left: 0.0,
      width: size.width,
      child: Container(
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isUnknownFace ? Colors.red.shade700 :
          isPermissionDenied ? Colors.orange.shade700 :
          Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                image: (!isUnknownFace && _imagePath != null && !isPermissionDenied)
                    ? DecorationImage(
                  image: FileImage(File(_imagePath!)),
                  fit: BoxFit.cover,
                )
                    : null,
                color: (isUnknownFace || _imagePath == null || isPermissionDenied)
                    ? Colors.grey[300] : null,
              ),
              child: (isUnknownFace || _imagePath == null || isPermissionDenied)
                  ? Icon(
                isUnknownFace ? Icons.person_off
                    : isPermissionDenied ? Icons.block
                    : Icons.error_outline,
                size: 40,
                color: Colors.yellow.shade200,
              )
                  : null,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color:Colors.white,
                      fontSize: 14.0,
                    ),
                  ),
                  // Show name and ID only for permission denied cases, not for unknown faces
                  if (!isUnknownFace && username != "Unknown" && username != null) ...[
                    SizedBox(height: 4),
                    Text(
                      'Name: $username',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                    Text(
                      'ID: $_officialID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isUnknownFace ? Icons.person_off
                  : isPermissionDenied ? Icons.block
                  : Icons.error_outline,
              color: Colors.yellow.shade200,
              size: 24.0,
            ),
          ],
        ),
      ),
    );
  }

  void onRecognized() {
    if (!isRecognizedTimeCheck && !_isDisposed) {
      setState(() {
        isRecognized = true;
        isRecognizedTimeCheck = true;
      });
      _recognitionTimer = Timer(Duration(seconds: 1), () {
        if (!_isDisposed && mounted) {
          setState(() {
            isRecognized = false;
            isRecognizedTimeCheck = false;
          });
        }
      });
    }
  }

  void onNotRecognized() {
    if (!isErrorRecognizedTimeCheck && !_isDisposed) {
      setState(() {
        isErrorRecognized = true;
        isErrorRecognizedTimeCheck = true;
      });
      _recognitionTimer = Timer(Duration(seconds: 1), () {
        if (!_isDisposed && mounted) {
          setState(() {
            isErrorRecognized = false;
            isErrorRecognizedTimeCheck = false;
          });
        }
      });
    }
  }

  Future<void> _loadImageFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    String? imagePath = prefs.getString('savedImagePath');
    String? id = await sharedPrefsHelper.getOfficialID();
    print("Image: $imagePath ID: $id");
    setState(() {
      _imagePath = imagePath;
      _officialID = id;
    });
  }

  Future<void> _punchAttendance(String action) async {
    // Early validation
    if (_officialID == null || _officialID!.isEmpty) {
      showToast("User ID not found", Colors.red);
      return;
    }

    if (latitude == null || longitude == null) {
      showToast("Location not available", Colors.red);
      return;
    }

    setState(() {
      _isPunching = true;
    });

    try {
      // Parse coordinates
      final lat = double.tryParse(latitude!);
      final lng = double.tryParse(longitude!);

      if (lat == null || lng == null) {
        throw Exception("Invalid location coordinates");
      }

      // Call API
      final result = await _apiService.punchAttendance(
        staffId: _officialID!,
        action: action,
        latitude: lat,
        longitude: lng,
        notes: 'Face Recognition Punch from mobile app',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully ${action.toLowerCase()}ed!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Navigate to HomeScreen after delay to show success message
      await Future.delayed(Duration(seconds: 1));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              staffId: _officialID!,
              staffName: username ?? "User",
            ),
          ),
        );
      }

    } catch (e) {
      print("Punch attendance error: $e");

      if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to punch: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        // Reset recognition state to try again
        setState(() {
          isRecognized = false;
          isErrorRecognized = true;
          errorMessage = 'API Error: ${e.toString()}';
        });

        // Auto-reset after 3 seconds
        Timer(Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              isErrorRecognized = false;
              errorMessage = '';
            });
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPunching = false;
        });
      }
    }
  }

  void showToast(String message,Color bgColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 2,
      backgroundColor: bgColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  void onInternetCheck(bool success, String message) {
    if (success) {
      if (message == "Poor connection" || message == "Fair connection") {
        print("Internet= $success, Messages $message");
        if (customdialog != null) {
          customdialog!.dismiss();
          showToast("Poor connection ",Colors.red);
        }
        isConnected = false;
      } else {
        isConnected = true;
      }
    } else {
      isConnected = false;
    }
    setState(() {});
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.absoluteImageSize, this.faces, this.camDire2);

  final Size absoluteImageSize;
  final List<Recognition> faces;
  final CameraLensDirection camDire2;

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;
    final Paint boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    for (Recognition face in faces) {
      double left = camDire2 == CameraLensDirection.front
          ? (absoluteImageSize.width - face.location.right) * scaleX
          : face.location.left * scaleX;
      double top = face.location.top * scaleY;
      double right = camDire2 == CameraLensDirection.front
          ? (absoluteImageSize.width - face.location.left) * scaleX
          : face.location.right * scaleX;
      double bottom = face.location.bottom * scaleY;

      Rect faceRect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(faceRect, boxPaint);

      TextSpan span = TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 20),
          text: "${face.name}");


      TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr);
      tp.layout();
      double labelX = left + (right - left) / 2 - tp.width / 2;
      tp.paint(canvas, Offset(labelX, top - 25));
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return true;
  }
}