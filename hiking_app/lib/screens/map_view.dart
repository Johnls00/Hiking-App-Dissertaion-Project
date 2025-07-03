import 'package:flutter/material.dart';
import 'package:hiking_app/models/route.dart';
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

late MapboxMap mapboxMap;

class _MapViewScreenState extends State<MapViewScreen> {
  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: true));
  }

  @override
  Widget build(BuildContext context) {
    final trailRoute = ModalRoute.of(context)!.settings.arguments as TrailRoute;

    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),
      body: SafeArea(
        child: Stack(
          children: [
            // Map background
            MapWidget(onMapCreated: _onMapCreated),

            // Overlay UI
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RoundBackButton(),
                        SizedBox(width: 20),
                        Flexible(
                          flex: 1,

                          child: Material(
                            color: Color.fromRGBO(221, 221, 221, 1),
                            borderRadius: BorderRadius.circular(25),
                            child: Center(
                              child: SizedBox(
                                width: 166,
                                height: 49,
                                child: Center(
                                  child: Text(
                                    trailRoute.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 69),
                      ],
                    ), // or BackButton()
                  ),
                  // Add more widgets here
                  Spacer(),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    color: Colors.white,
                    child: Text(
                      'Trail: ${trailRoute.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
