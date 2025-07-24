import 'package:flutter/material.dart';
import 'package:hiking_app/env/env.dart';
import 'package:hiking_app/screens/login.dart';
import 'package:hiking_app/screens/map_trail_view.dart';
import 'package:hiking_app/screens/trail_browse.dart';
import 'package:hiking_app/screens/trail_view.dart';
import 'package:hiking_app/screens/trail_waypoints_view.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/home': (context) => TrailBrowserScreen(),
        '/trail_view': (content) => TrailViewScreen(),
        '/trail_waypoints_view': (content) => TrailWaypointsScreen(),
        '/map_view': (content) => MapTrailViewScreen(),
      },
    ),
  );
}

Future<void> setup() async {
  // await dotenv.load(fileName: ".env",);
  MapboxOptions.setAccessToken(Env.mapboxKey,);
  
}
