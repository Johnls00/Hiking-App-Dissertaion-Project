
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

  // Helper to add trail line layer
  Future<void> addTrailLine(MapboxMap mapboxMapController, List<Point> trailPoints) async {
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
  }
