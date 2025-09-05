import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:hiking_app/models/trail_geofence.dart';
import 'package:hiking_app/models/trail.dart';
import 'package:hiking_app/models/waypoint.dart';
import 'package:hiking_app/models/waypoint_interaction.dart';
import 'package:hiking_app/services/trail_geofence_service.dart';
import 'package:hiking_app/services/waypoint_interaction_service.dart';
import 'package:hiking_app/utilities/geofence_utils.dart';
import 'package:hiking_app/widgets/waypoint_interaction_dialog.dart';
import 'package:latlong2/latlong.dart';

/// Fixed version of GeofencingMixin with proper trail status widget
mixin GeofencingMixin<T extends StatefulWidget> on State<T> {
  late final TrailGeofenceService _geofenceService;
  final List<TrailGeofence> _activeGeofences = [];

  // Optimized settings for faster response
  final double defaultRadius = 15.0; // Slightly smaller for quicker entry/exit
  final double defaultIntervalDistance = 25.0; // Closer geofences for better coverage
  final double minStartEndDistance = 50.0; // Reduced distance threshold
  final Duration minTrailTime = Duration(seconds: 30); // Faster minimum time

  // Trail progress tracking
  bool _trailStarted = false;
  DateTime? _trailStartTime;
  int _checkpointsReached = 0;
  double _estimatedProgress = 0.0; // 0.0 to 1.0
  bool _allowEndCompletion = false;
  
  // Trackpoint-based progress tracking
  List<LatLng> _trailTrackpoints = [];
  int _lastPassedTrackpointIndex = -1;
  double _trackpointProgress = 0.0;

  // Add trail status tracking
  bool _isCurrentlyOnTrail = true; // Track current trail status
  
  // Current trail reference for waypoint interactions
  Trail? _currentTrail;

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
            isOnTrail ? "✅ On Trail" : "⚠️ You're off the trail!",
            style: TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  /// Build trail progress bar widget
  Widget buildTrailProgressWidget() {
    return Container(
      padding: EdgeInsets.all(10),
      margin: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          // BoxShadow(
          //   color: Colors.black.withOpacity(0.1),
          //   blurRadius: 4,
          //   offset: Offset(0, 0),
          // ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trail Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '${(_estimatedProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _estimatedProgress > 0.8 ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Progress bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _estimatedProgress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue,
                      _estimatedProgress > 0.5 ? Colors.green : Colors.blue,
                      if (_estimatedProgress > 0.8) Colors.green[700]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          SizedBox(height: 8),

          // Progress details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_trailStarted) ...[

                Row(
                  children: [
                    Icon(
                      _estimatedProgress > 0.9
                          ? Icons.flag
                          : _estimatedProgress > 0.5
                          ? Icons.directions_walk
                          : Icons.play_arrow,
                      size: 16,
                      color: _estimatedProgress > 0.9
                          ? Colors.green
                          : Colors.blue,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _estimatedProgress > 0.9
                          ? 'Almost there!'
                          : _estimatedProgress > 0.5
                          ? 'Making good progress'
                          : 'Trail started',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _estimatedProgress > 0.9
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(Icons.not_started, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      'Trail not started',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              Text(
                'Checkpoints: $_checkpointsReached',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),

          // Trail status indicator
        ],
      ),
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
      (geofence) => geofence.type == GeofenceType.corridor,
    );

    if (inCorridorGeofence) {
      return true; // User is in trail corridor
    }

    // If no corridor geofences but user is in start/waypoint/checkpoint geofences, consider on-trail
    final inTrailRelatedGeofence = activeGeofences.any(
      (geofence) =>
          geofence.type == GeofenceType.trailStart ||
          geofence.type == GeofenceType.waypoint ||
          geofence.type == GeofenceType.checkpoint,
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

  /// Calculate user's progress along the trail using trackpoints
  void _calculateTrackpointProgress(LatLng userLocation) {
    if (_trailTrackpoints.isEmpty) return;
    
    double closestDistance = double.infinity;
    int closestTrackpointIndex = -1;
    
    // Find the closest trackpoint to user's current location
    for (int i = 0; i < _trailTrackpoints.length; i++) {
      final distance = _calculateDistanceInMeters(userLocation, _trailTrackpoints[i]);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestTrackpointIndex = i;
      }
    }
    
    // Only update progress if we're reasonably close to the trail (within 50 meters)
    if (closestDistance <= 50.0 && closestTrackpointIndex > _lastPassedTrackpointIndex) {
      _lastPassedTrackpointIndex = closestTrackpointIndex;
      
      // Calculate progress as percentage of trackpoints passed
      _trackpointProgress = (_lastPassedTrackpointIndex + 1) / _trailTrackpoints.length;
      
      // Update the main estimated progress to use trackpoint-based calculation
      _estimatedProgress = _trackpointProgress;
      
      debugPrint(
        'Trackpoint Progress: ${(_estimatedProgress * 100).toStringAsFixed(1)}% '
        '(trackpoint ${_lastPassedTrackpointIndex + 1}/${_trailTrackpoints.length}, '
        'distance to trail: ${closestDistance.toStringAsFixed(1)}m)',
      );
      
      // Allow end completion when we're 90% through the trackpoints
      if (!_allowEndCompletion && _estimatedProgress >= 0.9) {
        _allowEndCompletion = true;
        debugPrint('Trail progress sufficient - end completion now allowed (90% trackpoints passed)');
      }
    }
  }

  /// Calculate distance between two points in meters
  double _calculateDistanceInMeters(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double lat1Rad = point1.latitude * math.pi / 180;
    final double lat2Rad = point2.latitude * math.pi / 180;
    final double deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final double deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Public method to update progress based on current user location
  /// Can be called from screens to provide real-time progress updates
  void updateProgressFromLocation(LatLng userLocation) {
    _calculateTrackpointProgress(userLocation);
    if (mounted) {
      setState(() {
        // Trigger UI update
      });
    }
  }

  /// Setup geofencing for a trail route with optimized settings
  Future<void> setupTrailGeofencing(
    Trail route,
    MapboxMap mapController,
  ) async {
    try {
      // Store current trail reference for waypoint interactions
      _currentTrail = route;
      
      // Clear existing geofences and reset progress tracking
      _geofenceService.clearGeofences();
      _activeGeofences.clear();
      _resetTrailProgress();

      // Store trackpoints for progress calculation
      _trailTrackpoints = route.trackpoints
          .map(
            (point) => LatLng(
              point.coordinates.lat.toDouble(),
              point.coordinates.lng.toDouble(),
            ),
          )
          .toList();

      // Convert trackpoints to LatLng for corridor geofencing
      final trailPoints = _trailTrackpoints;

      // 1. Create corridor geofences with optimized spacing
      _geofenceService.addTrailCorridorGeofences(
        'corridor_${route.name.toLowerCase().replaceAll(' ', '_')}',
        '${route.name} Corridor',
        trailPoints,
        corridorWidth: defaultRadius, // 15m wide corridor
        segmentDistance: defaultIntervalDistance, // Geofence every 25m for better coverage
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
          radius: defaultRadius * 1,
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
          radius: defaultRadius * 1,
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

  /// Update trail status and trigger UI refresh if status changed
  void _updateTrailStatusIfChanged() {
    final newTrailStatus = _isUserOnTrail();
    if (newTrailStatus != _isCurrentlyOnTrail) {
      if (mounted) {
        setState(() {
          _isCurrentlyOnTrail = newTrailStatus;
        });
        
        // If user just got on trail and trail hasn't been started yet, start the trail
        if (newTrailStatus && !_trailStarted) {
          _onTrailStarted();
        }
        
        // Log status change
        debugPrint('Trail status changed: ${_isCurrentlyOnTrail ? "ON TRAIL" : "OFF TRAIL"}');
        
        // Force immediate UI rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        
      }
    }
  }

  /// Listen to geofence events
  void _setupGeofenceEventListening() {
    _geofenceService.eventStream.listen((event) {
      _handleGeofenceEvent(event);
    });
    
    // Also listen to service changes for immediate UI updates
    _geofenceService.addListener(_onGeofenceServiceChanged);
  }

  /// Handle geofence service changes for immediate UI updates
  void _onGeofenceServiceChanged() {
    if (mounted) {
      // Check if trail status changed and update immediately
      _updateTrailStatusIfChanged();
    }
  }

  /// Handle geofence enter/exit events
  void _handleGeofenceEvent(GeofenceEvent event) {
    // Calculate trackpoint-based progress using the event location
    _calculateTrackpointProgress(event.location);
    
    // Update progress tracking
    _updateTrailProgress(event);

    // Check if trail status changed and update UI
    _updateTrailStatusIfChanged();

    // Log event for analytics
    _logGeofenceEvent(event);
  }

  /// Show notification when trail status changes
  // void _showTrailStatusChangeNotification(bool isOnTrail) {
  //   if (!mounted) return;

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Row(
  //         children: [
  //           Icon(
  //             isOnTrail ? Icons.check_circle : Icons.warning,
  //             color: Colors.white,
  //             size: 15,
  //           ),
  //           const SizedBox(width: 8),
  //           Text(isOnTrail ? "Back on trail!" : "You've left the trail"),
  //         ],
  //       ),
  //       backgroundColor: isOnTrail ? Colors.green : Colors.orange,
  //       duration: const Duration(seconds: 3),
  //       behavior: SnackBarBehavior.floating,
  //     ),
  //   );
  // }

  /// Show geofence notification to user
  // void _showGeofenceNotification(String message, bool isEntering) {
  //   if (!mounted) return;

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Row(
  //         children: [
  //           Icon(
  //             isEntering ? Icons.location_on : Icons.location_off,
  //             color: Colors.white,
  //             size: 20,
  //           ),
  //           const SizedBox(width: 8),
  //           Expanded(child: Text(message)),
  //         ],
  //       ),
  //       backgroundColor: isEntering ? Colors.green : Colors.orange,
  //       duration: const Duration(seconds: 4),
  //       behavior: SnackBarBehavior.floating,
  //     ),
  //   );
  // }

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
    // Prevent multiple trail starts
    if (_trailStarted) {
      debugPrint('Trail already started - ignoring duplicate start signal');
      return;
    }
    
    debugPrint('Trail started - timer and tracking begun');
    _trailStarted = true;
    _trailStartTime = DateTime.now();
  }

  /// Called when hiker reaches a checkpoint or waypoint
  void _onCheckpointReached(TrailGeofence geofence) {
    debugPrint('Checkpoint reached: ${geofence.name}');
    _checkpointsReached++;

    if (!mounted || _currentTrail == null) return;

    // Find the corresponding waypoint from the current trail
    Waypoint? matchingWaypoint;
    
    try {
      // Try to find waypoint by name first
      matchingWaypoint = _currentTrail!.waypoints.firstWhere(
        (waypoint) => waypoint.name == geofence.name,
      );
    } catch (e) {
      // If name doesn't match, try to find by proximity to geofence center
      double minDistance = double.infinity;
      for (final waypoint in _currentTrail!.waypoints) {
        final distance = _calculateDistanceInMeters(
          LatLng(waypoint.lat, waypoint.lon),
          geofence.center,
        );
        if (distance < minDistance && distance < 50) { // Within 50m
          minDistance = distance;
          matchingWaypoint = waypoint;
        }
      }
    }

    if (matchingWaypoint != null) {
      // Show waypoint interaction dialog
      _showWaypointInteractionDialog(matchingWaypoint);
    } else {
      // Fallback to simple dialog if no matching waypoint found
      _showSimpleCheckpointDialog(geofence);
    }

    // Progress is now primarily calculated using trackpoints in _calculateTrackpointProgress
    // Keep checkpoint counting for reference but don't use it for main progress calculation
    
    debugPrint(
      'Checkpoint Progress: $_checkpointsReached checkpoints reached, '
      'Overall Progress: ${(_estimatedProgress * 100).toStringAsFixed(1)}% (trackpoint-based)',
    );
  }

  /// Show the waypoint interaction dialog
  void _showWaypointInteractionDialog(Waypoint waypoint) {
    showDialog(
      context: context,
      barrierDismissible: false, // Require user interaction
      builder: (context) => WaypointInteractionDialog(
        waypoint: waypoint,
        onInteractionSaved: (WaypointInteraction interaction) async {
          try {
            await WaypointInteractionService.saveWaypointInteraction(
              interaction,
              trailName: _currentTrail?.name ?? 'current_trail',
            );
            debugPrint('✅ Waypoint interaction saved for ${waypoint.name}');
          } catch (e) {
            debugPrint('❌ Failed to save waypoint interaction: $e');
          }
        },
      ),
    );
  }

  /// Fallback simple dialog for geofences without matching waypoints
  void _showSimpleCheckpointDialog(TrailGeofence geofence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.green),
            const SizedBox(width: 8),
            Text('Reached ${geofence.name}'),
          ],
        ),
        content: const Text('Great progress on your hike!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  /// Called when hiker completes the trail
  void _onTrailCompleted() {
    if (!_trailStarted) {
      debugPrint('Trail completion ignored - trail not started yet');
      return;
    }

    // need to add check that if the users has end so no double completion dialog is shown 
    // also need to add a way to save the trails the user has completed.


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
    _geofenceService.removeListener(_onGeofenceServiceChanged);
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
  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

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
    _isCurrentlyOnTrail = true; // Reset to on-trail
    
    // Reset trackpoint-based progress tracking
    _trailTrackpoints.clear();
    _lastPassedTrackpointIndex = -1;
    _trackpointProgress = 0.0;
    
    debugPrint('Trail progress tracking reset (including trackpoint progress)');
  }
}
