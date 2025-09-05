import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:gpx/gpx.dart';
import 'package:collection/collection.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:hiking_app/models/trackpoint.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:hiking_app/models/waypoint.dart';
import 'package:hiking_app/models/trail.dart'; 


class GpxFileUtil {
  // ====== IO ======
  static Future<Gpx> readGpxAsset(String assetPath) async {
    final xml = await rootBundle.loadString(assetPath);
    return GpxReader().fromString(xml);
  }

  // Keep backward compatibility
  static Future<Gpx> readGpxFile(String assetPath) async {
    return readGpxAsset(assetPath);
  }


    /// Build a GPX XML string from a list of recorded Trackpoints.
  ///
  /// [name] becomes the GPX track name and [creator] is written in the GPX header.
static String gpxFromTrackpoints(
  List<Trackpoint> points, {
  String name = 'Recorded Trail',
  String creator = 'Hiking_App',
  String description = 'Trail recorded by Hiking_App',
}) {
  final gpx = Gpx()
    ..creator = creator
    ..version = '1.1'
    ..metadata = Metadata(
      name: name,
      desc: description,
      time: DateTime.now().toUtc(),
    );

  final trk = Trk()..name = name;

  // Build the segment with proper Wpt list
  final seg = Trkseg()
    ..trkpts = points.map((tp) {
      final w = Wpt()
        ..lat = tp.lat
        ..lon = tp.lon;
      w.ele = tp.ele;
      return w;
    }).toList();

  trk.trksegs = [seg];
  gpx.trks = [trk];

  return GpxWriter().asString(gpx, pretty: true);
}

  /// Save a GPX file to [filePath] from a list of Trackpoints.
  /// Returns the written [File]. The path must be writable on the platform
  /// (e.g., use path_provider to obtain an app documents directory).
  static Future<File> saveTrackpointsAsGpx(
    List<Trackpoint> points,
    String filePath, {
    String name = 'Recorded Trail',
    String creator = 'Hiking_App',
  }) async {
    final xml = gpxFromTrackpoints(points, name: name, creator: creator);
    final file = File(filePath);
    await file.writeAsString(xml);
    return file;
  }


  static Future<Trail> buildTrailRouteFromAsset(
    String assetPath, {
    required String name,
    required String location,
    String description = '',
    List<String> images = const [],
    double walkingSpeedKmh = 5.0,
  }) async {
    final gpx = await readGpxAsset(assetPath);
    return buildTrailRouteFromGpx(
      gpx,
      name: name,
      location: location,
      description: description,
      images: images,
      walkingSpeedKmh: walkingSpeedKmh,
    );
  }

  static Trail buildTrailRouteFromGpx(
    Gpx gpx, {
    required String name,
    required String location,
    String description = '',
    List<String> images = const [],
    double walkingSpeedKmh = 5.0,
  }) {
    // Track points (use new method)
    final trackpoints = mapTrackpointsAsPoints(gpx);
    if (trackpoints.isEmpty) {
      throw StateError('GPX has no valid track points.');
    }
    final id = "unknown";
    // Stats (use new methods)
    final distance = calculateTotalDistanceMeters(gpx); // meters
    final elevationGain = calculateElevationGainMeters(gpx); // meters
    final timeToComplete = estimateTimeNaismith(distance, elevationGain, walkingSpeedKmh);

    // Waypoints (with fallback to first trkpt) + distanceFromStart snap
    final waypoints = mapWaypointsWithSnap(gpx);

    // Difficulty (simple buckets – adjust to your region)
    final difficulty = classifyDifficulty(distanceMeters: distance, elevationGainMeters: elevationGain);

    return Trail(
      id,
      name,
      location,
      timeToComplete,
      distance,          // convert meters to kilometers for TrailRoute
      elevationGain,              // meters
      difficulty,
      description,
      images,
      waypoints,
      trackpoints,
    );
  }

  // Legacy methods for backward compatibility
  static Duration calculateWalkingDuration(double distanceKm, double speedKmh) {
    final hours = distanceKm / speedKmh;
    return Duration(minutes: (hours * 60).round());
  }

  // Legacy mapWaypoints that returns List<Map<String, dynamic>>
  static List<Map<String, dynamic>> mapWaypoints(Gpx gpxFile) {
    return gpxFile.wpts.map((wpt) => {
      'name': wpt.name ?? 'Waypoint',
      'description': wpt.desc ?? '',
      'lat': wpt.lat ?? 0.0,
      'lon': wpt.lon ?? 0.0,
      'ele': wpt.ele ?? 0.0,
    }).toList();
  }

  // Legacy mapTrackpoints that returns List<Map<String, dynamic>>
  static List<Map<String, dynamic>> mapTrackpoints(Gpx gpxFile) {
    final trackpoints = <Map<String, dynamic>>[];
    for (final trk in gpxFile.trks) {
      for (final seg in trk.trksegs) {
        for (final p in seg.trkpts) {
          final lon = p.lon, lat = p.lat;
          if (lon != null && lat != null) {
            trackpoints.add({
              'lat': lat,
              'lon': lon,
              'ele': p.ele ?? 0.0,
            });
          }
        }
      }
    }
    return trackpoints;
  }

  // Legacy calculateTotalDistance that returns kilometers
  static double calculateTotalDistance(Gpx gpxFile) {
    return calculateTotalDistanceMeters(gpxFile) / 1000.0;
  }

  // Legacy calculateElevationGain 
  static double calculateElevationGain(Gpx gpxFile) {
    return calculateElevationGainMeters(gpxFile);
  }

  // ====== Mapping (New methods) ======
  static List<Point> mapTrackpointsAsPoints(Gpx gpxFile) {
    final mapped = <Point>[];
    for (final trk in gpxFile.trks) {
      for (final seg in trk.trksegs) {
        for (final p in seg.trkpts) {
          final lon = p.lon, lat = p.lat;
          if (lon != null && lat != null) {
            mapped.add(Point(coordinates: Position(lon, lat)));
          }
        }
      }
    }
    return mapped;
  }

  /// Waypoints with fallback + snap each to nearest segment to compute distanceFromStart.
  static List<Waypoint> mapWaypointsWithSnap(Gpx gpxFile) {
    final mapped = <Waypoint>[];

    // Fallback wpt if none present
    if (gpxFile.wpts.isEmpty) {
      final first = gpxFile.trks
          .expand((t) => t.trksegs)
          .expand((s) => s.trkpts)
          .firstWhereOrNull((pt) => pt.lat != null && pt.lon != null);
      if (first != null) {
        gpxFile.wpts.add(Wpt()..lat = first.lat..lon = first.lon);
      }
    }

    // Precompute cumulative distances along track (polyline measure)
    final trkPts = gpxFile.trks
        .expand((t) => t.trksegs)
        .expand((s) => s.trkpts)
        .where((p) => p.lat != null && p.lon != null)
        .toList();

    final cumDistances = _cumulativeAlongTrack(trkPts); // meters from start for each vertex

    for (final w in gpxFile.wpts) {
      final lon = w.lon, lat = w.lat;
      if (lon == null || lat == null) continue;

      final snap = _snapToTrack(lat, lon, trkPts, cumDistances);
      mapped.add(
        Waypoint(
          name: w.name ?? (mapped.isEmpty ? 'Start of trail' : 'Waypoint ${mapped.length + 1}'),
          description: w.desc ?? '',
          distanceFromStart: snap.distanceFromStartMeters,
          lat: lat,
          lon: lon,
          ele: w.ele ?? 0.0,
        ),
      );
    }
    return mapped;
  }

  // ====== Distance & Elevation (Renamed methods) ======

  /// 3D distance (planar + elevation) - returns meters.
  static double calculateTotalDistanceMeters(
  Gpx gpxFile, {
  double minMoveMeters = 0,
  double? maxJumpMeters, // e.g., 200 for noisy data; null to disable
}) {
  double total = 0.0;

  for (final trk in gpxFile.trks) {
    for (final seg in trk.trksegs) {
      final pts = seg.trkpts
          .where((p) => p.lat != null && p.lon != null)
          .toList();
      if (pts.length < 2) continue;

      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i];
        final b = pts[i + 1];

        final flat = Geolocator.distanceBetween(
          a.lat!, a.lon!, b.lat!, b.lon!,
        );

        // Skip tiny jitter
        if (flat < minMoveMeters) continue;

        // Skip huge teleports (optional)
        if (maxJumpMeters != null && flat > maxJumpMeters) continue;

        // Only add vertical component if BOTH have elevation
        final hasEle = (a.ele != null && b.ele != null);
        final eleDiff = hasEle ? (b.ele! - a.ele!).abs() : 0.0;

        total += (hasEle)
            ? sqrt(flat * flat + eleDiff * eleDiff)
            : flat;
      }
    }
  }
  return total;
}

  /// Elevation gain with a small threshold to ignore noise.
  static double calculateElevationGainMeters(Gpx gpxFile, {double thresholdMeters = 2.0}) {
    final pts = gpxFile.trks
        .expand((t) => t.trksegs)
        .expand((s) => s.trkpts)
        .where((p) => p.ele != null)
        .toList();

    var gain = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      final d = (pts[i + 1].ele! - pts[i].ele!);
      if (d > thresholdMeters) gain += d;
    }
    return gain;
  }

  // ====== Time & Difficulty ======

  /// Naismith's Rule (simple): time (hours) = distance_km / baseSpeed + ascent_m / 600.
  static Duration estimateTimeNaismith(double distanceMeters, double ascentMeters, double baseSpeedKmh) {
    final distKm = distanceMeters / 1000.0;
    final hours = (distKm / baseSpeedKmh) + (ascentMeters / 600.0);
    return Duration(minutes: (hours * 60).round());
  }

  /// Simple buckets; tune to your terrain/user base.
  static String classifyDifficulty({
    required double distanceMeters,
    required double elevationGainMeters,
  }) {
    final km = distanceMeters / 1000.0;
    if (km <= 6 && elevationGainMeters <= 200) return 'easy';
    if (km <= 12 && elevationGainMeters <= 600) return 'moderate';
    return 'hard';
  }

  // ====== Waypoint distance from start (snap to track) ======

  /// Returns distance-from-start to the nearest point on the polyline.
  static _SnapResult _snapToTrack(
    double wLat,
    double wLon,
    List<Wpt> trkPts,
    List<double> cumDistances,
  ) {
    // Track vertices
    final n = trkPts.length;
    if (n == 0) return _SnapResult(0, 0, 0);

    // Brute-force over segments, find the projection with min distance
    double bestMeters = double.infinity;
    double bestAlongMeters = 0.0;
    int bestSegIdx = 0;

    for (var i = 0; i < n - 1; i++) {
      final a = trkPts[i], b = trkPts[i + 1];
      final proj = _projectToSegment(wLat, wLon, a, b);
      final distMeters = proj.perpMeters;
      if (distMeters < bestMeters) {
        bestMeters = distMeters;
        bestAlongMeters = cumDistances[i] + proj.t * _geoDistance(a.lat!, a.lon!, b.lat!, b.lon!);
        bestSegIdx = i;
      }
    }
    return _SnapResult(bestAlongMeters, bestSegIdx, bestMeters);
  }

  /// Cumulative distance at each vertex.
  static List<double> _cumulativeAlongTrack(List<Wpt> pts) {
    final out = <double>[];
    var total = 0.0;
    out.add(0.0);
    for (var i = 0; i < pts.length - 1; i++) {
      total += _geoDistance(pts[i].lat!, pts[i].lon!, pts[i + 1].lat!, pts[i + 1].lon!);
      out.add(total);
    }
    return out;
  }

  static double _geoDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Project point W onto segment AB in geographic space (approx: use meters in local tangent).
  /// Returns fraction t in [0,1] and perpendicular distance in meters.
  static _Projection _projectToSegment(double wLat, double wLon, Wpt a, Wpt b) {
    // Convert to a local flat approximation using meters (good enough for short segments)
    // Use the first endpoint as origin.
    final ax = 0.0;
    final ay = 0.0;
    final bx = _eastMeters(a.lat!, a.lon!, b.lat!, b.lon!);
    final by = _northMeters(a.lat!, a.lon!, b.lat!, b.lon!);
    final wx = _eastMeters(a.lat!, a.lon!, wLat, wLon);
    final wy = _northMeters(a.lat!, a.lon!, wLat, wLon);

    final abx = bx - ax, aby = by - ay;
    final abLen2 = (abx * abx + aby * aby).clamp(1e-9, double.infinity);
    var t = ((wx - ax) * abx + (wy - ay) * aby) / abLen2;
    t = t.clamp(0.0, 1.0);

    final px = ax + t * abx;
    final py = ay + t * aby;

    final dx = wx - px;
    final dy = wy - py;
    final perp = sqrt(dx * dx + dy * dy);

    return _Projection(t: t, perpMeters: perp);
  }

  // Rough local ENU conversions using lat as reference.
  static double _northMeters(double lat0, double lon0, double lat1, double lon1) {
    return Geolocator.distanceBetween(lat0, lon0, lat1, lon0) * (lat1 >= lat0 ? 1 : -1);
    // north/south distance with lon fixed
  }

  static double _eastMeters(double lat0, double lon0, double lat1, double lon1) {
    return Geolocator.distanceBetween(lat0, lon0, lat0, lon1) * (lon1 >= lon0 ? 1 : -1);
    // east/west distance with lat fixed
  }
}

class _Projection {
  final double t; // 0..1 along the segment
  final double perpMeters;
  _Projection({required this.t, required this.perpMeters});
}

class _SnapResult {
  final double distanceFromStartMeters;
  final int segmentIndex;
  final double lateralMeters;
  _SnapResult(this.distanceFromStartMeters, this.segmentIndex, this.lateralMeters);
}

