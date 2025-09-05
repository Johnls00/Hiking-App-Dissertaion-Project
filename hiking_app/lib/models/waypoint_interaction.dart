/// Represents a user interaction with a waypoint on a trail.
///
/// Stores metadata such as timestamp, notes, photos, and coordinates.
class WaypointInteraction {
  /// Display name of the waypoint.
  final String waypointName;

  /// Unique ID of the waypoint.
  final String waypointId;

  /// When the interaction occurred.
  final DateTime timestamp;

  /// User-provided notes about the waypoint.
  final String userNotes;

  /// Paths or URLs of photos taken at the waypoint.
  final List<String> photosPaths;

  /// Latitude of the waypoint location.
  final double lat;

  /// Longitude of the waypoint location.
  final double lon;

  /// Creates a [WaypointInteraction].
  const WaypointInteraction({
    required this.waypointName,
    required this.waypointId,
    required this.timestamp,
    required this.userNotes,
    required this.photosPaths,
    required this.lat,
    required this.lon,
  });

  /// Converts this interaction to JSON.
  Map<String, dynamic> toJson() {
    return {
      'waypoint_name': waypointName,
      'waypoint_id': waypointId,
      'timestamp': timestamp.toIso8601String(),
      'user_notes': userNotes,
      'photos_paths': photosPaths,
      'lat': lat,
      'lon': lon,
    };
  }

  /// Creates a [WaypointInteraction] from JSON.
  factory WaypointInteraction.fromJson(Map<String, dynamic> json) {
    return WaypointInteraction(
      waypointName: json['waypoint_name'] ?? '',
      waypointId: json['waypoint_id'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      userNotes: json['user_notes'] ?? '',
      photosPaths: List<String>.from(json['photos_paths'] ?? []),
      lat: (json['lat'] ?? 0.0).toDouble(),
      lon: (json['lon'] ?? 0.0).toDouble(),
    );
  }

  /// Returns a copy with some fields replaced.
  WaypointInteraction copyWith({
    String? waypointName,
    String? waypointId,
    DateTime? timestamp,
    String? userNotes,
    List<String>? photosPaths,
    double? lat,
    double? lon,
  }) {
    return WaypointInteraction(
      waypointName: waypointName ?? this.waypointName,
      waypointId: waypointId ?? this.waypointId,
      timestamp: timestamp ?? this.timestamp,
      userNotes: userNotes ?? this.userNotes,
      photosPaths: photosPaths ?? this.photosPaths,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }

  @override
  String toString() {
    return 'WaypointInteraction(waypointName: $waypointName, '
        'id: $waypointId, timestamp: $timestamp, notes: $userNotes, '
        'photos: ${photosPaths.length}, lat: $lat, lon: $lon)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointInteraction &&
          waypointId == other.waypointId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => waypointId.hashCode ^ timestamp.hashCode;
}
