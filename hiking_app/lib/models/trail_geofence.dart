import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Represents a geofenced area around a hiking trail waypoint or point of interest
class TrailGeofence {
  final String id;
  final String name;
  final LatLng center;
  final double radius; // in meters
  final String description;
  final GeofenceType type;
  
  const TrailGeofence({
    required this.id,
    required this.name,
    required this.center,
    required this.radius,
    this.description = '',
    this.type = GeofenceType.waypoint,
  });

  /// Check if a given location is within this geofence
  bool isLocationInside(LatLng location) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double lat1Rad = center.latitude * (pi / 180);
    final double lat2Rad = location.latitude * (pi / 180);
    final double deltaLat = (location.latitude - center.latitude) * (pi / 180);
    final double deltaLng = (location.longitude - center.longitude) * (pi / 180);

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final double distance = earthRadius * c;
    return distance <= radius;
  }

  /// Calculate distance from center to a given location
  double distanceToLocation(LatLng location) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double lat1Rad = center.latitude * (pi / 180);
    final double lat2Rad = location.latitude * (pi / 180);
    final double deltaLat = (location.latitude - center.latitude) * (pi / 180);
    final double deltaLng = (location.longitude - center.longitude) * (pi / 180);

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Create from JSON
  factory TrailGeofence.fromJson(Map<String, dynamic> json) {
    return TrailGeofence(
      id: json['id'],
      name: json['name'],
      center: LatLng(json['latitude'], json['longitude']),
      radius: json['radius']?.toDouble() ?? 50.0,
      description: json['description'] ?? '',
      type: GeofenceType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GeofenceType.waypoint,
      ),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': center.latitude,
      'longitude': center.longitude,
      'radius': radius,
      'description': description,
      'type': type.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrailGeofence &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Types of geofences in the hiking app
enum GeofenceType {
  waypoint,
  pointOfInterest,
  trailStart,
  trailEnd,
  checkpoint,
  dangerZone,
  restArea,
  trailArea,    // Large buffer around entire trail
  corridor,     // Corridor segments along trail path
}
