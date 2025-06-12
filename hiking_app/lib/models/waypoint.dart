// a class that represents a waypoint on a route
class Waypoint {
  final String name;
  final double lat;
  final double lon;
  final double ele;

  Waypoint({
    required this.name,
    required this.lat,
    required this.lon,
    required this.ele,
  });
}