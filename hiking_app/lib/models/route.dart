/// an abstract class which represents a route
/// a route must have a name and a list of waypoints which link to make the route
abstract class Route {
  final String name;
  final String routeFile;

  Route({
    required this.name,
    required this.routeFile,
  });

  void printSummary(); //abstract method
}