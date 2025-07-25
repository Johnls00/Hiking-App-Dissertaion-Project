import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hiking_app/models/route.dart';
import 'package:hiking_app/utilities/maping_utils.dart';
import 'package:hiking_app/utilities/user_location_tracker.dart';
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Position;
import 'package:latlong2/latlong.dart';
import 'package:hiking_app/utilities/geofence_utils.dart';

class MapTrailViewScreen extends StatefulWidget {
  const MapTrailViewScreen({super.key});

  @override
  State<MapTrailViewScreen> createState() => _MapTrailViewScreenState();
}

StreamSubscription? userPositionStream;

class _MapTrailViewScreenState extends State<MapTrailViewScreen> {
  TrailRoute? _trailRoute; // Store trailRoute from args for use in callbacks
  late MapboxMap mapboxMapController;
  List<LatLng> geofenceTrailPoints = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    userPositionStream?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    mapboxMapController = controller;
    await mapboxMapController.loadStyleURI(MapboxStyles.OUTDOORS);

    // Enable scale bar
    await mapboxMapController.scaleBar.updateSettings(
      ScaleBarSettings(enabled: true),
    );

    if (_trailRoute == null || _trailRoute!.trackpoints.isEmpty) return;

    mapboxMapController.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    // Draw the trail line on the map
    await addTrailLine(mapboxMapController, _trailRoute!.trackpoints);
    await setupPositionTracking(mapboxMapController);
  }

  Future<void> _startTrailFollowing() async {
  if (_trailRoute == null || _trailRoute!.trackpoints.isEmpty) return;

  // Convert to LatLng points
  geofenceTrailPoints = _trailRoute!.trackpoints
      .map((e) => LatLng(e.coordinates.lat.toDouble() , e.coordinates.lng.toDouble()))
      .toList();

  Position pos = await Geolocator.getCurrentPosition();
  LatLng user = LatLng(pos.latitude, pos.longitude);

  // 3. Get trail start or closest point
  LatLng trailPoint = geofenceTrailPoints.first;

  // 4. Draw line
  await addLineBetweenPoints(mapboxMapController, user, trailPoint);


  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Started following trail: ${_trailRoute!.name}')),
  );
}

  @override
  Widget build(BuildContext context) {
    _trailRoute = ModalRoute.of(context)!.settings.arguments as TrailRoute;

    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),
      body: SafeArea(
        child: Stack(
          children: [
            // Map background
            MapWidget(onMapCreated: _onMapCreated),

            // Overlay UI
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RoundBackButton(),
                        SizedBox(width: 20),
                        Flexible(
                          flex: 1,
                          child: Material(
                            color: Color.fromRGBO(221, 221, 221, 1),
                            borderRadius: BorderRadius.circular(25),
                            child: Center(
                              child: SizedBox(
                                width: 166,
                                height: 49,
                                child: Center(
                                  child: Text(
                                    _trailRoute!.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 69),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Spacer(),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: _startTrailFollowing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Start Following Trail',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
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
}
