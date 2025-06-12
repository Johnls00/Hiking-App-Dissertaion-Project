import 'package:flutter/services.dart' show rootBundle;
import 'package:gpx/gpx.dart';
import 'package:hiking_app/models/waypoint.dart';

readGpxFile(String filePath) async {
  final xmlString = await rootBundle.loadString(filePath);
  final gpxFile = GpxReader().fromString(xmlString);

  return gpxFile;
}

// method which maps the waypoints to a waypoint object and returns them as a list
List<Waypoint> mapWaypoints(final gpxFile) {
  final List<Waypoint> mappedWaypoints = [];

  for (var wpt in gpxFile.wpts) {
    double lon = wpt.lon;
    double lat = wpt.lat;
    double ele = wpt.ele;
    String waypointName = wpt.name;
    // add the waypoints to the list of waypoints to be updated in the route class
    mappedWaypoints.add(Waypoint(name: waypointName, lat: lat, lon: lon, ele: ele));
  }

  return mappedWaypoints;
}

