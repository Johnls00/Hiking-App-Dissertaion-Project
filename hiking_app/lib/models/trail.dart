
import 'package:hiking_app/models/waypoint.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// a class which represents a route
/// a route must have a name and a list of waypoints which link to make the route
class Trail {
  String id;
  String name;
  String description;
  String location;
  Duration timeToComplete;
  double distance;
  double elevation;
  String difficulty;
  List<String> images;
  List<Waypoint> waypoints;
  List<Point> trackpoints;

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
