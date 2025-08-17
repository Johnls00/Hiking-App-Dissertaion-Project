// a class that represents a waypoint on a route
class Waypoint {
  final String name;
  // implement later
  final String description; 
  double distanceFromStart;
  final String image = "";
  final double lat;
  final double lon;
  final double ele;

  Waypoint({
    required this.name,
    String? description,
    required this.distanceFromStart,
    required this.lat,
    required this.lon,
    required this.ele,
  }) : description = description ?? 'No description provided';

  

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