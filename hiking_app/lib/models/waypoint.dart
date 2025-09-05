// a class that represents a waypoint on a route

/// A class that represents a waypoint on a hiking route.
///
/// Contains information about the waypoint's name, description,
/// distance from the start of the route, image, and geographic coordinates.
class Waypoint {
  /// The name of the waypoint.
  final String name;

  /// A description of the waypoint.
  final String description; 

  /// The distance of the waypoint from the start of the route, in kilometers.
  final double distanceFromStart;

  /// A URL or path to an image representing the waypoint.
  final String image;

  /// The latitude coordinate of the waypoint.
  final double lat;

  /// The longitude coordinate of the waypoint.
  final double lon;

  /// The elevation of the waypoint, in meters.
  final double ele;

  /// Creates a new [Waypoint] instance.
  ///
  /// The [name], [distanceFromStart], [lat], [lon], and [ele] parameters are required.
  /// The [description] and [image] parameters are optional; if not provided,
  /// they default to 'No description provided' and an empty string respectively.
  Waypoint({
    required this.name,
    String? description,
    String? image,
    required this.distanceFromStart,
    required this.lat,
    required this.lon,
    required this.ele,
  }) : description = description ?? 'No description provided',
       image = image ?? '';

  /// Returns the name of the waypoint.
  ///
  /// Note: This method is redundant since [name] is publicly accessible.
  String returnName(){
    return name;
  }

  /// Returns the latitude coordinate of the waypoint.
  ///
  /// Note: This method is redundant since [lat] is publicly accessible.
  double returnLat() {
    return lat;
  }

  /// Returns the longitude coordinate of the waypoint.
  ///
  /// Note: This method is redundant since [lon] is publicly accessible.
  double returnLon() {
    return lon;
  }

  /// Returns the elevation of the waypoint.
  ///
  /// Note: This method is redundant since [ele] is publicly accessible.
  double returnEle() {
    return ele;
  }
  
  /// Returns a string representation of the waypoint's coordinates in the format 'lat,lon,ele'.
  String returnCoordinates() {
    return '$lat,$lon,$ele';
  }
}