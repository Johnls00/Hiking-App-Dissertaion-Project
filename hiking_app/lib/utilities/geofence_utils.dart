import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:hiking_app/models/trail_geofence.dart';
import 'package:hiking_app/models/waypoint.dart';
import 'package:hiking_app/services/trail_geofence_service.dart';

/// Utility functions for working with geofences
class GeofenceUtils {
  
  /// Generate geofences from a list of waypoints
  static List<TrailGeofence> generateGeofencesFromWaypoints(
    List<Waypoint> waypoints, {
    double defaultRadius = 20.0,
    GeofenceType defaultType = GeofenceType.waypoint,
  }) {
    final List<TrailGeofence> geofences = [];
    
    for (int i = 0; i < waypoints.length; i++) {
      final waypoint = waypoints[i];
      final isFirst = i == 0;
      final isLast = i == waypoints.length - 1;
      
      GeofenceType type = defaultType;
      double radius = defaultRadius;
      
      // Determine type based on position
      if (isFirst) {
        type = GeofenceType.trailStart;
        radius = 20.0; // Larger radius for start/end points
      } else if (isLast) {
        type = GeofenceType.trailEnd;
        radius = 20.0;
      }
      
      final geofence = TrailGeofence(
        id: 'waypoint_$i',
        name: waypoint.name.isNotEmpty ? waypoint.name : 'Waypoint ${i + 1}',
        center: LatLng(waypoint.lat, waypoint.lon),
        radius: radius,
        description: waypoint.description.isNotEmpty ? waypoint.description : 'Trail waypoint ${i + 1}',
        type: type,
      );
      
      geofences.add(geofence);
    }
    
    return geofences;
  }
  
  /// Generate geofences at regular intervals along a trail
  static List<TrailGeofence> generateGeofencesAlongTrail(
    List<LatLng> trailPoints, {
    double intervalDistance = 30.0, // meters
    double radius = 20.0,
    GeofenceType type = GeofenceType.checkpoint,
  }) {
    if (trailPoints.length < 2) return [];
    
    final List<TrailGeofence> geofences = [];
    double currentDistance = 0.0;
    int checkpointCount = 1;
    
    // Add start point
    geofences.add(TrailGeofence(
      id: 'trail_start',
      name: 'Trail Start', 
      center: trailPoints.first,
      radius: 20.0,
      description: 'Beginning of the trail',
      type: GeofenceType.trailStart,
    ));
    
    for (int i = 1; i < trailPoints.length; i++) {
      final previousPoint = trailPoints[i - 1];
      final currentPoint = trailPoints[i];
      
      final segmentDistance = _calculateDistance(previousPoint, currentPoint);
      currentDistance += segmentDistance;
      
      // Check if we should add a checkpoint
      if (currentDistance >= intervalDistance) {
        geofences.add(TrailGeofence(
          id: 'checkpoint_$checkpointCount',
          name: 'Checkpoint $checkpointCount',
          center: currentPoint,
          radius: radius,
          description: 'Trail checkpoint $checkpointCount',
          type: type,
        ));
        
        currentDistance = 0.0;
        checkpointCount++;
      }
    }
    
    // Add end point
    geofences.add(TrailGeofence(
      id: 'trail_end',
      name: 'Trail End',
      center: trailPoints.last,
      radius: 20.0,
      description: 'End of the trail',
      type: GeofenceType.trailEnd,
    ));
    
    return geofences;
  }
  
  /// Calculate distance between two LatLng points using Haversine formula
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double lat1Rad = point1.latitude * (pi / 180);
    final double lat2Rad = point2.latitude * (pi / 180);
    final double deltaLat = (point2.latitude - point1.latitude) * (pi / 180);
    final double deltaLng = (point2.longitude - point1.longitude) * (pi / 180);

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
  
  /// Create geofences for points of interest
  static List<TrailGeofence> createPointsOfInterest(
    List<Map<String, dynamic>> poisData,
  ) {
    final List<TrailGeofence> geofences = [];
    
    for (int i = 0; i < poisData.length; i++) {
      final poi = poisData[i];
      
      geofences.add(TrailGeofence(
        id: poi['id'] ?? 'poi_$i',
        name: poi['name'] ?? 'Point of Interest ${i + 1}',
        center: LatLng(poi['latitude'], poi['longitude']),
        radius: poi['radius']?.toDouble() ?? 20.0,
        description: poi['description'] ?? '',
        type: _parseGeofenceType(poi['type']),
      ));
    }
    
    return geofences;
  }
  
  /// Parse string to GeofenceType enum
  static GeofenceType _parseGeofenceType(String? typeString) {
    if (typeString == null) return GeofenceType.pointOfInterest;
    
    switch (typeString.toLowerCase()) {
      case 'waypoint':
        return GeofenceType.waypoint;
      case 'trailstart':
      case 'trail_start':
        return GeofenceType.trailStart;
      case 'trailend':
      case 'trail_end':
        return GeofenceType.trailEnd;
      case 'checkpoint':
        return GeofenceType.checkpoint;
      case 'dangerzone':
      case 'danger_zone':
        return GeofenceType.dangerZone;
      case 'restarea':
      case 'rest_area':
        return GeofenceType.restArea;
      default:
        return GeofenceType.pointOfInterest;
    }
  }
  
  /// Get appropriate notification message for geofence event
  static String getNotificationMessage(GeofenceEvent event) {
    final geofence = event.geofence;
    final isEntering = event.eventType == GeofenceEventType.enter;
    
    switch (geofence.type) {
      case GeofenceType.trailStart:
        return isEntering 
            ? 'Welcome to ${geofence.name}! Your hike begins here.'
            : 'You have left the trail starting area.';
            
      case GeofenceType.trailEnd:
        return isEntering
            ? 'Congratulations! You have reached ${geofence.name}!'
            : 'You have left the trail ending area.';
            
      case GeofenceType.waypoint:
        return isEntering
            ? 'Reached waypoint: ${geofence.name}'
            : 'Left waypoint: ${geofence.name}';
            
      case GeofenceType.checkpoint:
        return isEntering
            ? 'Checkpoint reached: ${geofence.name}'
            : 'Left checkpoint: ${geofence.name}';
            
      case GeofenceType.restArea:
        return isEntering
            ? 'Rest area available: ${geofence.name}'
            : 'Left rest area: ${geofence.name}';
            
      case GeofenceType.dangerZone:
        return isEntering
            ? 'WARNING: Entering danger zone - ${geofence.name}'
            : 'Left danger zone: ${geofence.name}';
            
      case GeofenceType.pointOfInterest:
        return isEntering
            ? 'Point of interest: ${geofence.name}'
            : 'Left point of interest: ${geofence.name}';
            
      case GeofenceType.trailArea:
        return isEntering
            ? 'Entered trail area: ${geofence.name}'
            : 'Left trail area: ${geofence.name}';
            
      case GeofenceType.corridor:
        // Corridor geofences are for silent tracking - no notifications
        return '';
    }
  }
}