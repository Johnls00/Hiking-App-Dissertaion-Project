import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hiking_app/models/route.dart';
import 'package:hiking_app/screens/trail_waypoints_view.dart';
import 'package:hiking_app/utilities/maping_utils.dart';
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrailViewScreen extends StatefulWidget {
  const TrailViewScreen({super.key});

  @override
  State<TrailViewScreen> createState() => _TrailViewScreenState();
}

late MapboxMap mapboxMapController;

class _TrailViewScreenState extends State<TrailViewScreen> {
  void _onMapCreated(MapboxMap controller) async {
    mapboxMapController = controller;
    await mapboxMapController.loadStyleURI(MapboxStyles.OUTDOORS);
    if (!mounted) return;
    final trailRoute = ModalRoute.of(context)!.settings.arguments as TrailRoute;

    final lineString = LineString(
      coordinates: trailRoute.trackpoints.map((p) => p.coordinates).toList(),
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

    await cameraBoundsFromPoints(mapboxMapController, trailRoute.trackpoints);
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RoundBackButton(),

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

              Row(
                children: [
                  SizedBox(width: 10),
                  Text(trailRoute.name, style: TextStyle(fontSize: 24)),
                ],
              ),
              Row(
                children: [
                  SizedBox(width: 10),
                  Text(
                    trailRoute.location,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(width: 10),
                  Text(
                    "Rating",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            (trailRoute.distance / 1000).toStringAsFixed(2),
                            style: TextStyle(fontSize: 32, color: Colors.black),
                          ),
                          Text(
                            "km",
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        ],
                      ),
                      Text(
                        "Distance",
                        style: TextStyle(color: Colors.black45, fontSize: 16),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            (trailRoute.elevation).toStringAsFixed(2),
                            style: TextStyle(fontSize: 32, color: Colors.black),
                          ),
                          Text(
                            "m",
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        ],
                      ),
                      Text(
                        "Elevation Gain",
                        style: TextStyle(color: Colors.black45, fontSize: 16),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            trailRoute.timeToComplete.inMinutes.toString(),
                            style: TextStyle(fontSize: 32, color: Colors.black),
                          ),
                          Text(
                            "mins",
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        ],
                      ),
                      Text(
                        "Average time",
                        style: TextStyle(color: Colors.black45, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),
              Row(
                children: [
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      trailRoute.description,
                      style: TextStyle(color: Colors.black, fontSize: 13), softWrap: true,
                    ),
                  ),
                  SizedBox(width: 10),
                ],
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),
              Row(
                children: [
                  SizedBox(width: 10),
                  Text(
                    "Trail Overview",
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ],
              ),

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
                    // cameraOptions: CameraOptions(
                    //   center: trailRoute.trackpoints.first,
                    //   zoom: 15.5,
                    // ),
                  ),
                ),
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),

              InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/trail_waypoints_view',
                    arguments: trailRoute,
                  );
                },
                child: SizedBox(
                  height: 49,
                  width: double.infinity,
                  child: Row(
                    children: [
                      SizedBox(width: 15),
                      Ink(
                        width: 49,
                        height: 49,
                        decoration: const ShapeDecoration(
                          color: Color.fromRGBO(221, 221, 221, 1),
                          shape: CircleBorder(),
                        ),
                        child: Icon(Icons.flag_outlined),
                      ),
                      const SizedBox(
                        width: 10,
                      ), // spacing between icon and text
                      Expanded(
                        child: Text(
                          "Explore points of interest",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Icon(size: 30, Icons.arrow_circle_right_outlined),
                      const SizedBox(width: 20), // optional right padding
                    ],
                  ),
                ),
              ),

              SizedBox(height: 12),

              InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/trail_waypoints_view',
                    arguments: trailRoute,
                  );
                },
                child: SizedBox(
                  height: 49,
                  width: double.infinity,
                  child: Row(
                    children: [
                      SizedBox(width: 15),
                      Ink(
                        width: 49,
                        height: 49,
                        decoration: const ShapeDecoration(
                          color: Color.fromRGBO(221, 221, 221, 1),
                          shape: CircleBorder(),
                        ),
                        child: Icon(Icons.rate_review_outlined),
                      ),
                      const SizedBox(
                        width: 10,
                      ), // spacing between icon and text
                      Expanded(
                        child: Text(
                          "Read reviews",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Icon(size: 30, Icons.arrow_circle_right_outlined),
                      const SizedBox(width: 20), // optional right padding
                    ],
                  ),
                ),
              ),

              Divider(color: Colors.black, indent: 10, endIndent: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              "Download",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/map_view',
                                arguments: trailRoute,
                              );
                            },
                            child: Text(
                              "View Map",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
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
