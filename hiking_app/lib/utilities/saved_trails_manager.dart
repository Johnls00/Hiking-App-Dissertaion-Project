import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// saved trails need to be moved into thier own model file and the logic for them should only be stored here
// saved trails will also be saved to firebase instead of local storage
class SavedTrail {
  final String id;
  final String name;
  final String description;
  final String location;
  final DateTime createdAt;
  final double distanceMeters;
  final int durationSeconds;
  final int pointsCount;
  final List<String> images;
  final String gpxPath;
  final String dirPath;

  SavedTrail({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    required this.createdAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.pointsCount,
    required this.images,
    required this.gpxPath,
    required this.dirPath,
  });

  factory SavedTrail.fromJson(Map<String, dynamic> json, String dirPath) {
    return SavedTrail(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      distanceMeters: (json['distance_meters'] ?? 0).toDouble(),
      durationSeconds: json['duration_seconds'] ?? 0,
      pointsCount: json['points_count'] ?? 0,
      images: List<String>.from(json['images'] ?? []),
      gpxPath: p.join(dirPath, '${json['name']}.gpx'),
      dirPath: dirPath,
    );
  }

  Duration get duration => Duration(seconds: durationSeconds);
  double get distanceKm => distanceMeters / 1000;

  String get formattedDuration {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  List<String> get fullImagePaths {
    return images.map((imageName) => p.join(dirPath, imageName)).toList();
  }
}

class SavedTrailsManager {
  static Future<Directory> get _savedTrailsDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory(p.join(directory.path, 'saved_trails'));
  }

  /// Get all saved trails
  static Future<List<SavedTrail>> getSavedTrails() async {
    try {
      final trailsDir = await _savedTrailsDirectory;
      
      if (!await trailsDir.exists()) {
        return [];
      }

      final savedTrails = <SavedTrail>[];
      
      await for (final entity in trailsDir.list()) {
        if (entity is Directory) {
          final metadataFile = File(p.join(entity.path, 'metadata.json'));
          
          if (await metadataFile.exists()) {
            try {
              final metadataJson = await metadataFile.readAsString();
              final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
              
              final savedTrail = SavedTrail.fromJson(metadata, entity.path);
              savedTrails.add(savedTrail);
            } catch (e) {
              debugPrint('Error reading metadata for ${entity.path}: $e');
            }
          }
        }
      }

      // Sort by creation date, newest first
      savedTrails.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return savedTrails;
    } catch (e) {
      debugPrint('Error getting saved trails: $e');
      return [];
    }
  }

  /// Delete a saved trail
  static Future<bool> deleteTrail(SavedTrail trail) async {
    try {
      final trailDir = Directory(trail.dirPath);
      if (await trailDir.exists()) {
        await trailDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting trail: $e');
      return false;
    }
  }

  /// Check if saved trails directory exists and has trails
  static Future<bool> hasSavedTrails() async {
    final trails = await getSavedTrails();
    return trails.isNotEmpty;
  }

  /// Get the total number of saved trails
  static Future<int> getTrailCount() async {
    final trails = await getSavedTrails();
    return trails.length;
  }
}
