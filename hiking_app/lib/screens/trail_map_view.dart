import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:hiking_app/models/trail.dart';
import 'package:hiking_app/utilities/geofencing_mixin.dart';
import 'package:hiking_app/utilities/maping_utils.dart' as map_utils;
import 'package:hiking_app/utilities/user_location_tracker.dart';
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LocationSettings;
import 'package:latlong2/latlong.dart';

class TrailMapViewScreen extends StatefulWidget {
  const TrailMapViewScreen({super.key});

  @override
  State<TrailMapViewScreen> createState() => _TrailMapViewScreenState();
}

class _TrailMapViewScreenState extends State<TrailMapViewScreen>
    with GeofencingMixin {
  StreamSubscription<geo.Position>?
  _userPositionStream; 
  Trail? _trailRoute;
  late MapboxMap mapboxMapController;
  CircleAnnotationManager? circleAnnotationManager;

  List<LatLng> geofenceTrailPoints = [];

  final Distance _distance = Distance();
  bool _isExiting = false;
  bool _isNavigating = false;

  Duration _elapsedTime = Duration.zero;
  double _totalDistance = 0;
  double _currentSpeed = 0;
  double _currentPace = 0; // in min/km (optional)
  double _currentElevation = 0;
  DateTime? _startTime;
  LatLng? _lastPosition;
  Timer? _elapsedTimer;

  DateTime? _lastMovementTime;
  bool _inactivityAlerted = false;
  final Duration _inactivityDuration = Duration(minutes: 2);

  @override
  void dispose() {
    _isExiting = true;
    _userPositionStream?.cancel();
    _elapsedTimer?.cancel();
    stopGeofencing().catchError((_) {});
    circleAnnotationManager = null;
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    mapboxMapController = controller;
    await mapboxMapController.loadStyleURI(MapboxStyles.OUTDOORS);

    // disable scale bar
    await mapboxMapController.scaleBar.updateSettings(
      ScaleBarSettings(enabled: false),
    );

    if (_trailRoute == null || _trailRoute!.trackpoints.isEmpty) return;

    await mapboxMapController.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        puckBearingEnabled: true,
      ),
    );

    // Setup position tracking and geofencing with a small delay to ensure map is ready
    await Future.delayed(const Duration(milliseconds: 200));
    await setupPositionTracking(
      mapboxMapController,
      isDisposed: () => _isExiting,
    );

    // Draw the trail line on the map
    await map_utils.addTrailLine(mapboxMapController, _trailRoute!.trackpoints);

    // Add waypoint markers safely
    await _addWaypointMarkers();
  }

  Future<void> _addWaypointMarkers() async {
    try {
      circleAnnotationManager = await mapboxMapController.annotations
          .createCircleAnnotationManager();

      // Add waypoint circles
      for (
        int waypointIndex = 0;
        waypointIndex < _trailRoute!.waypoints.length;
        waypointIndex++
      ) {
        final waypoint = _trailRoute!.waypoints[waypointIndex];

        CircleAnnotationOptions circleAnnotationOptions =
            CircleAnnotationOptions(
              geometry: Point(
                coordinates: Position(waypoint.lon, waypoint.lat),
              ),
              circleColor: Colors.blue.toARGB32(),
              circleOpacity: 1,
              circleRadius: 10,
            );

        await circleAnnotationManager!.create(circleAnnotationOptions);
      }

      debugPrint('Added ${_trailRoute!.waypoints.length} waypoint markers');
    } catch (e) {
      debugPrint('Error adding waypoint markers: $e');
      // Fallback: set manager to null if it failed
      circleAnnotationManager = null;
    }
  }

  Future<void> _startTrailFollowing() async {
    if (_trailRoute == null || _trailRoute!.trackpoints.isEmpty) return;

    // Setup geofencing for the trail using mixin
    await setupTrailGeofencing(_trailRoute!, mapboxMapController);

    // Convert trackpoints to LatLng for use in navigation
    geofenceTrailPoints = _trailRoute!.trackpoints
        .map(
          (e) => LatLng(
            e.coordinates.lat.toDouble(),
            e.coordinates.lng.toDouble(),
          ),
        )
        .toList();

    setState(() {
      _isNavigating = true;
      _startTime = DateTime.now();
      _elapsedTime = Duration.zero;
      _totalDistance = 0;
      _currentSpeed = 0;
      _currentPace = 0;
      _currentElevation = 0;
    });

    _elapsedTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_startTime != null && mounted) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });


    _lastMovementTime = DateTime.now();
    _inactivityAlerted = false;


    // Get initial user position for stats
    final geo.Position pos = await geo.Geolocator.getCurrentPosition();
    _currentSpeed = pos.speed;
    _currentPace = (_currentSpeed > 0) ? (1000 / _currentSpeed) / 60 : 0;
    _currentElevation = pos.altitude;

    // Start tracking position with immediate updates
    _userPositionStream =
        geo.Geolocator.getPositionStream(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.bestForNavigation,
            distanceFilter: 0, // Update on any movement
            timeLimit: Duration(seconds: 1), // Force update every second
          ),
        ).listen((position) async {
          if (_isExiting || !mounted) return;
          final LatLng userLocation = LatLng(
            position.latitude,
            position.longitude,
          );

          // Update navigation statistics
          if (_lastPosition != null) {
            final double delta = _distance(userLocation, _lastPosition!);
            _totalDistance += delta;

            if (delta > 1.0) {
              _lastMovementTime = DateTime.now();
              _inactivityAlerted = false;
            }
          }

          _lastPosition = userLocation;
          _currentSpeed = position.speed;
          _currentPace = (_currentSpeed > 0) ? (1000 / _currentSpeed) / 60 : 0;
          _currentElevation = position.altitude;


          // Update geofencing progress with current location
          updateProgressFromLocation(userLocation);

          // Force immediate UI update for trail status
          if (_isExiting) return;
          if (mounted) {
            setState(() {});
          }

          // Inactivity alert (navigation feature, not geofencing)
          if (_lastMovementTime != null &&
              DateTime.now().difference(_lastMovementTime!) >
                  _inactivityDuration &&
              !_inactivityAlerted) {
            _inactivityAlerted = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ You\'ve been inactive for over 2 minutes'),
                ),
              );
            }
          }
        });
  }

  Future<void> _cleanup() async {
    if (_isExiting) return;
    _isExiting = true;

    try {
      await _userPositionStream?.cancel();
    } catch (_) {}
    _userPositionStream = null;

    try {
      _elapsedTimer?.cancel();
    } catch (_) {}
    _elapsedTimer = null;

    try {
      await stopGeofencing();
    } catch (e) {
      debugPrint('Error stopping geofencing during cleanup: $e');
    }

    // Turn off Mapbox location component & following
    try {
      await mapboxMapController.location.updateSettings(
        LocationComponentSettings(
          enabled: false,
          pulsingEnabled: false,
          puckBearingEnabled: false,
        ),
      );
    } catch (_) {}

    await map_utils.safelyCleanupAnnotationManager(circleAnnotationManager);
    circleAnnotationManager = null;
  }

  void _stopTrailNavigation() {
    _userPositionStream?.cancel();
    _elapsedTimer?.cancel();

    if (mounted) {
      stopGeofencing().catchError((error) {
        debugPrint('Error stopping geofencing: $error');
      });
    }

    setState(() {
      _isNavigating = false;
      _elapsedTime = Duration.zero;
      _totalDistance = 0;
      _currentSpeed = 0;
      _currentPace = 0;
      _currentElevation = 0;
      _startTime = null;
      _lastPosition = null;

    });

    debugPrint('Stopped trail navigation and geofence monitoring');
  }


  Widget _buildTrailOverview() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard(
              "Distance",
              (_trailRoute!.distance / 1000).toStringAsFixed(2),
              "km",
            ),
            _buildStatCard(
              "Elevation",
              _trailRoute!.elevation.toStringAsFixed(2),
              "m",
            ),
            _buildStatCard(
              "Time",
              _trailRoute!.timeToComplete.inMinutes.toString(),
              "mins",
            ),
          ],
        ),
        SizedBox(height: 10),
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
            child: Text('Start Navigation', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationStats() {
    return Column(
      children: [
        buildTrailProgressWidget(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard("Time", _formatDuration(_elapsedTime), ""),
            _buildStatCard(
              "Distance",
              (_totalDistance / 1000).toStringAsFixed(2),
              "km",
            ),
            _buildStatCard(
              "Elevation",
              _currentElevation.toStringAsFixed(2),
              "m",
            ),
          ],
        ),
        SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard("Pace", _currentPace.toStringAsFixed(2), "min/km"),
            _buildStatCard("Speed", _currentSpeed.toStringAsFixed(1), "m/s"),
          ],
        ),
        SizedBox(height: 10),
        Center(
          child: ElevatedButton(
            onPressed: _stopTrailNavigation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 140),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Stop Navigation', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit) {
    return Column(
      children: [
        Row(
          children: [
            Text(value, style: TextStyle(fontSize: 25, color: Colors.black)),
            if (unit.isNotEmpty)
              Text(unit, style: TextStyle(fontSize: 20, color: Colors.black)),
          ],
        ),
        Text(label, style: TextStyle(fontSize: 16, color: Colors.black45)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    _trailRoute = ModalRoute.of(context)!.settings.arguments as Trail;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _cleanup();
        } else {
          await _cleanup();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // Map background
              MapWidget(
                key: ValueKey('trail-map-${_trailRoute?.name ?? UniqueKey()}'),
                onMapCreated: _onMapCreated,
              ),

              // On/Off Trail Status Banner
              if (_isNavigating)
                Positioned(
                  top: 65,
                  left: 120,
                  right: 120,
                  child: buildGeofenceStatusWidget(),
                ),

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
                          if (!_isNavigating)
                            RoundBackButton(
                              onPressed: () async {
                                await _cleanup();
                                if (context.mounted &&
                                    Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          // SizedBox(width: 20),
                          if (_isNavigating)
                            Flexible(
                              flex: 1,
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                child: Center(
                                  child: SizedBox(
                                    width: 166,
                                    height: 49,
                                    child: Center(
                                      child: Text(
                                        "Following:\n${_trailRoute!.name}",
                                        textAlign: TextAlign.center,
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
                          // SizedBox(width: 69),
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
                          _isNavigating
                              ? _buildNavigationStats()
                              : _buildTrailOverview(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
