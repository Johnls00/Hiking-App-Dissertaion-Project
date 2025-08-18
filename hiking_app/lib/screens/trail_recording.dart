import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hiking_app/models/trackpoint.dart';
import 'package:hiking_app/services/trail_recorder_service.dart';
import 'package:hiking_app/utilities/maping_utils.dart';
import 'package:hiking_app/utilities/user_location_tracker.dart';
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LocationSettings;
import 'package:hiking_app/screens/trail_save_screen.dart';

class TrailRecordingScreen extends StatefulWidget {
  const TrailRecordingScreen({super.key});

  @override
  State<TrailRecordingScreen> createState() => _TrailRecordingScreenState();
}

class _TrailRecordingScreenState extends State<TrailRecordingScreen> {
  late MapboxMap mapboxMapController;
  // StreamSubscription<gl.Position>? _userPositionStream;

  // final Distance _distance = Distance();

  // Recording state moved to recorder
  final TrailRecorder _recorder = TrailRecorder(distanceFilterMeters: 5);

  bool _isRecording = false;

  Duration _elapsedTime = Duration.zero;
  double _totalDistance = 0;
  double _currentSpeed = 0;
  double _currentElevation = 0;
  // DateTime? _startTime;
  // LatLng? _lastPosition;
  // Timer? _elapsedTimer;

  // List<Trackpoint> _recordedPath = [];
  final List<Point> _userTrailPointsLine = [];

  StreamSubscription<RecordingStats>? _statsSub;
  StreamSubscription<Trackpoint>? _pointSub;

  @override
  void dispose() {
    // _userPositionStream?.cancel();
    // _elapsedTimer?.cancel();
    _statsSub?.cancel();
    _pointSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    mapboxMapController = controller;
    await mapboxMapController.loadStyleURI(MapboxStyles.OUTDOORS);
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
      _elapsedTime = Duration.zero;
      _totalDistance = 0;
      _currentSpeed = 0;
      _currentElevation = 0;
      _userTrailPointsLine.clear();
    });

    // subscribe to stats
    _statsSub = _recorder.statsStream.listen((s) {
      setState(() {
        _elapsedTime = s.elapsed;
        _totalDistance = s.totalDistanceMeters;
        _currentSpeed = s.currentSpeed;
        _currentElevation = s.currentElevation;
      });
    });

    // subscribe to track points (for map drawing)
    _pointSub = _recorder.trackStream.listen((tp) {
      final lat = tp.lat;
      final lon = tp.lon;
      _userTrailPointsLine.add(Point(coordinates: Position(lon, lat)));
      addUserTrailLine(mapboxMapController, _userTrailPointsLine);
    });

    await _recorder.start();
    debugPrint('🔴 Started trail recording');
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();

    setState(() {
      _isRecording = false;
    });

    debugPrint('🛑 Stopped trail recording');
    debugPrint('📊 Recorded ${_recorder.recordedTrack.length} points');

    // Navigate to save screen instead of automatically saving
    if (mounted && _recorder.recordedTrack.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrailSaveScreen(
            recordedTrack: _recorder.recordedTrack,
            totalDistance: _totalDistance,
            elapsedTime: _elapsedTime,
          ),
        ),
      );
    }
  }
  // Future<void> _startRecording() async {
  //   // Ensure location services are enabled
  //   final isLocationEnabled = await gl.Geolocator.isLocationServiceEnabled();
  //   if (!isLocationEnabled) {
  //     debugPrint('Location services are disabled');
  //     return;
  //   }

  //   setState(() {
  //     _isRecording = true;
  //     _startTime = DateTime.now();
  //     _elapsedTime = Duration.zero;
  //     _totalDistance = 0;
  //     _currentSpeed = 0;
  //     _currentElevation = 0;
  //     _recordedPath.clear();
  //     _userTrailPointsLine.clear();
  //     _lastPosition = null;
  //     // Reset last position
  //   });

  //   // Start elapsed time timer
  //   _elapsedTimer = Timer.periodic(Duration(seconds: 1), (_) {
  //     if (_startTime != null && mounted) {
  //       setState(() {
  //         _elapsedTime = DateTime.now().difference(_startTime!);
  //       });
  //     }
  //   });

  //   if (_userTrailPointsLine.isEmpty) {
  //     final initialPosition = await gl.Geolocator.getCurrentPosition();
  //     _userTrailPointsLine.add(
  //       Point(
  //         coordinates: Position(
  //           initialPosition.longitude,
  //           initialPosition.latitude,
  //         ),
  //       ),
  //     );
  //     _recordedPath.add(
  //       Trackpoint(
  //         lat: initialPosition.latitude.toDouble(),
  //         lon: initialPosition.longitude.toDouble(),
  //         ele: initialPosition.altitude.toDouble(),
  //       ),
  //     );
  //   }

  //   // Build platform-specific location settings for high-frequency updates
  //   final gl.LocationSettings locationSettings = Platform.isAndroid
  //       ? gl.AndroidSettings(
  //           accuracy: gl.LocationAccuracy.best,
  //           distanceFilter: 5, // meters
  //           // intervalDuration: const Duration(seconds: 1),
  //           timeLimit: Duration(seconds: 1), // request updates ~1s
  //           forceLocationManager: true,
  //           foregroundNotificationConfig: const gl.ForegroundNotificationConfig(
  //             notificationTitle: 'Trail recording',
  //             notificationText: 'Recording your trail in the background',
  //             enableWakeLock: true,
  //           ),
  //         )
  //       : gl.AppleSettings(
  //           accuracy: gl.LocationAccuracy.best,
  //           distanceFilter: 5, // meters
  //           timeLimit: Duration(seconds: 1), // request updates ~1s
  //           activityType: gl.ActivityType.fitness,
  //           allowBackgroundLocationUpdates: true,
  //           pauseLocationUpdatesAutomatically: false,
  //           showBackgroundLocationIndicator: true,
  //         );

  //   // Start tracking position for recording - remove initial position setup
  //   _userPositionStream =
  //       gl.Geolocator.getPositionStream(
  //         locationSettings: locationSettings,
  //       ).listen((position) {
  //         final LatLng userLocation = LatLng(
  //           position.latitude,
  //           position.longitude,
  //         );

  //         final ts = position.timestamp?.toIso8601String() ?? 'no-ts';
  //         debugPrint(
  //           'pos @ $ts '
  //           'lat=${position.latitude}, lon=${position.longitude} '
  //           'acc=${position.accuracy}m speed=${position.speed} '
  //           'alt=${position.altitude}',
  //         );
  //         if (_lastPosition != null) {
  //           final delta = _distance.as(
  //             LengthUnit.Meter,
  //             _lastPosition!,
  //             LatLng(position.latitude, position.longitude),
  //           );
  //           debugPrint('Δdist = ${delta.toStringAsFixed(1)} m');
  //         }

  //         // Always add new trackpoint for every position update
  //         _recordedPath.add(
  //           Trackpoint(
  //             lat: position.latitude.toDouble(),
  //             lon: position.longitude.toDouble(),
  //             ele: position.altitude.toDouble(),
  //           ),
  //         );

  //         // Update recording statistics if we have a previous position
  //         if (_lastPosition != null) {
  //           final double delta = _distance.as(
  //             LengthUnit.Meter,
  //             _lastPosition!,
  //             userLocation,
  //           );
  //           debugPrint(
  //             'Distance from last point: ${delta.toStringAsFixed(2)} m',
  //           );
  //           _totalDistance += delta;
  //         }

  //         // Update current position and stats
  //         _lastPosition = userLocation;
  //         _currentSpeed = position.speed;
  //         _currentElevation = position.altitude;
  //         debugPrint(
  //           'Current speed: ${_currentSpeed.toStringAsFixed(2)} m/s, '
  //           'Elevation: ${_currentElevation.toStringAsFixed(2)} m',
  //         );

  //         final lat = position.latitude.toDouble();
  //         final lon = position.longitude.toDouble();
  //         _userTrailPointsLine.add(Point(coordinates: Position(lon, lat)));

  //         addUserTrailLine(mapboxMapController, _userTrailPointsLine);

  //         // Debug print for tracking
  //         debugPrint(
  //           'Recorded point ${_recordedPath.length}: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
  //         );

  //         if (mounted) setState(() {});
  //       });

  //   debugPrint('🔴 Started trail recording');
  // }

  // Future<void> _stopRecording() async {
  //   _userPositionStream?.cancel();
  //   _elapsedTimer?.cancel();

  //   setState(() {
  //     _isRecording = false;
  //     _elapsedTime = Duration.zero;
  //     _totalDistance = 0;
  //     _currentSpeed = 0;
  //     _currentElevation = 0;
  //     _startTime = null;
  //     _lastPosition = null;
  //   });

  //   debugPrint('🛑 Stopped trail recording');
  //   debugPrint('📊 Recorded ${_recordedPath.length} points');

  //   // debugPrint('Saving GPX with ${_recordedPath.length} points');
  //   // for (var i = 0; i < (_recordedPath.length).clamp(0, 3); i++) {
  //   //   final tp = _recordedPath[i];
  //   //   debugPrint('  pt[$i] lat=${tp.lat}, lon=${tp.lon}, ele=${tp.ele}');
  //   // }
  //   // final xml = GpxFileUtil.gpxFromTrackpoints(_recordedPath);
  //   // debugPrint(xml.substring(0, xml.indexOf('</trkseg>') + 9));
  //   // TODO: Save recorded trail to storage/database
  //   await _saveRecording();
  //   _recordedPath.clear();
  // }

  // Future<void> _saveRecording() async {
  //   if (_recordedPath.isEmpty) {
  //     debugPrint('⚠️ No points recorded; skipping GPX save.');
  //     return;
  //   }
  //   try {
  //     final dir = await getApplicationDocumentsDirectory();
  //     final path = p.join(dir.path, 'my_recording.gpx');
  //     await GpxFileUtil.saveTrackpointsAsGpx(
  //       _recordedPath,
  //       path,
  //       name: 'Trail Recording',
  //     );
  //     debugPrint('✅ GPX saved to $path');
  //   } catch (e, st) {
  //     debugPrint('❌ Failed to save GPX: $e');
  //     debugPrint(st.toString());
  //   }
  // }

  Widget _buildRecordingOverview() {
    return Column(
      children: [
        Text(
          'Ready to record your trail?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        //   children: [
        //     _buildStatCard("Time", "00:00:00", ""),
        //     _buildStatCard("Distance", "0.00", "km"),
        //     _buildStatCard("Elevation", "0.0", "m"),
        //   ],
        // ),
        // SizedBox(height: 20),
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
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.center,
        //   children: [
        //     Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
        //     SizedBox(width: 8),
        //     Text(
        //       'Recording in progress',
        //       style: TextStyle(
        //         fontSize: 16,
        //         fontWeight: FontWeight.w500,
        //         color: Colors.red,
        //       ),
        //     ),
        //   ],
        // ),
        // SizedBox(height: 15),
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
            _buildStatCard("Speed", (_currentSpeed * 3.6 ).toStringAsFixed(1), "km/h"),
            _buildStatCard("Points", _recorder.recordedTrack.length.toString(), ""),
          ],
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // ElevatedButton(
            //   onPressed: () {
            //     // TODO: Pause/Resume functionality
            //   },
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.orange,
            //     foregroundColor: Colors.white,
            //     padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(10),
            //     ),
            //   ),
            //   child: Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Icon(Icons.pause, size: 18),
            //       SizedBox(width: 6),
            //       Text('Pause'),
            //     ],
            //   ),
            // ),
            ElevatedButton(
              onPressed: _showFinishedConfirmationDialog,
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

  /// Show finished confirmation dialog
  void _showFinishedConfirmationDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration, color: Colors.green),
            SizedBox(width: 8),
            Text('Trail Complete?'),
          ],
        ),
        content: const Text('Are you ready to finish and save your hike? '),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white,
                ), 
                child: const Text('Resume'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  _stopRecording(); // Stop recording and navigate to save screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, 
                  foregroundColor: Colors.white,
                ), 
                child: const Text('Finish'),
              ),
            ],
          ),
        ],
      ),
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
                top: 15,
                left: 100,
                right: 100,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 16,
                      ),
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
                  if (!_isRecording)
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [RoundBackButton(onPressed: () { Navigator.pushReplacementNamed(context, '/home'); },), SizedBox(width: 16)],
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
                          color: Colors.black.withValues(alpha: 0.1),
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
