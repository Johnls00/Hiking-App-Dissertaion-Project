import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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
  await mapboxMapController.setCamera(camera);
}
