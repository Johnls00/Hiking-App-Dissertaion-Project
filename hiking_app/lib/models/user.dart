/// Represents a user of the hiking app.
///
/// A [User] contains identity information, profile details,
/// and statistics about their hiking activity.
class User {
  /// Unique identifier for the user (e.g., Firestore UID).
  final String id;

  /// Display name of the user.
  final String name;

  /// Email address of the user.
  final String email;

  /// Path or URL to the user’s profile image.
  final String? profileImagePath;

  /// Date when the user joined the app.
  final DateTime joinDate;

  /// List of trail IDs that the user has marked as favorites.
  final List<String> favoriteTrailIds;

  /// List of trail IDs that the user has recorded.
  final List<String> recordedTrailIds;

  /// Statistics about the user’s hiking activity.
  final UserStats stats;

  /// Creates a [User] object.
  User({
    required this.id,
    required this.name,
    required this.email,
    this.profileImagePath,
    required this.joinDate,
    this.favoriteTrailIds = const [],
    this.recordedTrailIds = const [],
    required this.stats,
  });

  /// Creates a [User] from a JSON map.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImagePath: json['profile_image_path'],
      joinDate: DateTime.parse(json['join_date']),
      favoriteTrailIds: List<String>.from(json['favorite_trail_ids'] ?? []),
      recordedTrailIds: List<String>.from(json['recorded_trail_ids'] ?? []),
      stats: UserStats.fromJson(json['stats'] ?? {}),
    );
  }

  /// Converts this [User] into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profile_image_path': profileImagePath,
      'join_date': joinDate.toIso8601String(),
      'favorite_trail_ids': favoriteTrailIds,
      'recorded_trail_ids': recordedTrailIds,
      'stats': stats.toJson(),
    };
  }

  /// Returns a copy of this [User] with updated fields.
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImagePath,
    DateTime? joinDate,
    List<String>? favoriteTrailIds,
    List<String>? recordedTrailIds,
    UserStats? stats,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      joinDate: joinDate ?? this.joinDate,
      favoriteTrailIds: favoriteTrailIds ?? this.favoriteTrailIds,
      recordedTrailIds: recordedTrailIds ?? this.recordedTrailIds,
      stats: stats ?? this.stats,
    );
  }
}

/// Stores aggregated statistics about a user’s hiking activity.
///
/// Includes metrics such as total distance, elevation gain, and streaks.
class UserStats {
  /// Number of trails recorded by the user.
  final int totalTrailsRecorded;

  /// Total hiking distance in kilometers.
  final double totalDistanceKm;

  /// Total hiking time.
  final Duration totalTimeHiking;

  /// Total elevation gain in meters.
  final int totalElevationGainM;

  /// Current streak of consecutive days with hikes.
  final int currentStreak;

  /// Longest streak of consecutive days with hikes.
  final int longestStreak;

  /// The date of the user’s most recent hike.
  final DateTime? lastHikeDate;

  /// Creates a [UserStats] object with optional defaults.
  UserStats({
    this.totalTrailsRecorded = 0,
    this.totalDistanceKm = 0.0,
    this.totalTimeHiking = Duration.zero,
    this.totalElevationGainM = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastHikeDate,
  });

  /// Creates a [UserStats] object from a JSON map.
  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalTrailsRecorded: json['total_trails_recorded'] ?? 0,
      totalDistanceKm: (json['total_distance_km'] ?? 0.0).toDouble(),
      totalTimeHiking: Duration(seconds: json['total_time_hiking_seconds'] ?? 0),
      totalElevationGainM: json['total_elevation_gain_m'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      lastHikeDate: json['last_hike_date'] != null
          ? DateTime.parse(json['last_hike_date'])
          : null,
    );
  }

  /// Converts this [UserStats] into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'total_trails_recorded': totalTrailsRecorded,
      'total_distance_km': totalDistanceKm,
      'total_time_hiking_seconds': totalTimeHiking.inSeconds,
      'total_elevation_gain_m': totalElevationGainM,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_hike_date': lastHikeDate?.toIso8601String(),
    };
  }

  /// Returns the total hiking time as a formatted string (e.g., "5h 32m").
  String get formattedTotalTime {
    final hours = totalTimeHiking.inHours;
    final minutes = totalTimeHiking.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  /// Returns a copy of this [UserStats] with updated fields.
  UserStats copyWith({
    int? totalTrailsRecorded,
    double? totalDistanceKm,
    Duration? totalTimeHiking,
    int? totalElevationGainM,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastHikeDate,
  }) {
    return UserStats(
      totalTrailsRecorded: totalTrailsRecorded ?? this.totalTrailsRecorded,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalTimeHiking: totalTimeHiking ?? this.totalTimeHiking,
      totalElevationGainM: totalElevationGainM ?? this.totalElevationGainM,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastHikeDate: lastHikeDate ?? this.lastHikeDate,
    );
  }
}