import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hiking_app/models/route.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrailWaypointsScreen extends StatefulWidget {
  const TrailWaypointsScreen({super.key});

  @override
  State<TrailWaypointsScreen> createState() => _TrailWaypointsScreenState();
}

int waypointIndex = 0;

late MapboxMap mapboxMap;
CircleAnnotationManager? circleAnnotationManager;

class _TrailWaypointsScreenState extends State<TrailWaypointsScreen> {
  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    circleAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();

    await circleAnnotationManager?.deleteAll();

    final trailRoute = ModalRoute.of(context)!.settings.arguments as TrailRoute;
    final waypoint = trailRoute.waypoints[waypointIndex];
    // Load the image from assets
    // final ByteData bytes = await rootBundle.load('assets/icons/waypoint-marker.png');
    // final Uint8List imageData = bytes.buffer.asUint8List();

    // Create a PointAnnotationOptions
    CircleAnnotationOptions circleAnnotationOptions = CircleAnnotationOptions(
      geometry: Point(coordinates: Position(waypoint.lon, waypoint.lat) ),
      circleColor: Colors.blue.toARGB32(), // Example coordinates
      circleOpacity: 1,
      circleRadius: 10,
    );

    circleAnnotationManager?.create(circleAnnotationOptions);

    final lineString = LineString(coordinates: trailRoute.trackpoints.map((p) => p.coordinates).toList(),);
    final feature = Feature(geometry: lineString, id: "route_line");
    final featureCollection = FeatureCollection(features: [feature]);

    await mapboxMap.style.addSource(
      GeoJsonSource(id: "line", data: jsonEncode(featureCollection.toJson())),
    );

    await mapboxMap.style.addLayer(
      LineLayer(
        slot: "middle",
        id: "line_layer",
        sourceId: "line",
        lineColor: Colors.red.toARGB32(),
        lineBorderColor: Colors.red.shade900.toARGB32(),
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineWidth: 6.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trailRoute = ModalRoute.of(context)!.settings.arguments as TrailRoute;

    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page back button
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(width: 10),
                  Ink(
                    decoration: const ShapeDecoration(
                      color: Color.fromRGBO(221, 221, 221, 1),
                      shape: CircleBorder(),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pushNamed(context, "/home");
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                ],
              ),

              // map widget
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: double.maxFinite,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: MapWidget(
                    key: ValueKey(
                      waypointIndex,
                    ), // rebuilds map when index changes
                    onMapCreated: _onMapCreated,

                    cameraOptions: CameraOptions(
                      center: Point(
                        coordinates: Position(
                          trailRoute.waypoints[waypointIndex].lon,
                          trailRoute.waypoints[waypointIndex].lat,
                        ),
                      ),
                      zoom: 17,
                    ),
                  ),
                ),
              ),

              // Waypoint name
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 12),
                  Text(
                    trailRoute.waypoints[waypointIndex].name,
                    style: TextStyle(fontSize: 24),
                  ),
                ],
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trailRoute.waypoints[waypointIndex].distanceFromStart
                            .toStringAsFixed(2),
                        style: TextStyle(fontSize: 32),
                      ),
                      Text(
                        "Distance",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromRGBO(104, 104, 104, 1),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 38),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trailRoute.waypoints[waypointIndex].ele.toStringAsFixed(
                          2,
                        ),
                        style: TextStyle(fontSize: 32),
                      ),
                      Text(
                        "Elevation",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromRGBO(104, 104, 104, 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Divider(color: Colors.black, indent: 10, endIndent: 10),

              Row(
                children: [
                  SizedBox(width: 10),
                  Text(
                    trailRoute.waypoints[waypointIndex].description,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    trailRoute.images.first,
                    width: double.maxFinite, // fixed width for the image
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              SizedBox(height: 8),

              Divider(color: Colors.black, indent: 10, endIndent: 10),

              // waypoint navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 166,
                    height: 42,
                    child: Ink(
                      decoration: ShapeDecoration(
                        color: Color.fromRGBO(221, 221, 221, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (waypointIndex > 0) {
                                  waypointIndex--;
                                }
                              });
                            },
                            icon: const Icon(Icons.arrow_back),
                          ),

                          Text(
                            "${waypointIndex + 1}/${trailRoute.waypoints.length}",
                          ),

                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (waypointIndex <
                                    (trailRoute.waypoints.length - 1)) {
                                  waypointIndex++;
                                }
                              });
                            },
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
