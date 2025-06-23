// a class that represents a waypoint on a route
class Waypoint {
  final String name;
  // implement later
  final String waypointDescription = "description of the waypoint blah blah"; 
  final double distanceFromStart = 0.00;
  final String image = "";
  final double lat;
  final double lon;
  final double ele;

  Waypoint({
    required this.name,
    required this.lat,
    required this.lon,
    required this.ele,
  });

  

  String returnName(){
    return name;
  }

  double returnLat() {
    return lat;
  }

   double returnLon() {
    return lon;
  }

   double returnEle() {
    return ele;
  }
  
  String returnCoordinates() {
    return '$lat,$lon,$ele';
  }
}