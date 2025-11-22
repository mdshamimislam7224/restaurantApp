import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'InternetCheckCallback.dart';

class Internet_check {
  Future<void> checkConnectivity(InternetCheckCallback callback) async {
    final ConnectivityResult result = await Connectivity().checkConnectivity();

    if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
      await _checkInternet(callback);
    } else {
      callback.onInternetCheck(false, "Please connect to the Internet.");
    }
  }

  Future<void> _checkInternet(InternetCheckCallback callback) async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse('https://www.google.com')).timeout(Duration(seconds: 3));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final latency = stopwatch.elapsedMilliseconds;
        String qualityMessage = _determineConnectionQuality(latency);
        callback.onInternetCheck(true, "Internet available. Quality: $qualityMessage");
      } else {
        callback.onInternetCheck(false, "Failed to connect. Status code: ${response.statusCode}");
      }
    } catch (e) {
      callback.onInternetCheck(false, "Internet unavailable. Error: $e");
    }
  }

  String _determineConnectionQuality(int latency) {
    if (latency < 50) {
      return "Excellent connection";
    } else if (latency < 100) {
      return "Good connection";
    } else if (latency < 200) {
      return "Fair connection";
    } else {
      return "Poor connection";
    }
  }
}
