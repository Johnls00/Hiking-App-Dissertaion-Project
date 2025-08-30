// lib/utils/location_tracker.dart

import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:hiking_app/utilities/maping_utils.dart' as map_utils;

StreamSubscription? userPositionStream;

Future<void> setupPositionTracking(MapboxMap mapController, {bool Function()? isDisposed}) async {
  bool serviceEnabled;
  geo.LocationPermission permission;

  serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await geo.Geolocator.checkPermission();
  if (permission == geo.LocationPermission.denied) {
    permission = await geo.Geolocator.requestPermission();
    if (permission == geo.LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == geo.LocationPermission.deniedForever) {
    return Future.error(
      'Location permissions are permanently denied, cannot request permissions.',
    );
  }

  geo.LocationSettings locationSettings = geo.LocationSettings(
    accuracy: geo.LocationAccuracy.high,
    distanceFilter: 25,
  );

  userPositionStream?.cancel();
  userPositionStream =
      geo.Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((geo.Position? position) {
        if (position != null && (isDisposed == null || !isDisposed())) {
          map_utils.safelySetCamera(
            mapController,
            CameraOptions(
              center: Point(
                coordinates: Position(position.longitude, position.latitude),
              ),
              zoom: 15,
            ),
          );
        }
      });
}

/// Cancel the active position tracking stream
Future<void> cancelPositionTracking() async {
  try {
    await userPositionStream?.cancel();
    userPositionStream = null;
    print('📍 Location tracking cancelled successfully');
  } catch (e) {
    print('⚠️ Error cancelling location tracking: $e');
    userPositionStream = null; // Set to null anyway
  }
}

