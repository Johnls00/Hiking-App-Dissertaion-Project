import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hiking_app/models/waypoint.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:hiking_app/models/trail_geofence.dart';
import 'package:hiking_app/utilities/trail_geofence_builder.dart';

// Helper to add trail line layer
Future<void> addTrailLine(
  MapboxMap mapboxMapController,
  List<Point> trailPoints,
) async {
  try {
    final lineString = LineString(
      coordinates: trailPoints.map((p) => p.coordinates).toList(),
    );
    final feature = Feature(geometry: lineString, id: "route_line");
    final featureCollection = FeatureCollection(features: [feature]);

    await mapboxMapController.style.addSource(
      GeoJsonSource(id: "line", data: jsonEncode(featureCollection.toJson())),
    );

    await mapboxMapController.style.addLayer(
      LineLayer(
        slot: LayerSlot.MIDDLE,
        id: "line_layer_trail_overview",
        sourceId: "line",
        lineColor: Colors.red.toARGB32(),
        lineBorderColor: Colors.red.shade900.toARGB32(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineWidth: 6.0,
      ),
    );
  } catch (e, stack) {
    debugPrint("Error in addTrailLine: $e");
    debugPrintStack(stackTrace: stack);
  }
}

Future<void> addDirectionsLine(
  MapboxMap mapboxMapController,
  List<Point> trailPoints,
) async {
  try {
    final lineString = LineString(
      coordinates: trailPoints.map((p) => p.coordinates).toList(),
    );
    final feature = Feature(geometry: lineString, id: "directions_line");
    final featureCollection = FeatureCollection(features: [feature]);

    await mapboxMapController.style.addSource(
      GeoJsonSource(
        id: "directions_line_style",
        data: jsonEncode(featureCollection.toJson()),
      ),
    );

    await mapboxMapController.style.addLayer(
      LineLayer(
        slot: LayerSlot.MIDDLE,
        id: "line_layer_directions",
        sourceId: "line",
        lineColor: Colors.red.toARGB32(),
        lineBorderColor: Colors.red.shade900.toARGB32(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineWidth: 6.0,
      ),
    );
  } catch (e, stack) {
    debugPrint("Error in addDirectionsLine: $e");
    debugPrintStack(stackTrace: stack);
  }
}

// a helper method to focus the camera postion to view the whole trail line or shape
Future<void> cameraBoundsFromPoints(
  MapboxMap mapboxMapController,
  List<Point> points,
) async {
  if (points.isEmpty) {
    throw Exception("No points to bound camera.");
  }

  num minLat = points.first.coordinates.lat;
  num maxLat = points.first.coordinates.lat;
  num minLon = points.first.coordinates.lng;
  num maxLon = points.first.coordinates.lng;

  for (final point in points) {
    final lat = point.coordinates.lat;
    final lon = point.coordinates.lng;
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
    if (lon < minLon) minLon = lon;
    if (lon > maxLon) maxLon = lon;
  }

  final bounds = CoordinateBounds(
    southwest: Point(coordinates: Position(minLon, minLat)),
    northeast: Point(coordinates: Position(maxLon, maxLat)),
    infiniteBounds: true,
  );

  final padding = MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50);
  final bearing = 0.0; // no rotation
  final pitch = 0.0; // flat top-down view
  final maxZoom = null; // or specify a number, e.g. 15.0
  final offset = null; // or: ScreenCoordinate(x: 0, y: 0)

  final camera = await mapboxMapController.cameraForCoordinateBounds(
    bounds,
    padding,
    bearing,
    pitch,
    maxZoom,
    offset,
  );
  await safelySetCamera(mapboxMapController, camera);
}

// adds a straight line between two points on the map
Future<void> addLineBetweenPoints(
  MapboxMap mapboxMapController,
  ll.LatLng start,
  ll.LatLng end, {
  String sourceId = 'user-trail-connector-source',
  String layerId = 'user-trail-connector-layer',
  int lineColorHex = 0xFF2196F3, // blue
  double lineWidth = 4.0,
}) async {
  // Remove existing layer and source if any
  try {
    await mapboxMapController.style.removeStyleLayer(layerId);
    await mapboxMapController.style.removeStyleSource(sourceId);
  } catch (_) {
    // Safe to ignore if not found
  }

  // Define the GeoJSON LineString feature
  final geoJson = {
    "type": "Feature",
    "geometry": {
      "type": "LineString",
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
    },
  };

  final String geoJsonString = jsonEncode(geoJson);

  // Add source
  await mapboxMapController.style.addSource(
    GeoJsonSource(id: sourceId, data: geoJsonString),
  );

  // Add line layer
  await mapboxMapController.style.addLayer(
    LineLayer(
      id: layerId,
      sourceId: sourceId,
      lineColor: lineColorHex,
      lineWidth: lineWidth,
    ),
  );
}

Future<void> redrawLineToTrail(
  MapboxMap mapController,
  ll.LatLng user,
  ll.LatLng trailPoint, {
  String sourceId = 'user-to-trail-source',
  String layerId = 'user-to-trail-layer',
}) async {
  final updatedGeoJson = jsonEncode({
    "type": "Feature",
    "geometry": {
      "type": "LineString",
      "coordinates": [
        [user.longitude, user.latitude],
        [trailPoint.longitude, trailPoint.latitude],
      ],
    },
  });

  // Remove existing layer/source if needed
  try {
    await mapController.style.removeStyleLayer(layerId);
    await mapController.style.removeStyleSource(sourceId);
  } catch (e) {
    debugPrint("Layer/source not found on redraw: $e");
  }

  // Add new source
  await mapController.style.addSource(
    GeoJsonSource(id: sourceId, data: updatedGeoJson),
  );

  // Add new layer
  await mapController.style.addLayer(
    LineLayer(
      id: layerId,
      sourceId: sourceId,
      lineColor: 0xFF2196F3,
      lineWidth: 4.0,
    ),
  );
}

Future<void> drawRouteLine(
  MapboxMap map,
  List<List<double>> coordinates,
) async {
  final points = coordinates
      .map((coord) => Position(coord[0], coord[1]))
      .toList();

  final polylineManager = await map.annotations
      .createPolylineAnnotationManager();

  await polylineManager.create(
    PolylineAnnotationOptions(
      geometry: LineString(coordinates: points),
      lineColor: 0xFFFF0000, // red
      lineWidth: 5.0,
    ),
  );
}

/// Add a circular geofence visualization to the map
Future<void> addGeofenceCircle(
  MapboxMap mapboxMapController,
  TrailGeofence geofence, {
  int fillColor = 0x4000FF00, // Semi-transparent green
  int borderColor = 0xFF00FF00, // Green border
  double borderWidth = 2.0,
}) async {
  try {
    // Remove existing geofence if it exists
    await removeGeofenceCircle(mapboxMapController, geofence.id);

    // Create circle coordinates (approximation using polygon)
    final List<Position> coordinates = [];
    const int numPoints = 64; // Number of points to create smooth circle
    final double radiusInDegrees =
        geofence.radius / 111320; // Rough conversion to degrees

    for (int i = 0; i <= numPoints; i++) {
      final double angle = (i * 2 * 3.14159265359) / numPoints;
      final double lat =
          geofence.center.latitude + (radiusInDegrees * cos(angle));
      final double lng =
          geofence.center.longitude +
          (radiusInDegrees *
              sin(angle) /
              cos(geofence.center.latitude * 3.14159265359 / 180));
      coordinates.add(Position(lng, lat));
    }

    final polygon = Polygon(coordinates: [coordinates]);
    final feature = Feature(geometry: polygon, id: geofence.id);
    final featureCollection = FeatureCollection(features: [feature]);

    // Add source for the geofence
    await mapboxMapController.style.addSource(
      GeoJsonSource(
        id: 'geofence-source-${geofence.id}',
        data: jsonEncode(featureCollection.toJson()),
      ),
    );

    // Add fill layer
    await mapboxMapController.style.addLayer(
      FillLayer(
        id: 'geofence-fill-${geofence.id}',
        sourceId: 'geofence-source-${geofence.id}',
        fillColor: fillColor,
        fillOpacity: 0.3,
      ),
    );

    // Add border layer
    await mapboxMapController.style.addLayer(
      LineLayer(
        id: 'geofence-border-${geofence.id}',
        sourceId: 'geofence-source-${geofence.id}',
        lineColor: borderColor,
        lineWidth: borderWidth,
      ),
    );
  } catch (e, stack) {
    debugPrint("Error in addGeofenceCircle: $e");
    debugPrintStack(stackTrace: stack);
  }
}

/// Remove a geofence circle from the map
Future<void> removeGeofenceCircle(
  MapboxMap mapboxMapController,
  String geofenceId,
) async {
  try {
    await mapboxMapController.style.removeStyleLayer(
      'geofence-fill-$geofenceId',
    );
    await mapboxMapController.style.removeStyleLayer(
      'geofence-border-$geofenceId',
    );
    await mapboxMapController.style.removeStyleSource(
      'geofence-source-$geofenceId',
    );
  } catch (e) {
    // Safe to ignore if layers don't exist
    debugPrint("Geofence layers not found for removal: $e");
  }
}

/// Add multiple geofences to the map
Future<void> addGeofenceCircles(
  MapboxMap mapboxMapController,
  List<TrailGeofence> geofences, {
  int fillColor = 0x4000FF00,
  int borderColor = 0xFF00FF00,
  double borderWidth = 2.0,
}) async {
  for (final geofence in geofences) {
    await addGeofenceCircle(
      mapboxMapController,
      geofence,
      fillColor: fillColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
  }
}

/// Remove all geofence circles from the map
Future<void> removeAllGeofenceCircles(
  MapboxMap mapboxMapController,
  List<TrailGeofence> geofences,
) async {
  for (final geofence in geofences) {
    await removeGeofenceCircle(mapboxMapController, geofence.id);
  }
}

/// Highlight an active geofence with different colors
Future<void> highlightActiveGeofence(
  MapboxMap mapboxMapController,
  TrailGeofence geofence, {
  int fillColor = 0x40FF0000, // Semi-transparent red
  int borderColor = 0xFFFF0000, // Red border
  double borderWidth = 3.0,
}) async {
  await addGeofenceCircle(
    mapboxMapController,
    geofence,
    fillColor: fillColor,
    borderColor: borderColor,
    borderWidth: borderWidth,
  );
}

/// Add a geofence center marker
Future<void> addGeofenceCenterMarker(
  MapboxMap mapboxMapController,
  TrailGeofence geofence,
) async {
  try {
    final pointAnnotationManager = await mapboxMapController.annotations
        .createPointAnnotationManager();

    await pointAnnotationManager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            geofence.center.longitude,
            geofence.center.latitude,
          ),
        ),
        textField: geofence.name,
        textOffset: [0.0, -2.0],
        textColor: 0xFF000000,
        textSize: 12.0,
        iconImage: 'waypoint-marker', // You can customize this
        iconSize: 0.8,
      ),
    );
  } catch (e, stack) {
    debugPrint("Error in addGeofenceCenterMarker: $e");
    debugPrintStack(stackTrace: stack);
  }
}

/// Add corridor geofences along the trail
Future<void> addTrailCorridorGeofences(
  MapboxMap mapboxMapController,
  String trailId,
  String trailName,
  List<ll.LatLng> trailPoints, {
  double corridorWidth = 5.0,
  double segmentDistance = 10.0,
  int fillColor = 0x4000FF00, // Semi-transparent green
  int borderColor = 0xFF00FF00, // Green border
}) async {
  try {
    // Create corridor geofences
    final corridorGeofences = TrailGeofenceBuilder.createTrailCorridorGeofences(
      trailId: trailId,
      trailName: trailName,
      trailPoints: trailPoints,
      corridorWidth: corridorWidth,
      segmentDistance: segmentDistance,
    );

    // Add each corridor geofence to the map
    for (final geofence in corridorGeofences) {
      await addGeofenceCircle(
        mapboxMapController,
        geofence,
        fillColor: fillColor,
        borderColor: borderColor,
        borderWidth: 1.0,
      );
    }

    debugPrint('✅ Added ${corridorGeofences.length} corridor geofences to map');
  } catch (e) {
    debugPrint("❌ Error adding corridor geofences: $e");
  }
}

/// Creates circle annotations for a list of waypoints and returns the manager.
Future<CircleAnnotationManager> addWaypointAnnotations(
  MapboxMap map,
  List<Waypoint> waypoints, {
  Color color = Colors.blue,
  double opacity = 1.0,
  double radius = 10,
}) async {
  final manager = await map.annotations.createCircleAnnotationManager();

  for (final w in waypoints) {
    final opts = CircleAnnotationOptions(
      geometry: Point(
        coordinates: Position(
          w.lon.toDouble(), // Mapbox Position expects (lng, lat)
          w.lat.toDouble(),
        ),
      ),
      circleColor: color.toARGB32(),
      circleOpacity: opacity,
      circleRadius: radius,
    );
    await manager.create(opts);
  }

  return manager;
}

/// Convenience helper to draw a single waypoint annotation.
Future<CircleAnnotationManager> addWaypointAnnotation(
  MapboxMap map,
  Waypoint waypoint, {
  Color color = Colors.blue,
  double opacity = 1.0,
  double radius = 10,
}) {
  return addWaypointAnnotations(
    map,
    [waypoint],
    color: color,
    opacity: opacity,
    radius: radius,
  );
}

/// Add user recorded trail line to the map
Future<void> addUserTrailLine(
  MapboxMap mapboxMapController,
  List<Point> trailPoints,
) async {
  try {
    // Remove existing user trail if it exists
    try {
      await mapboxMapController.style.removeStyleLayer("user_trail_layer");
      await mapboxMapController.style.removeStyleSource("user_trail_source");
    } catch (_) {
      // Safe to ignore if not found
    }

    if (trailPoints.isEmpty) return;

    final lineString = LineString(
      coordinates: trailPoints.map((p) => p.coordinates).toList(),
    );
    final feature = Feature(geometry: lineString, id: "user_trail_line");
    final featureCollection = FeatureCollection(features: [feature]);

    await mapboxMapController.style.addSource(
      GeoJsonSource(id: "user_trail_source", data: jsonEncode(featureCollection.toJson())),
    );

    await mapboxMapController.style.addLayer(
      LineLayer(
        slot: LayerSlot.MIDDLE,
        id: "user_trail_layer",
        sourceId: "user_trail_source",
        lineColor: Colors.blue.toARGB32(), // Blue for user recorded trail
        lineBorderColor: Colors.blue.shade900.toARGB32(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineWidth: 5.0,
      ),
    );
  } catch (e, stack) {
    debugPrint("Error in addUserTrailLine: $e");
    debugPrintStack(stackTrace: stack);
  }
}

/// Safely clean up circle annotation manager
Future<void> safelyCleanupAnnotationManager(CircleAnnotationManager? manager) async {
  if (manager != null) {
    try {
      await manager.deleteAll();
      debugPrint("Successfully cleaned up annotation manager");
    } catch (e) {
      debugPrint("Error cleaning up annotation manager: $e");
      // Platform channel errors are common during cleanup, don't rethrow
    }
  }
}

/// Safely set camera with error handling
Future<void> safelySetCamera(MapboxMap mapController, CameraOptions cameraOptions) async {
  try {
    // Add a small delay to ensure map is fully initialized
    await Future.delayed(const Duration(milliseconds: 100));
    await mapController.setCamera(cameraOptions);
    debugPrint("Successfully set camera");
  } catch (e) {
    debugPrint("Error setting camera: $e");
    // Platform channel errors can occur during initialization or disposal
    // Don't rethrow to prevent app crashes
  }
}
