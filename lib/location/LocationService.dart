import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

class LocationService {
  Location _location = Location();
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;
  LocationData? _currentLocation;
  Timer? _locationUpdateTimer;
  bool _isUpdatingLocation = false;  // Track if location updates are active
  Function? showGpsDialog;

  LocationService({this.showGpsDialog});

  // Starts listening to location updates
  Future<void> startLocationUpdates(
      BuildContext context, {required Function(LocationData position) onSuccess}) async {

    if (_isUpdatingLocation) return; // Prevent duplicate calls
    _isUpdatingLocation = true;

    // Check if location services are enabled and request to enable if not
    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      if (showGpsDialog != null) showGpsDialog!();
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        print('Location services are disabled.');
        _isUpdatingLocation = false;
        return;
      }
    }

    // Check for location permission
    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        print('Location permissions are denied.');
        _isUpdatingLocation = false;
        return;
      }
    }

    // Start a timer to get location updates every 5 seconds
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      _currentLocation = await _location.getLocation();
      onSuccess(_currentLocation!);
    });
  }

  // Stops listening to location updates
  Future<void> stopLocationUpdates() async {
    if (_isUpdatingLocation) {
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;
      _isUpdatingLocation = false;
      print('Location updates stopped');
    }
  }
}
