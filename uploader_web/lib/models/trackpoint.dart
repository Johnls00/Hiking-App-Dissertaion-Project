class Trackpoint {
  final double lat;
  final double lon;
  final double ele;

  Trackpoint({
    required this.lat,
    required this.lon,
    required this.ele,
  });
  
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