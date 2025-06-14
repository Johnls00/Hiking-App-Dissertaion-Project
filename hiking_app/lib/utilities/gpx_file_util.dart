import 'package:flutter/services.dart' show rootBundle;
import 'package:gpx/gpx.dart';
import 'package:hiking_app/models/waypoint.dart';

class GpxFileUtil {

  static Future<Gpx> readGpxFile(String filePath) async {
    String xmlString = await rootBundle.loadString(filePath);
    Gpx gpxFile = GpxReader().fromString(xmlString);

    return gpxFile;
  }

  // method which maps the waypoints to a waypoint object and returns them as a list
  static List<Waypoint> mapWaypoints(Gpx gpxFile) {
    List<Waypoint> mappedWaypoints = [];

    for (var wpt in gpxFile.wpts) {
      double? lon = wpt.lon;
      double? lat = wpt.lat;
      double? ele = wpt.ele;
      String? waypointName = wpt.name;

      if (lon != null && lat != null && ele != null && waypointName != null) {
        mappedWaypoints.add(
          Waypoint(name: waypointName, lat: lat, lon: lon, ele: ele),
        );
      }
    }

    return mappedWaypoints;
  }
}
