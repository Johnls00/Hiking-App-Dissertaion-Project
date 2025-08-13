// lib/services/trail_recorder.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart' as gl;
import 'package:latlong2/latlong.dart';
import 'package:hiking_app/models/trackpoint.dart';

class RecordingStats {
  final Duration elapsed;
  final double totalDistanceMeters;
  final double currentSpeed;     // m/s (from geolocator)
  final double currentElevation; // meters
  final int points;

  const RecordingStats({
    required this.elapsed,
    required this.totalDistanceMeters,
    required this.currentSpeed,
    required this.currentElevation,
    required this.points,
  });
}

class TrailRecorder {
  final Distance _distance = Distance();
  final List<Trackpoint> _recorded = [];
  final _statsCtrl = StreamController<RecordingStats>.broadcast();
  final _pointCtrl = StreamController<Trackpoint>.broadcast();

  StreamSubscription<gl.Position>? _sub;
  Timer? _timer;
  DateTime? _start;
  LatLng? _last;
  double _totalDist = 0;
  double _currSpeed = 0;
  double _currEle = 0;

  /// meters between updates (geolocator distanceFilter)
  final int distanceFilterMeters;

  TrailRecorder({this.distanceFilterMeters = 5});

  Stream<RecordingStats> get statsStream => _statsCtrl.stream;
  Stream<Trackpoint> get trackStream => _pointCtrl.stream;

  List<Trackpoint> get recordedTrack => List.unmodifiable(_recorded);

  bool get isRecording => _sub != null;

  Future<void> start() async {
    if (_sub != null) return;

    final enabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Location services are disabled');
    }

    _reset();

    // tick elapsed time (once a second)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitStats();
    });

    final gl.LocationSettings settings = Platform.isAndroid
        ? gl.AndroidSettings(
            accuracy: gl.LocationAccuracy.best,
            distanceFilter: distanceFilterMeters,
            // intervalDuration: const Duration(seconds: 1),  // optional
            timeLimit: const Duration(seconds: 1),
            forceLocationManager: true,
            foregroundNotificationConfig: const gl.ForegroundNotificationConfig(
              notificationTitle: 'Trail recording',
              notificationText: 'Recording your trail in the background',
              enableWakeLock: true,
            ),
          )
        : gl.AppleSettings(
            accuracy: gl.LocationAccuracy.best,
            distanceFilter: distanceFilterMeters,
            timeLimit: const Duration(seconds: 1),
            activityType: gl.ActivityType.fitness,
            allowBackgroundLocationUpdates: true,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
          );

    _sub = gl.Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final lat = pos.latitude.toDouble();
        final lon = pos.longitude.toDouble();
        final tp = Trackpoint(lat: lat, lon: lon, ele: pos.altitude.toDouble());

        _recorded.add(tp);
        _pointCtrl.add(tp);

        final here = LatLng(lat, lon);
        if (_last != null) {
          final d = _distance.as(LengthUnit.Meter, _last!, here);
          _totalDist += d;
        }
        _last = here;
        _currSpeed = pos.speed;      // m/s as provided
        _currEle = pos.altitude;     // meters

        _emitStats();
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _emitStats(); // final push
  }

  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _statsCtrl.close();
    _pointCtrl.close();
  }

  void _reset() {
    _recorded.clear();
    _start = DateTime.now();
    _totalDist = 0;
    _currSpeed = 0;
    _currEle = 0;
    _last = null;
  }

  void _emitStats() {
    final elapsed = _start == null ? Duration.zero : DateTime.now().difference(_start!);
    _statsCtrl.add(
      RecordingStats(
        elapsed: elapsed,
        totalDistanceMeters: _totalDist,
        currentSpeed: _currSpeed,
        currentElevation: _currEle,
        points: _recorded.length,
      ),
    );
  }
}