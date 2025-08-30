
class WaypointInteraction {
  final String waypointName;
  final String waypointId;
  final DateTime timestamp;
  final String userNotes;
  final List<String> photosPaths;
  final double lat;
  final double lon;

  const WaypointInteraction({
    required this.waypointName,
    required this.waypointId,
    required this.timestamp,
    required this.userNotes,
    required this.photosPaths,
    required this.lat,
    required this.lon,
  });

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

  factory WaypointInteraction.fromJson(Map<String, dynamic> json) {
    return WaypointInteraction(
      waypointName: json['waypoint_name'] ?? '',
      waypointId: json['waypoint_id'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      userNotes: json['user_notes'] ?? '',
      photosPaths: List<String>.from(json['photos_paths'] ?? []),
      lat: json['lat']?.toDouble() ?? 0.0,
      lon: json['lon']?.toDouble() ?? 0.0,
    );
  }
}
