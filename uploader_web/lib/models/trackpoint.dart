/// A model representing a single GPS trackpoint with latitude, longitude,
/// and elevation values.
///
/// Useful for storing and retrieving individual points along a hiking trail
/// or route.
class Trackpoint {
  /// The latitude of the trackpoint in decimal degrees.
  final double lat;

  /// The longitude of the trackpoint in decimal degrees.
  final double lon;

  /// The elevation of the trackpoint in meters.
  final double ele;

  /// Creates a [Trackpoint] with the given latitude, longitude, and elevation.
  Trackpoint({
    required this.lat,
    required this.lon,
    required this.ele,
  });
  
  /// Returns the latitude value of this trackpoint.
  double returnLat() {
    return lat;
  }

  /// Returns the longitude value of this trackpoint.
  double returnLon() {
    return lon;
  }

  /// Returns the elevation value of this trackpoint.
  double returnEle() {
    return ele;
  }
  
  /// Returns the trackpoint's coordinates as a comma-separated string
  /// in the format `lat,lon,ele`.
  String returnCoordinates() {
    return '$lat,$lon,$ele';
  }
}