import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:hiking_app/models/waypoint_interaction.dart';

class WaypointInteractionService {
  static const String _interactionsFileName = 'interactions.json';

  /// Save a waypoint interaction to local storage
  static Future<void> saveWaypointInteraction(
    WaypointInteraction interaction, {
    String? trailName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final interactionsDir = Directory(p.join(
        directory.path, 
        'trail_interactions',
        trailName ?? 'current_trail'
      ));
      
      await interactionsDir.create(recursive: true);
      
      final interactionsFile = File(p.join(interactionsDir.path, _interactionsFileName));
      
      // Load existing interactions
      List<Map<String, dynamic>> interactions = [];
      if (await interactionsFile.exists()) {
        final existingContent = await interactionsFile.readAsString();
        if (existingContent.isNotEmpty) {
          final existingData = jsonDecode(existingContent);
          if (existingData is List) {
            interactions = List<Map<String, dynamic>>.from(existingData);
          }
        }
      }
      
      // Add new interaction
      interactions.add(interaction.toJson());
      
      // Save updated interactions
      await interactionsFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(interactions),
      );
      
      print('✅ Waypoint interaction saved successfully');
    } catch (e) {
      print('❌ Error saving waypoint interaction: $e');
      rethrow;
    }
  }

  /// Load all waypoint interactions for a trail
  static Future<List<WaypointInteraction>> loadWaypointInteractions({
    String? trailName,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final interactionsDir = Directory(p.join(
        directory.path, 
        'trail_interactions',
        trailName ?? 'current_trail'
      ));
      
      final interactionsFile = File(p.join(interactionsDir.path, _interactionsFileName));
      
      if (!await interactionsFile.exists()) {
        return [];
      }
      
      final content = await interactionsFile.readAsString();
      if (content.isEmpty) {
        return [];
      }
      
      final data = jsonDecode(content);
      if (data is! List) {
        return [];
      }
      
      return data
          .map((json) => WaypointInteraction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error loading waypoint interactions: $e');
      return [];
    }
  }

  /// Get interaction for a specific waypoint
  static Future<WaypointInteraction?> getWaypointInteraction(
    String waypointId, {
    String? trailName,
  }) async {
    final interactions = await loadWaypointInteractions(trailName: trailName);
    
    try {
      return interactions.firstWhere(
        (interaction) => interaction.waypointId == waypointId,
      );
    } catch (e) {
      return null; // No interaction found
    }
  }

  /// Check if a waypoint has been interacted with
  static Future<bool> hasWaypointInteraction(
    String waypointId, {
    String? trailName,
  }) async {
    final interaction = await getWaypointInteraction(waypointId, trailName: trailName);
    return interaction != null;
  }

  /// Delete a waypoint interaction
  static Future<void> deleteWaypointInteraction(
    String waypointId, {
    String? trailName,
  }) async {
    try {
      final interactions = await loadWaypointInteractions(trailName: trailName);
      
      // Remove the interaction
      interactions.removeWhere((interaction) => interaction.waypointId == waypointId);
      
      // Save updated list
      final directory = await getApplicationDocumentsDirectory();
      final interactionsDir = Directory(p.join(
        directory.path, 
        'trail_interactions',
        trailName ?? 'current_trail'
      ));
      
      final interactionsFile = File(p.join(interactionsDir.path, _interactionsFileName));
      
      await interactionsFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(
          interactions.map((i) => i.toJson()).toList(),
        ),
      );
      
      print('✅ Waypoint interaction deleted successfully');
    } catch (e) {
      print('❌ Error deleting waypoint interaction: $e');
      rethrow;
    }
  }

  /// Clear all waypoint interactions for a trail
  static Future<void> clearTrailInteractions({String? trailName}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final interactionsDir = Directory(p.join(
        directory.path, 
        'trail_interactions',
        trailName ?? 'current_trail'
      ));
      
      if (await interactionsDir.exists()) {
        await interactionsDir.delete(recursive: true);
      }
      
      print('✅ Trail interactions cleared successfully');
    } catch (e) {
      print('❌ Error clearing trail interactions: $e');
      rethrow;
    }
  }

  /// Get statistics about waypoint interactions
  static Future<Map<String, dynamic>> getInteractionStats({String? trailName}) async {
    final interactions = await loadWaypointInteractions(trailName: trailName);
    
    int totalPhotos = 0;
    int interactionsWithNotes = 0;
    int interactionsWithPhotos = 0;
    
    for (final interaction in interactions) {
      totalPhotos += interaction.photosPaths.length;
      if (interaction.userNotes.isNotEmpty) {
        interactionsWithNotes++;
      }
      if (interaction.photosPaths.isNotEmpty) {
        interactionsWithPhotos++;
      }
    }
    
    return {
      'total_interactions': interactions.length,
      'total_photos': totalPhotos,
      'interactions_with_notes': interactionsWithNotes,
      'interactions_with_photos': interactionsWithPhotos,
    };
  }
}
