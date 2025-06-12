/// an abstract class which represents a route
/// a route must have a name and a list of waypoints which link to make the route
class TrailRoute {
  final String name;
  final String routeFile;
  final String location;
  final Duration timeToComplete;
  final double distance;
  final String difficulty;
  final String description;
  final List<String> images;
  final List<String> waypoints;

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
