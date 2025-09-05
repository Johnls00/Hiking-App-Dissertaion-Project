import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Represents a geofenced area around a hiking trail trackpoint, point of interest or other area.
///
/// A [TrailGeofence] is defined by a unique [id], a [center] coordinate, and a [radius] in meters. The [type] determines the context
/// (e.g., waypoint, checkpoint, trail start).
class TrailGeofence {
  /// Unique identifier for this geofence.
  final String id;

  /// Display name of the geofence (e.g., "Summit", "Waterfall").
  final String name;

  /// The central location (latitude/longitude) of the geofence.
  final LatLng center;

  /// Radius of the geofence in meters.
  final double radius;

  /// Optional description of the geofence (e.g., notes for hikers).
  final String description;

  /// The type of geofence (see [GeofenceType]).
  final GeofenceType type;
  
  /// Creates a new [TrailGeofence].
  const TrailGeofence({
    required this.id,
    required this.name,
    required this.center,
    required this.radius,
    this.description = '',
    this.type = GeofenceType.waypoint,
  });

  /// Returns `true` if the given [location] is inside the geofence.
  ///
  /// Uses the haversine formula to compute the distance from [center]
  /// to [location], and checks if it is less than or equal to [radius].
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

  /// Calculates the distance in meters from [center] to the given [location].
  ///
  /// Uses the haversine formula to account for Earth’s curvature.
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

  /// Creates a [TrailGeofence] instance from a JSON map.
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

  /// Converts this [TrailGeofence] into a JSON map.
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

/// Types of geofences used in the hiking app.
enum GeofenceType {
  /// A waypoint marker (default type).
  waypoint,
  /// A point of interest (e.g., scenic view, waterfall).
  pointOfInterest,
  /// The starting point of a trail.
  trailStart,
  /// The ending point of a trail.
  trailEnd,
  /// A checkpoint or milestone along the trail.
  checkpoint,
  /// A dangerous area hikers should be aware of.
  dangerZone,
  /// A designated rest area.
  restArea,
  /// Large buffer around the entire trail.
  /// Useful for detecting entry/exit to the overall trail area.
  trailArea,
  /// Corridor segments along the trail path.
  /// Useful for precise trail-following detection.
  corridor,
}