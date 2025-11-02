import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../Inernet_Check/InternetCheckCallback.dart';
import '../Inernet_Check/Internet_check.dart';
import '../Navigation/Navigation_Class.dart';
import '../alertDialog/customdialog.dart';
import '../location/LocationService.dart';
import '../main.dart';
import '../sharedPref/SharedPrefsHelper.dart';
import 'Recognition.dart';
import 'Recognizer.dart';

class RecognitionScreen extends StatefulWidget {
  RecognitionScreen({Key? key}) : super(key: key);

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
  late Size size;
  bool _isDisposed = false;
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
  bool isCheckingPermission = false; // New variable for loading state
  customDialog? customdialog;
  String? latitude;
  String? longitude;
  String deviceName = '';
  String deviceModel = '';
  bool isConnected = false;
  String errorMessage = ''; // To store specific error message

  late FaceDetector detector;
  late Recognizer recognizer;

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
        showToast("Please grant all permissions to use this app.");
      }
    });
  }

  Future<void> _initializeApp() async {
    detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        minFaceSize: 0.08,
      ),
    );
    recognizer = Recognizer();

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
        showToast("Could not fetch location after multiple attempts");
      }
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
    controller = CameraController(description, ResolutionPreset.high);
    try {
      await controller.initialize();
      if (!mounted) return false;

      controller.startImageStream((image) {
        if (!isBusy) {
          isBusy = true;
          frameSkipCount++;
          if (frameSkipCount % 5 == 0) {
            frameSkipCount = 0;
            print('Image processed');
            doFaceDetectionOnFrame(image);
          } else {
            isBusy = false;
          }
        }
      });

      _incrementSuccessCounter();
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
        // if (Navigator.canPop(context)) {
        //     WidgetsBinding.instance.addPostFrameCallback((_) {
        //       customdialog?.dismiss();
        //     });
        //   }
      }
    } else {}
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
    _recognitionTimer?.cancel();
    _locationUpdateTimer?.cancel();
    controller?.dispose();
    _locationService.stopLocationUpdates();
    super.dispose();
  }

  dynamic _scanResults;
  CameraImage? frame;

  Future<void> doFaceDetectionOnFrame(CameraImage image) async {
    final InputImage inputImage = getInputImage(image);
    final List<Face> faces = await detector.processImage(inputImage);
    print("Faces detected: ${faces.length}");
    print('Faces: ${faces.length}');
    await performFaceRecognition(faces, image);
  }

  img.Image? image;

  // REMOVED: Permission check - we'll handle it in sendData response instead

  // MODIFIED: Perform Face Recognition - simplified without permission check
  Future<void> performFaceRecognition(List<Face> faces, CameraImage image) async {
    recognitions.clear();

    img.Image convertedImage = convertYUV420ToImage(image);
    img.Image rotatedImage = img.copyRotate(
      convertedImage,
      angle: camDirec == CameraLensDirection.front ? 270 : 90,
    );

    for (Face face in faces) {
      if (faces.length == 1) {
        Rect faceRect = face.boundingBox;

        img.Image croppedFace = img.copyCrop(
          rotatedImage,
          x: faceRect.left.toInt(),
          y: faceRect.top.toInt(),
          width: faceRect.width.toInt(),
          height: faceRect.height.toInt(),
        );

        recognition = recognizer.recognize(croppedFace, face.boundingBox);

        if (recognition.distance > 1) {
          recognition.name = "Not Recognized";
          if (!isErrorRecognizedTimeCheck) {
            errorMessage = 'Face not recognized';
            onNotRecognized();
            username = recognition.name;
            _officialID = "0000000000";
          }
        }
        recognitions.add(recognition);

        if (recognition.name != "Not Recognized") {
          if (!isRecognizedTimeCheck) {
            // Get user info and proceed directly to recognition
            username = recognition.name;
            _officialID = await sharedPrefsHelper.getOfficialID();

            // Proceed with recognition - permission will be checked in sendData
            onRecognized();
          }
        }
      }
    }

    if (!_isDisposed && mounted) {
      setState(() {
        isBusy = false;
        _scanResults = recognitions;
      });
    }
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
      print('--- InputImage Debug ---');
      print('cameraImage.format.raw: ${cameraImage.format.raw}');
      print('cameraImage.width: ${cameraImage.width}');
      print('cameraImage.height: ${cameraImage.height}');
      print('cameraImage.planes.first.bytesPerRow: ${cameraImage.planes.first.bytesPerRow}');
      print('description.sensorOrientation: ${description.sensorOrientation}');

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
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;

    if (controller != null) {
      // UNIVERSAL CAMERA PREVIEW FIX - Works on all devices
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

      // Face detection overlay
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: buildResult(),
        ),
      );
      // Success/Error messages handling
      if (isRecognizedTimeCheck && !dataSendChecker) {
        dataSendChecker = true;
        Future.microtask(() {
          sendData(
            onSuccess: (bool success) {
              if (!_isDisposed && mounted) {
                setState(() {
                  isCheckingPermission = false;
                  isRecognized = true;
                });
              }
              _locationService.stopLocationUpdates();
              Future.delayed(Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => Navigation_Class()),
                  );
                  showToast("Attendance submitted successfully!");
                }
              });
            },
            onError: (String error) {
              print('Error occurred: $error');
              _locationService.stopLocationUpdates();
              dataSendChecker = false;
              if (!_isDisposed && mounted) {
                setState(() {
                  isCheckingPermission = false;
                  isRecognized = false;
                  isRecognizedTimeCheck = false;
                  isErrorRecognized = true;
                  isErrorRecognizedTimeCheck = true;
                });
              }
              if (error.contains('Permission Denied') ||
                  error.contains('not allow to remote check in') ||
                  error.contains('are not allow to remote check in')) {
                errorMessage = 'Remote attendance not allowed';
              } else if (error.contains('message')) {
                try {
                  final jsonError = jsonDecode(error);
                  errorMessage = jsonError['message'] ?? 'Request failed';
                } catch (e) {
                  errorMessage = 'Request failed';
                }
              } else {
                errorMessage = 'Request failed: Connection error';
              }
              _recognitionTimer?.cancel();
              _recognitionTimer = Timer(Duration(seconds: 5), () {
                if (!_isDisposed && mounted) {
                  setState(() {
                    isErrorRecognized = false;
                    isErrorRecognizedTimeCheck = false;
                    errorMessage = '';
                  });
                }
              });
            },
          );
        });
      }

      if (isRecognized) {
        stackChildren.add(buildSuccessMessage());
      } else if (isErrorRecognized) {
        stackChildren.add(buildErrorMessage());
      }
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.blue,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            SizedBox(height: 10),
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
        ),
      ),
    );
  }


  Widget buildSuccessMessage() {
    return Positioned(
      bottom: 0.0,
      left: 0.0,
      width: size.width,
      child: Container(
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                  child: _imagePath == null ? Icon(Icons.person, size: 30, color: Colors.white) : null,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Successfully data updated',
                        style: TextStyle(
                          fontSize: 16.0,
                        ),
                      ),
                      Text(
                        'Name: $username',
                        style: TextStyle(
                          fontSize: 16.0,
                        ),
                      ),
                      Text(
                        'ID: $_officialID',
                        style: TextStyle(
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                Icons.check_circle_outline,
                size: 24.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Loading message while verifying permission
  Widget buildLoadingMessage() {
    return Positioned(
      bottom: 0.0,
      left: 0.0,
      width: size.width,
      child: Container(
        margin: EdgeInsets.all(5),
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Verifying attendance...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Name: $username',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MODIFIED: Better error message with specific error types and full error text
  Widget buildErrorMessage() {
    bool isUnknownFace = username == "Not Recognized";
    String title = isUnknownFace ? 'Face Not Recognized' : 'Permission Denied';
    String subtitle = isUnknownFace
        ? 'Unknown person detected'
        : errorMessage.isNotEmpty
        ? errorMessage
        : 'Remote attendance not allowed';

    return Positioned(
      bottom: 0.0,
      left: 0.0,
      width: size.width,
      child: Container(
        margin: EdgeInsets.all(8), // Responsive margin
        padding: EdgeInsets.all(12), // Responsive padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive sizes based on screen width
            final bool isSmallScreen = constraints.maxWidth < 360;
            final bool isLargeScreen = constraints.maxWidth > 600;

            // Responsive dimensions
            final double imageSize = isSmallScreen ? 70 : (isLargeScreen ? 90 : 60);
            final double imageHeight = isSmallScreen ? 80 : (isLargeScreen ? 100 : 90);
            final double iconSize = isSmallScreen ? 24 : (isLargeScreen ? 35 : 30);
            final double rightIconSize = isSmallScreen ? 20 : (isLargeScreen ? 28 : 24);
            final double spacing = isSmallScreen ? 6 : (isLargeScreen ? 16 : 10);
            final double titleFontSize = isSmallScreen ? 14 : (isLargeScreen ? 18 : 16);
            final double textFontSize = isSmallScreen ? 12 : (isLargeScreen ? 16 : 14);
            final double detailFontSize = isSmallScreen ? 11 : (isLargeScreen ? 15 : 14);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image/Icon Container
                Container(
                  width: imageSize,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    image: (!isUnknownFace && _imagePath != null)
                        ? DecorationImage(
                      image: FileImage(File(_imagePath!)),
                      fit: BoxFit.cover,
                    )
                        : null,
                    color: (isUnknownFace || _imagePath == null) ? Colors.grey[300] : null,
                  ),
                  child: (isUnknownFace || _imagePath == null)
                      ? Icon(
                    isUnknownFace ? Icons.person_off : Icons.block,
                    size: iconSize,
                    color: Colors.white,
                  )
                      : null,
                ),

                SizedBox(width: spacing),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          height: 1.2,
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 2 : 4),

                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: textFontSize,
                          height: 1.3,
                        ),
                        maxLines: isSmallScreen ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (!isUnknownFace) ...[
                        SizedBox(height: isSmallScreen ? 2 : 6),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Name: $username',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: detailFontSize,
                            ),
                          ),
                        ),

                        SizedBox(height: 2),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'ID: $_officialID',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: detailFontSize,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(width: spacing - 2),

                // Right Icon
                Icon(
                  isUnknownFace ? Icons.error_outline : Icons.block,
                  color: Colors.yellow.shade200,
                  size: rightIconSize,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  void onRecognized() {
    if (!isRecognizedTimeCheck && !_isDisposed) {
      setState(() {
        isRecognizedTimeCheck = true;
        isCheckingPermission = true; // Show loading immediately
      });
    }
  }

  void onNotRecognized() {
    if (!isErrorRecognizedTimeCheck && !_isDisposed) {
      setState(() {
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

  Future<void> sendData({
    required Function(bool success) onSuccess,
    required Function(String error) onError,
  }) async {
    print("Here Send $latitude");
    if (latitude != null && longitude != null) {
      _locationService.stopLocationUpdates();

      String? token ="";
      final String? url = "await variables.getRemote_AttendaceRequestAPI()";
      int? userId = 0;

      DateTime now = DateTime.now();
      String formattedDate = DateFormat('yyyy-MM-dd').format(now);
      String formattedTime = DateFormat('HH:mm:ss').format(now);

      print('Date: $formattedDate');
      print('Time: $formattedTime');

      print("Request:$formattedDate");

      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      Map<String, dynamic> body = {
        "date": formattedDate,
        "time": formattedTime,
        "device": deviceName,
        "model": deviceModel,
        "latitude": latitude,
        "longitude": longitude,
        "employee": userId,
      };

      final client = http.Client();
      try {
        final response = await http
            .post(
          Uri.parse(url!),
          headers: headers,
          body: jsonEncode(body),
        )
            .timeout(Duration(seconds: 10));

        print("Response:${response.statusCode}");
        print("API URL :${url}");
        if (response.statusCode == 200 || response.statusCode == 201) {
          print('Success: ${response.body}');
          onSuccess(true);
          latitude = '';
          longitude = '';
        } else {
          onError(response.body);
          print('Error: ${response.statusCode}, ${response.body}');
          latitude = '';
          longitude = '';
        }
      } catch (e) {
        if (e is TimeoutException) {
          print("Request timed out.");
          onError("Request timed out");
        } else {
          print("Exception: $e");
          onError("Exception: $e");
        }
      } finally {
        client.close();
      }
    } else {
      showToast("Location not found");
    }
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.red,
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
          showToast("Poor connection ");
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
      // Mirror the box coordinates for front camera to match preview
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
          text: "${face.name}  ");
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