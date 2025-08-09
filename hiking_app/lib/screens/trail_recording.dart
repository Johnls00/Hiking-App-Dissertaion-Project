import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hiking_app/utilities/user_location_tracker.dart';
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide Position, LocationSettings;
import 'package:latlong2/latlong.dart';

class TrailRecordingScreen extends StatefulWidget {
  const TrailRecordingScreen({super.key});

  @override
  State<TrailRecordingScreen> createState() => _TrailRecordingScreenState();
}

class _TrailRecordingScreenState extends State<TrailRecordingScreen> {
  late MapboxMap mapboxMapController;
  StreamSubscription<Position>? _userPositionStream;

  final Distance _distance = Distance();
  bool _isRecording = false;

  Duration _elapsedTime = Duration.zero;
  double _totalDistance = 0;
  double _currentSpeed = 0;
  double _currentElevation = 0;
  DateTime? _startTime;
  LatLng? _lastPosition;
  Timer? _elapsedTimer;

  List<LatLng> _recordedPath = [];

  @override
  void dispose() {
    _userPositionStream?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    mapboxMapController = controller;
    await mapboxMapController.loadStyleURI(MapboxStyles.OUTDOORS);

    // Disable scale bar
    await mapboxMapController.scaleBar.updateSettings(
      ScaleBarSettings(enabled: false),
    );

    // Enable location component
    await mapboxMapController.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        puckBearingEnabled: true,
      ),
    );

    // Setup position tracking for map camera
    await setupPositionTracking(mapboxMapController);
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _startTime = DateTime.now();
      _elapsedTime = Duration.zero;
      _totalDistance = 0;
      _currentSpeed = 0;
      _currentElevation = 0;
      _recordedPath.clear();
    });

    // Start elapsed time timer
    _elapsedTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (_startTime != null && mounted) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });

    // Get initial position
    try {
      final Position pos = await Geolocator.getCurrentPosition();
      _currentSpeed = pos.speed;
      _currentElevation = pos.altitude;
      _lastPosition = LatLng(pos.latitude, pos.longitude);
      _recordedPath.add(_lastPosition!);
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }

    // Start tracking position for recording
    _userPositionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // Record point every 5 meters
      ),
    ).listen((position) {
      final LatLng userLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      // Update recording statistics
      if (_lastPosition != null) {
        final double delta = _distance(userLocation, _lastPosition!);
        _totalDistance += delta;
      }

      _lastPosition = userLocation;
      _currentSpeed = position.speed;
      _currentElevation = position.altitude;
      _recordedPath.add(userLocation);

      if (mounted) setState(() {});
    });

    debugPrint('🔴 Started trail recording');
  }

  void _stopRecording() {
    _userPositionStream?.cancel();
    _elapsedTimer?.cancel();

    setState(() {
      _isRecording = false;
      _elapsedTime = Duration.zero;
      _totalDistance = 0;
      _currentSpeed = 0;
      _currentElevation = 0;
      _startTime = null;
      _lastPosition = null;
    });

    debugPrint('🛑 Stopped trail recording');
    debugPrint('📊 Recorded ${_recordedPath.length} points');

    // TODO: Save recorded trail to storage/database
    _recordedPath.clear();
  }

  Widget _buildRecordingOverview() {
    return Column(
      children: [
        Text(
          'Ready to record your trail',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard("Time", "00:00:00", ""),
            _buildStatCard("Distance", "0.00", "km"),
            _buildStatCard("Elevation", "0.0", "m"),
          ],
        ),
        SizedBox(height: 20),
        ElevatedButton(
          onPressed: _startRecording,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, size: 20),
              SizedBox(width: 8),
              Text('Start Recording', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingStats() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
            SizedBox(width: 8),
            Text(
              'Recording in progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ],
        ),
        SizedBox(height: 15),
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
              _currentElevation.toStringAsFixed(1),
              "m",
            ),
          ],
        ),
        SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard("Speed", _currentSpeed.toStringAsFixed(1), "m/s"),
            _buildStatCard("Points", _recordedPath.length.toString(), ""),
          ],
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                // TODO: Pause/Resume functionality
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause, size: 18),
                  SizedBox(width: 6),
                  Text('Pause'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _stopRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop, size: 18),
                  SizedBox(width: 6),
                  Text('Stop'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontSize: 28, color: Colors.black)),
            if (unit.isNotEmpty)
              Text(unit, style: TextStyle(fontSize: 18, color: Colors.black)),
          ],
        ),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.black45)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Map background
            MapWidget(onMapCreated: _onMapCreated),

            // Recording status indicator
            if (_isRecording)
              Positioned(
                top: 65,
                left: 20,
                right: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Recording Trail',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Overlay UI
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar with back button and title
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        RoundBackButton(),
                        SizedBox(width: 16),
                      ],
                    ),
                  ),
                  Spacer(),
                  // Bottom card with stats and controls
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: _isRecording
                        ? _buildRecordingStats()
                        : _buildRecordingOverview(),
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