class User {
  final String id;
  final String name;
  final String email;
  final String? profileImagePath;
  final DateTime joinDate;
  final List<String> favoriteTrailIds;
  final List<String> recordedTrailIds;
  final UserStats stats;

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

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profileImagePath,
    DateTime? joinDate,
    List<String>? favoriteTrailIds,
    UserStats? stats,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      joinDate: joinDate ?? this.joinDate,
      favoriteTrailIds: favoriteTrailIds ?? this.favoriteTrailIds,
      stats: stats ?? this.stats,
    );
  }
}

class UserStats {
  final int totalTrailsRecorded;
  final double totalDistanceKm;
  final Duration totalTimeHiking;
  final int totalElevationGainM;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastHikeDate;

  UserStats({
    this.totalTrailsRecorded = 0,
    this.totalDistanceKm = 0.0,
    this.totalTimeHiking = Duration.zero,
    this.totalElevationGainM = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastHikeDate,
  });

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

  String get formattedTotalTime {
    final hours = totalTimeHiking.inHours;
    final minutes = totalTimeHiking.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

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
