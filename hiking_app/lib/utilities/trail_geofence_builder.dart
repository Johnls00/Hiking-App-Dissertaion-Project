import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:hiking_app/models/trail_geofence.dart';

/// Utility class for creating trail-wide geofences
class TrailGeofenceBuilder {

  /// Create multiple overlapping circular geofences along the trail
  static List<TrailGeofence> createTrailCorridorGeofences({
    required String trailId,
    required String trailName,
    required List<LatLng> trailPoints,
    required double corridorWidth, // in meters
    required double segmentDistance, // distance between geofence centers in meters
  }) {
    final List<TrailGeofence> geofences = [];
    
    if (trailPoints.length < 2) return geofences;

    // Create geofences along the trail at regular intervals
    int geofenceIndex = 0;
    
    for (int i = 0; i < trailPoints.length - 1; i++) {
      final start = trailPoints[i];
      final end = trailPoints[i + 1];
      final segmentLength = _calculateDistance(start, end);
      
      // Add geofences along this segment
      final numGeofences = (segmentLength / segmentDistance).ceil();
      
      for (int j = 0; j < numGeofences; j++) {
        final ratio = j / numGeofences;
        final point = _interpolatePoint(start, end, ratio);
        
        geofences.add(TrailGeofence(
          id: '${trailId}_corridor_${geofenceIndex++}',
          name: '$trailName Corridor ${geofenceIndex}',
          center: point,
          radius: corridorWidth,
          description: 'Trail corridor segment',
          type: GeofenceType.corridor,
        ));
      }
    }

    return geofences;
  }

  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLat = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLng = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static LatLng _interpolatePoint(LatLng start, LatLng end, double ratio) {
    final lat = start.latitude + (end.latitude - start.latitude) * ratio;
    final lng = start.longitude + (end.longitude - start.longitude) * ratio;
    return LatLng(lat, lng);
  }
}
