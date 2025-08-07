import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:hiking_app/models/trail_geofence.dart';
import 'package:hiking_app/utilities/trail_geofence_builder.dart';

/// Service for managing and monitoring trail geofences
class TrailGeofenceService extends ChangeNotifier {
  final List<TrailGeofence> _geofences = [];
  final List<String> _activeGeofences = [];
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _currentLocation;
  bool _isMonitoring = false;
  bool _isDisposed = false;

  // Getters
  List<TrailGeofence> get geofences => List.unmodifiable(_geofences);
  List<String> get activeGeofences => List.unmodifiable(_activeGeofences);
  LatLng? get currentLocation => _currentLocation;
  bool get isMonitoring => _isMonitoring;

  // Events stream
  final StreamController<GeofenceEvent> _eventController = StreamController<GeofenceEvent>.broadcast();
  Stream<GeofenceEvent> get eventStream => _eventController.stream;

  /// Add a geofence to monitor
  void addGeofence(TrailGeofence geofence) {
    if (_isDisposed) return;
    if (!_geofences.any((g) => g.id == geofence.id)) {
      _geofences.add(geofence);
      notifyListeners();
      debugPrint('Added geofence: ${geofence.name}');
    }
  }

  /// Remove a geofence from monitoring
  void removeGeofence(String geofenceId) {
    _geofences.removeWhere((g) => g.id == geofenceId);
    _activeGeofences.remove(geofenceId);
    notifyListeners();
    debugPrint('Removed geofence: $geofenceId');
  }

  /// Clear all geofences
  void clearGeofences() {
    _geofences.clear();
    _activeGeofences.clear();
    notifyListeners();
    debugPrint('Cleared all geofences');
  }

  /// Add multiple geofences from waypoints
  void addGeofencesFromWaypoints(List<LatLng> waypoints, {
    double radius = 10.0,
    GeofenceType type = GeofenceType.waypoint,
  }) {
    for (int i = 0; i < waypoints.length; i++) {
      final geofence = TrailGeofence(
        id: 'waypoint_$i',
        name: 'Waypoint ${i + 1}',
        center: waypoints[i],
        radius: radius,
        description: 'Trail waypoint ${i + 1}',
        type: type,
      );
      addGeofence(geofence);
    }
  }

  /// Create and add corridor geofences along the trail
  void addTrailCorridorGeofences(
    String trailId,
    String trailName,
    List<LatLng> trailPoints, {
    double corridorWidth = 10.0,
    double segmentDistance = 20.0,
  }) {
    if (trailPoints.isEmpty) return;

    final corridorGeofences = TrailGeofenceBuilder.createTrailCorridorGeofences(
      trailId: trailId,
      trailName: trailName,
      trailPoints: trailPoints,
      corridorWidth: corridorWidth,
      segmentDistance: segmentDistance,
    );

    for (final geofence in corridorGeofences) {
      addGeofence(geofence);
    }

    debugPrint('✅ Added ${corridorGeofences.length} corridor geofences');
  }

  /// Start monitoring geofences
  Future<void> startMonitoring() async {
    if (_isMonitoring || _isDisposed) return;

    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // Start location monitoring
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _updateLocation(LatLng(position.latitude, position.longitude));
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );

    _isMonitoring = true;
    notifyListeners();
    debugPrint('Started geofence monitoring');
  }

  /// Stop monitoring geofences
  Future<void> stopMonitoring() async {
    if (_isDisposed) return;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isMonitoring = false;
    _activeGeofences.clear();
    if (!_isDisposed) notifyListeners();
    debugPrint('Stopped geofence monitoring');
  }

  /// Update current location and check geofences
  void _updateLocation(LatLng location) {
    if (_isDisposed) return;
    _currentLocation = location;
    _checkGeofences(location);
    if (!_isDisposed) notifyListeners();
  }

  /// Check if current location is within any geofences
  void _checkGeofences(LatLng location) {
    for (final geofence in _geofences) {
      final isInside = geofence.isLocationInside(location);
      final wasActive = _activeGeofences.contains(geofence.id);

      if (isInside && !wasActive) {
        // Entered geofence
        _activeGeofences.add(geofence.id);
        _eventController.add(GeofenceEvent(
          geofence: geofence,
          eventType: GeofenceEventType.enter,
          location: location,
          timestamp: DateTime.now(),
        ));
        debugPrint('Entered geofence: ${geofence.name}');
      } else if (!isInside && wasActive) {
        // Exited geofence
        _activeGeofences.remove(geofence.id);
        _eventController.add(GeofenceEvent(
          geofence: geofence,
          eventType: GeofenceEventType.exit,
          location: location,
          timestamp: DateTime.now(),
        ));
        debugPrint('Exited geofence: ${geofence.name}');
      }
    }
  }

  /// Get the nearest geofence to current location
  TrailGeofence? getNearestGeofence() {
    if (_currentLocation == null || _geofences.isEmpty) return null;

    TrailGeofence? nearest;
    double minDistance = double.infinity;

    for (final geofence in _geofences) {
      final distance = geofence.distanceToLocation(_currentLocation!);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = geofence;
      }
    }

    return nearest;
  }

  /// Get distance to nearest geofence
  double? getDistanceToNearestGeofence() {
    if (_currentLocation == null) return null;
    final nearest = getNearestGeofence();
    return nearest?.distanceToLocation(_currentLocation!);
  }

  /// Check if currently inside any geofence
  bool isInsideAnyGeofence() {
    return _activeGeofences.isNotEmpty;
  }

  /// Get list of currently active geofences
  List<TrailGeofence> getActiveGeofenceObjects() {
    return _geofences.where((g) => _activeGeofences.contains(g.id)).toList();
  }

  /// Simulate a geofence event for testing
  void simulateGeofenceEvent(GeofenceEvent event) {
    _eventController.add(event);

    if (event.eventType == GeofenceEventType.enter) {
      if (!_activeGeofences.contains(event.geofence.id)) {
        _activeGeofences.add(event.geofence.id);
      }
    } else {
      _activeGeofences.remove(event.geofence.id);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopMonitoring();
    _eventController.close();
    super.dispose();
  }
}

/// Represents a geofence event (enter/exit)
class GeofenceEvent {
  final TrailGeofence geofence;
  final GeofenceEventType eventType;
  final LatLng location;
  final DateTime timestamp;

  const GeofenceEvent({
    required this.geofence,
    required this.eventType,
    required this.location,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'GeofenceEvent(${eventType.name}: ${geofence.name} at ${location.latitude}, ${location.longitude})';
  }
}

/// Types of geofence events
enum GeofenceEventType {
  enter,
  exit,
}
