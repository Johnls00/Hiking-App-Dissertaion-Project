import 'package:hiking_app/models/waypoint.dart';

/// an abstract class which represents a route
/// a route must have a name and a list of waypoints which link to make the route
class TrailRoute {
  String name;
  String routeFile;
  String location;
  Duration timeToComplete;
  double distance;
  double elevation = 0.00;
  String difficulty;
  String description;
  List<String> images;
  List<Waypoint> waypoints;

  TrailRoute(
    this.name,
    this.routeFile,
    this.location,
    this.timeToComplete,
    this.distance,
    this.difficulty,
    this.description,
    this.images,
    this.waypoints,
  );


  void printSummary(){
    print('name: $name, location: $location, distance: $distance');
  } //abstract method
}
