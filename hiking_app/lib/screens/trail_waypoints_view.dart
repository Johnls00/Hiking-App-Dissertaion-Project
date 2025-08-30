import 'package:flutter/material.dart';
import 'package:hiking_app/models/trail.dart';
import 'package:hiking_app/utilities/maping_utils.dart' as map_utils;
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrailWaypointsScreen extends StatefulWidget {
  const TrailWaypointsScreen({super.key});

  @override
  State<TrailWaypointsScreen> createState() => _TrailWaypointsScreenState();
}

int waypointIndex = 0;

late MapboxMap mapboxMapController;
CircleAnnotationManager? circleAnnotationManager;

class _TrailWaypointsScreenState extends State<TrailWaypointsScreen> {
  @override
  void initState() {
    super.initState();
    waypointIndex = 0;
  }

  @override
  void dispose() {
    // Clean up annotation manager if it exists
    circleAnnotationManager = null;
    super.dispose();
  }

  void _onMapCreated(MapboxMap controller) async {
    mapboxMapController = controller;
    await mapboxMapController.loadStyleURI(MapboxStyles.OUTDOORS);

    // Clean up existing annotations safely
    await map_utils.safelyCleanupAnnotationManager(circleAnnotationManager);

    if (!mounted) return;

    try {
      final trailRoute =
          ModalRoute.of(context)!.settings.arguments as Trail;
      final waypoint = trailRoute.waypoints[waypointIndex];

      await map_utils.addTrailLine(mapboxMapController, trailRoute.trackpoints);

      circleAnnotationManager = await map_utils.addWaypointAnnotation(
        mapboxMapController,
        waypoint,
      );
    } catch (e, stack) {
      debugPrint("Error in _onMapCreated: $e");
      debugPrintStack(stackTrace: stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailRoute = ModalRoute.of(context)!.settings.arguments as Trail;

    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page back button
              RoundBackButton(),
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
                      Row(
                        children: [
                          Text(
                            (trailRoute
                                        .waypoints[waypointIndex]
                                        .distanceFromStart /
                                    1000)
                                .toStringAsFixed(2),
                            style: TextStyle(fontSize: 32),
                          ),
                          Text(
                            "km",
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        ],
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
                      Row(
                        children: [
                          Text(
                            trailRoute.waypoints[waypointIndex].ele
                                .toStringAsFixed(2),
                            style: TextStyle(fontSize: 32),
                          ),
                          Text(
                            "m",
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        ],
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

              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: ClipRRect(
              //     borderRadius: BorderRadius.circular(12),
              //     child: Image.asset(
              //       trailRoute.images.first,
              //       width: double.maxFinite, // fixed width for the image
              //       height: 200,
              //       fit: BoxFit.cover,
              //     ),
              //   ),
              // ),

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
