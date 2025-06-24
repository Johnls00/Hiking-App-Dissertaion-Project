
import 'package:hiking_app/models/waypoint.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// an abstract class which represents a route
/// a route must have a name and a list of waypoints which link to make the route
class TrailRoute {
  String name;
  String location;
  Duration timeToComplete;
  double distance;
  double elevation = 0.00;
  String difficulty;
  String description;
  List<String> images;
  List<Waypoint> waypoints;
  List<Point> trackpoints;

  TrailRoute(
    this.name,
    this.location,
    this.timeToComplete,
    this.distance,
    this.difficulty,
    this.description,
    this.images,
    this.waypoints,
    this.trackpoints,
  );

}
