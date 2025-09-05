import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:hiking_app/models/user.dart';
import 'package:hiking_app/utilities/saved_trails_manager.dart';

class UserProfileManager {
  static const String _userProfileFileName = 'user_profile.json';

  /// Get user profile file path
  static Future<File> get _userProfileFile async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = p.join(directory.path, _userProfileFileName);
    debugPrint('User profile file path: $filePath');
    return File(filePath);
  }

  /// Load user profile
  static Future<User?> loadUserProfile() async {
    try {
      final file = await _userProfileFile;
      debugPrint('Checking user profile file: ${file.path}');
      
      if (await file.exists()) {
        debugPrint('User profile file exists, reading contents');
        final contents = await file.readAsString();
        debugPrint('File contents length: ${contents.length}');
        
        final json = jsonDecode(contents) as Map<String, dynamic>;
        final user = User.fromJson(json);
        debugPrint('Successfully loaded user: ${user.name} with ${user.stats.totalTrailsRecorded} trails');
        return user;
      } else {
        debugPrint('User profile file does not exist');
        return null;
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      return null;
    }
  }

  /// Save user profile
  static Future<void> saveUserProfile(User user) async {
    try {
      final file = await _userProfileFile;
      final jsonData = jsonEncode(user.toJson());
      debugPrint('Saving user profile to: ${file.path}');
      debugPrint('User data: ${user.name}, trails: ${user.stats.totalTrailsRecorded}, distance: ${user.stats.totalDistanceKm}');
      
      await file.writeAsString(jsonData);
      debugPrint('User profile saved successfully');
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }
  }

  /// Create a default user profile
  static Future<User> createDefaultUser({
    required String name,
    required String email,
  }) async {
    debugPrint('Creating default user with name: $name, email: $email');
    final user = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      joinDate: DateTime.now(),
      stats: UserStats(),
    );
    await saveUserProfile(user);
    debugPrint('Default user created and saved');
    return user;
  }

  /// Update user stats with new trail data
  static Future<User?> updateUserStatsWithNewTrail(SavedTrail trail) async {
    try {
      final user = await loadUserProfile();
      if (user == null) return null;

      final updatedStats = user.stats.copyWith(
        totalTrailsRecorded: user.stats.totalTrailsRecorded + 1,
        totalDistanceKm: user.stats.totalDistanceKm + trail.distanceKm,
        totalTimeHiking: Duration(
          seconds: user.stats.totalTimeHiking.inSeconds + trail.durationSeconds,
        ),
        lastHikeDate: trail.createdAt,
        currentStreak: _calculateCurrentStreak(user.stats.lastHikeDate, trail.createdAt, user.stats.currentStreak),
      );

      final updatedUser = user.copyWith(stats: updatedStats);
      await saveUserProfile(updatedUser);
      return updatedUser;
    } catch (e) {
      debugPrint('Error updating user stats: $e');
      return null;
    }
  }

  /// Calculate current hiking streak
  static int _calculateCurrentStreak(DateTime? lastHike, DateTime newHike, int currentStreak) {
    if (lastHike == null) return 1;
    
    final daysDifference = newHike.difference(lastHike).inDays;
    if (daysDifference == 1) {
      return currentStreak + 1;
    } else if (daysDifference == 0) {
      return currentStreak; // Same day, don't increment
    } else {
      return 1; // Streak broken, start new
    }
  }

  /// Add trail to favorites
  static Future<User?> addToFavorites(String trailId) async {
    try {
      final user = await loadUserProfile();
      if (user == null) return null;

      if (!user.favoriteTrailIds.contains(trailId)) {
        final updatedUser = user.copyWith(
          favoriteTrailIds: [...user.favoriteTrailIds, trailId],
        );
        await saveUserProfile(updatedUser);
        return updatedUser;
      }
      return user;
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
      return null;
    }
  }

  /// Remove trail from favorites
  static Future<User?> removeFromFavorites(String trailId) async {
    try {
      final user = await loadUserProfile();
      if (user == null) return null;

      final updatedFavorites = user.favoriteTrailIds.where((id) => id != trailId).toList();
      final updatedUser = user.copyWith(favoriteTrailIds: updatedFavorites);
      await saveUserProfile(updatedUser);
      return updatedUser;
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
      return null;
    }
  }

  /// Check if trail is favorited
  static Future<bool> isTrailFavorited(String trailId) async {
    final user = await loadUserProfile();
    return user?.favoriteTrailIds.contains(trailId) ?? false;
  }

  /// Get favorite trails
  static Future<List<String>> getFavoriteTrailIds() async {
    final user = await loadUserProfile();
    return user?.favoriteTrailIds ?? [];
  }

  /// Update user profile picture
  static Future<User?> updateProfilePicture(String imagePath) async {
    try {
      final user = await loadUserProfile();
      if (user == null) return null;

      // Copy image to app directory
      final directory = await getApplicationDocumentsDirectory();
      final profileDir = Directory(p.join(directory.path, 'profile'));
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      final fileName = 'profile_picture.jpg';
      final savedImagePath = p.join(profileDir.path, fileName);
      await File(imagePath).copy(savedImagePath);

      final updatedUser = user.copyWith(profileImagePath: savedImagePath);
      await saveUserProfile(updatedUser);
      return updatedUser;
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
      return null;
    }
  }

  /// Delete user profile
  static Future<void> deleteUserProfile() async {
    try {
      final file = await _userProfileFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting user profile: $e');
    }
  }

  /// Check if user profile exists
  static Future<bool> hasUserProfile() async {
    try {
      final file = await _userProfileFile;
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Recalculate user stats from saved trails
  static Future<User?> recalculateUserStats() async {
    try {
      final user = await loadUserProfile();
      if (user == null) return null;

      final savedTrails = await SavedTrailsManager.getSavedTrails();
      debugPrint('Recalculating stats for ${savedTrails.length} saved trails');
      
      double totalDistance = 0;
      int totalTime = 0;
      DateTime? lastHike;
      
      for (final trail in savedTrails) {
        totalDistance += trail.distanceKm;
        totalTime += trail.durationSeconds;
        if (lastHike == null || trail.createdAt.isAfter(lastHike)) {
          lastHike = trail.createdAt;
        }
      }

      final updatedStats = user.stats.copyWith(
        totalTrailsRecorded: savedTrails.length,
        totalDistanceKm: totalDistance,
        totalTimeHiking: Duration(seconds: totalTime),
        lastHikeDate: lastHike,
      );

      final updatedUser = user.copyWith(stats: updatedStats);
      debugPrint('Recalculated stats: ${savedTrails.length} trails, ${totalDistance.toStringAsFixed(2)} km');
      await saveUserProfile(updatedUser);
      return updatedUser;
    } catch (e) {
      debugPrint('Error recalculating user stats: $e');
      return null;
    }
  }

}
