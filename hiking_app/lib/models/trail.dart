import 'package:hiking_app/models/waypoint.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// A class that represents a hiking trail or route.
///
/// A [Trail] contains metadata such as [id], [name], [location], and [difficulty],
/// as well as geospatial data in the form of [waypoints] and [trackpoints].
/// 
/// Each trail is made up of:
/// - A list of [waypoints] (important locations along the route)
/// - A list of [trackpoints] (points that define the detailed path/geometry)
class Trail {
  /// Unique identifier for the trail.
  String id;

  /// Display name of the trail.
  String name;

  /// Description of the trail (e.g., highlights, warnings, notes).
  String description;

  /// General location of the trail (e.g., "Mourne Mountains, NI").
  String location;

  /// Estimated time required to complete the trail.
  Duration timeToComplete;

  /// Total distance of the trail in kilometers.
  double distance;

  /// Total elevation gain of the trail in meters.
  double elevation;

  /// Difficulty rating (e.g., "easy", "moderate", "hard").
  String difficulty;

  /// A list of image URLs associated with the trail.
  List<String> images;

  /// Key waypoints marking significant spots along the trail.
  List<Waypoint> waypoints;

  /// Detailed trackpoints forming the path geometry of the trail.
  List<Point> trackpoints;

  /// Creates a [Trail] instance.
  Trail(
    this.id,
    this.name,
    this.location,
    this.timeToComplete,
    this.distance,
    this.elevation,
    this.difficulty,
    this.description,
    this.images,
    this.waypoints,
    this.trackpoints,
  );
}