import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:hiking_app/models/trail_geofence.dart';
import 'package:hiking_app/models/route.dart';
import 'package:hiking_app/providers/trail_geofence_service.dart';
import 'package:hiking_app/utilities/geofence_utils.dart';
import 'package:latlong2/latlong.dart';

/// Fixed version of GeofencingMixin with proper trail status widget
mixin GeofencingMixin<T extends StatefulWidget> on State<T> {
  late final TrailGeofenceService _geofenceService;
  final List<TrailGeofence> _activeGeofences = [];

  final double defaultRadius = 20.0;
  final double defaultIntervalDistance = 40.0; // meters
  final double minStartEndDistance = 100.0; // Minimum distance between start/end for separate geofences
  final Duration minTrailTime = Duration(minutes: 2); // Minimum time before end can be triggered
  
  // Trail progress tracking
  bool _trailStarted = false;
  DateTime? _trailStartTime;
  int _checkpointsReached = 0;
  double _estimatedProgress = 0.0; // 0.0 to 1.0
  bool _allowEndCompletion = false;

  @override
  void initState() {
    super.initState();
    _geofenceService = TrailGeofenceService();
    _setupGeofenceEventListening();
  }

  /// Get current geofence status for UI
  Widget buildGeofenceStatusWidget() {
    return ListenableBuilder(
      listenable: _geofenceService,
      builder: (context, child) {
        final isOnTrail = _isUserOnTrail();

        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isOnTrail ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isOnTrail
                ? "✅ On Trail"
                : "⚠️ You're off the trail!",
            style: TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  /// Determine if user is currently on the trail
  bool _isUserOnTrail() {
    if (!_geofenceService.isMonitoring) {
      return true; // Default to on-trail if not monitoring
    }

    // Get currently active geofences
    final activeGeofences = _geofenceService.getActiveGeofenceObjects();
    
    // Check if user is in any corridor geofences (these represent the trail path)
    final inCorridorGeofence = activeGeofences.any(
      (geofence) => geofence.type == GeofenceType.corridor
    );
    
    if (inCorridorGeofence) {
      return true; // User is in trail corridor
    }
    
    // If no corridor geofences but user is in start/waypoint/checkpoint geofences, consider on-trail
    final inTrailRelatedGeofence = activeGeofences.any(
      (geofence) => geofence.type == GeofenceType.trailStart ||
                   geofence.type == GeofenceType.waypoint ||
                   geofence.type == GeofenceType.checkpoint
    );
    
    if (inTrailRelatedGeofence) {
      return true; // User is at trail point
    }
    
    // If user just started and hasn't moved much, consider on-trail
    if (_trailStarted && _trailStartTime != null) {
      final timeSinceStart = DateTime.now().difference(_trailStartTime!);
      if (timeSinceStart < Duration(minutes: 1)) {
        return true; // Grace period after starting
      }
    }
    
    return false; // User is off trail
  }

  /// Setup geofencing for a trail route
  Future<void> setupTrailGeofencing(
    TrailRoute route,
    MapboxMap mapController,
  ) async {
    try {
      // Clear existing geofences and reset progress tracking
      _geofenceService.clearGeofences();
      _activeGeofences.clear();
      _resetTrailProgress();

      // Convert trackpoints to LatLng for corridor geofencing
      final trailPoints = route.trackpoints
          .map(
            (point) => LatLng(
              point.coordinates.lat.toDouble(),
              point.coordinates.lng.toDouble(),
            ),
          )
          .toList();

      // 1. Create corridor geofences along the trail path
      _geofenceService.addTrailCorridorGeofences(
        'corridor_${route.name.toLowerCase().replaceAll(' ', '_')}',
        '${route.name} Corridor',
        trailPoints,
        corridorWidth: defaultRadius, // 20m wide corridor
        segmentDistance:
            defaultIntervalDistance, // Geofence every 40m for good overlap
      );

      // 2. Generate geofences from waypoints
      final geofences = GeofenceUtils.generateGeofencesFromWaypoints(
        route.waypoints,
        defaultRadius: defaultRadius,
      );

      // Add waypoint geofences to service
      for (final geofence in geofences) {
        _geofenceService.addGeofence(geofence);
        _activeGeofences.add(geofence);
      }

      // 3. Add start and end geofences
      if (route.trackpoints.isNotEmpty) {
        final startPoint = route.trackpoints.first;
        final endPoint = route.trackpoints.last;

        final startGeofence = TrailGeofence(
          id: 'trail_start',
          name: 'Trail Start',
          center: LatLng(
            startPoint.coordinates.lat.toDouble(),
            startPoint.coordinates.lng.toDouble(),
          ),
          radius: defaultRadius * 2,
          description: 'Starting point of ${route.name}',
          type: GeofenceType.trailStart,
        );

        final endGeofence = TrailGeofence(
          id: 'trail_end',
          name: 'Trail End',
          center: LatLng(
            endPoint.coordinates.lat.toDouble(),
            endPoint.coordinates.lng.toDouble(),
          ),
          radius: defaultRadius * 2,
          description: 'End point of ${route.name}',
          type: GeofenceType.trailEnd,
        );

        // Only add separate end geofence if distance from start is significant
        if (_calculateDistance(startPoint, endPoint) > minStartEndDistance) {
          _geofenceService.addGeofence(endGeofence);
          _activeGeofences.add(endGeofence);
          _allowEndCompletion = true; // Allow trail end completion
        }

        _geofenceService.addGeofence(startGeofence);
        _activeGeofences.add(startGeofence);
      }

      // Start monitoring
      await _geofenceService.startMonitoring();

      // final totalGeofences = _geofenceService.geofences.length;
      // _showGeofenceSetupComplete(totalGeofences);
    } catch (e) {
      _showError('Failed to setup geofencing: $e');
    }
  }

  /// Listen to geofence events
  void _setupGeofenceEventListening() {
    _geofenceService.eventStream.listen((event) {
      _handleGeofenceEvent(event);
    });
  }

  /// Handle geofence enter/exit events
  void _handleGeofenceEvent(GeofenceEvent event) {
    final message = GeofenceUtils.getNotificationMessage(event);
    final isEntering = event.eventType == GeofenceEventType.enter;

    // Show notification only if message is not empty (skip corridor geofences)
    if (message.isNotEmpty) {
      _showGeofenceNotification(message, isEntering);
    }

    // Update progress tracking
    _updateTrailProgress(event);

    // Log event for analytics
    _logGeofenceEvent(event);
  }

  /// Show geofence notification to user
  void _showGeofenceNotification(String message, bool isEntering) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isEntering ? Icons.location_on : Icons.location_off,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isEntering ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Update trail progress based on geofence events
  void _updateTrailProgress(GeofenceEvent event) {
    if (event.eventType == GeofenceEventType.enter) {
      switch (event.geofence.type) {
        case GeofenceType.trailStart:
          _onTrailStarted();
          break;
        case GeofenceType.checkpoint:
        case GeofenceType.waypoint:
          _onCheckpointReached(event.geofence);
          break;
        case GeofenceType.trailEnd:
          _onTrailCompleted();
          break;
        default:
          break;
      }
    }
  }

  /// Called when hiker starts the trail
  void _onTrailStarted() {
    debugPrint('Trail started - timer and tracking begun');
    _trailStarted = true;
    _trailStartTime = DateTime.now();
  }

  /// Called when hiker reaches a checkpoint or waypoint
  void _onCheckpointReached(TrailGeofence geofence) {
    debugPrint('Checkpoint reached: ${geofence.name}');
    _checkpointsReached++;

    // Update estimated progress based on geofence types
    final totalProgressGeofences = _activeGeofences
        .where((g) => g.type == GeofenceType.checkpoint || 
                     g.type == GeofenceType.waypoint ||
                     g.type == GeofenceType.corridor)
        .length;
    
    if (totalProgressGeofences > 0) {
      _estimatedProgress = _checkpointsReached / totalProgressGeofences;
    }

    // After reaching several checkpoints, allow end completion for close start/end trails
    if (!_allowEndCompletion && _checkpointsReached >= 3) {
      _allowEndCompletion = true;
      debugPrint('Trail progress sufficient - end completion now allowed');
    }

    debugPrint('Progress: ${(_estimatedProgress * 100).toStringAsFixed(1)}% ($_checkpointsReached/$totalProgressGeofences)');
  }

  /// Called when hiker completes the trail
  void _onTrailCompleted() {
    debugPrint('Trail completed!');
    _showTrailCompletionDialog();
  }

  /// Show trail completion dialog
  void _showTrailCompletionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.green),
            SizedBox(width: 8),
            Text('Trail Complete!'),
          ],
        ),
        content: const Text('Congratulations on completing your hike!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Log geofence event for analytics
  void _logGeofenceEvent(GeofenceEvent event) {
    debugPrint('Geofence Event: ${event.toString()}');
  }

 

  /// Show error message
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Stop geofencing monitoring
  Future<void> stopGeofencing() async {
    if (!_geofenceService.isMonitoring) return;
    try {
      await _geofenceService.stopMonitoring();
    } catch (e) {
      debugPrint('Error stopping geofencing: $e');
    }
  }

  @override
  void dispose() {
    try {
      _geofenceService.stopMonitoring().catchError((error) {
        debugPrint('Error stopping geofencing in dispose: $error');
      });
      _geofenceService.dispose();
    } catch (e) {
      debugPrint('Error disposing geofence service: $e');
    }
    super.dispose();
  }

  /// Calculate distance between two trackpoints in meters
  double _calculateDistance(dynamic point1, dynamic point2) {
    final lat1 = point1.coordinates.lat.toDouble();
    final lng1 = point1.coordinates.lng.toDouble();
    final lat2 = point2.coordinates.lat.toDouble();
    final lng2 = point2.coordinates.lng.toDouble();
    
    return _haversineDistance(lat1, lng1, lat2, lng2);
  }

  /// Haversine distance calculation in meters
  double _haversineDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Reset trail progress tracking variables
  void _resetTrailProgress() {
    _trailStarted = false;
    _trailStartTime = null;
    _checkpointsReached = 0;
    _estimatedProgress = 0.0;
    _allowEndCompletion = false;
    debugPrint('Trail progress tracking reset');
  }
}
