// lib/utils/location_tracker.dart

import 'dart:async';

import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

StreamSubscription? userPositionStream;

Future<void> setupPositionTracking(MapboxMap mapController) async {
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
    distanceFilter: 100,
  );

  userPositionStream?.cancel();
  userPositionStream =
      geo.Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((geo.Position? position) {
        if (position != null) {
          mapController.setCamera(
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

