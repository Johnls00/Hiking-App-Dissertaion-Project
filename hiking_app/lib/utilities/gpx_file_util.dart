import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gpx/gpx.dart';
import 'package:geolocator/geolocator.dart' hide Position;
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
      double? distanceFromStart = calculateDistanceFromStart(gpxFile, wpt);
      String? waypointName = wpt.name;
      String? description = wpt.desc;

      if (lon != null &&
          lat != null &&
          ele != null &&
          waypointName != null &&
          description != null) {
        mappedWaypoints.add(
          Waypoint(
            name: waypointName,
            description: description,
            distanceFromStart: distanceFromStart,
            lat: lat,
            lon: lon,
            ele: ele,
          ),
        );
      }
    }

    return mappedWaypoints;
  }

  // method for mapping track points from gpx file using Position from mapbox_maps_flutter
  static List<Point> mapTrackpoints(Gpx gpxFile) {
    List<Point> mappedTrackpoints = [];

    for (var track in gpxFile.trks) {
      for (var trackseg in track.trksegs) {
        for (var trackpoint in trackseg.trkpts) {
          double? lon = trackpoint.lon;
          double? lat = trackpoint.lat;

          if (lon != null && lat != null) {
            mappedTrackpoints.add(Point(coordinates: Position(lon, lat)));
          }
        }
      }
    }
    return mappedTrackpoints;
  }

  // method to calculate the total distance of a trail in meters
  static double calculateTotalDistance(Gpx gpxFile) {
    final points = gpxFile.trks
        .expand((trk) => trk.trksegs)
        .expand((seg) => seg.trkpts)
        .toList();

    double totalDistance = 0.0;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final flatDistance = Geolocator.distanceBetween(
        p1.lat!,
        p1.lon!,
        p2.lat!,
        p2.lon!,
      );
      final elevationDiff = (p2.ele! - p1.ele!);
      final distance = sqrt(pow(flatDistance, 2) + pow(elevationDiff, 2));

      totalDistance += distance;
    }

    return totalDistance; // in meters
  }

  // a method to calculate the estimated time to complete trail
  static Duration calculateWalkingDuration(
    double distanceMeters,
    double speedKmPerHour,
  ) {
    double speedMetersPerSecond = (speedKmPerHour * 1000) / 3600;
    double timeInSeconds = distanceMeters / speedMetersPerSecond;
    return Duration(seconds: timeInSeconds.round());
  }

  // ((trailRoute.distance) / (5.1 * 1000) * 60.toStringAsFixed(2),

  // a method to caculate the distance of a waypoint from the start of a trail
  static double calculateDistanceFromStart(Gpx gpxFile, point) {
    double pointDistance = 0.0;

    final points = gpxFile.trks
        .expand((trk) => trk.trksegs)
        .expand((seg) => seg.trkpts)
        .toList();

    for (int i = 0; i < points.length - 1; i++) {
      double segmentDistance = Geolocator.distanceBetween(
        points[i].lat!,
        points[i].lon!,
        points[i + 1].lat!,
        points[i + 1].lon!,
      );

      pointDistance += segmentDistance;

      // Check if waypoint is closest to this segment
      double distToCurrent = Geolocator.distanceBetween(
        points[i].lat!,
        points[i].lon!,
        point.lat!,
        point.lon!,
      );

      if (distToCurrent < 10) {
        // 10 meters threshold or your own logic
        return pointDistance;
      }
    }
    return pointDistance;
  }

  // a method which calculates the elevation gain of a trail
  static double calculateElevationGain(Gpx gpxFile) {
  final points = gpxFile.trks
      .expand((trk) => trk.trksegs)
      .expand((seg) => seg.trkpts)
      .toList();

  double elevationGain = 0.0;

  for (int i = 0; i < points.length - 1; i++) {
    final currentEle = points[i].ele;
    final nextEle = points[i + 1].ele;

    if (currentEle != null && nextEle != null) {
      double diff = nextEle - currentEle;
      if (diff > 0) {
        elevationGain += diff;
      }
    }
  }

  return elevationGain; // in meters
}
}
