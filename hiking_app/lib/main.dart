import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hiking_app/env/env.dart';
import 'package:hiking_app/screens/login.dart';
import 'package:hiking_app/screens/trail_map_view.dart';
import 'package:hiking_app/screens/trail_browse.dart';
import 'package:hiking_app/screens/trail_view.dart';
import 'package:hiking_app/screens/trail_waypoints_view.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:hiking_app/screens/trail_recording.dart';
import 'package:hiking_app/screens/profile_screen.dart';
import 'package:hiking_app/screens/saved_trails_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hiking_app/widget_tree.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables with error handling
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("⚠️ Warning: Could not load .env file: $e");
  }
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  cf.FirebaseFirestore.instance.settings = const cf.Settings(
    persistenceEnabled: true,
  );
  cf.FirebaseFirestore.instance.enableNetwork(); // call once at startup
  final o = Firebase.app().options;
  print('projectId=${o.projectId} appId=${o.appId} storage=${o.storageBucket}');

  // Setup Mapbox
  await setup();
  runApp(const hikingApp());
}

class hikingApp extends StatelessWidget {
  const hikingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const WidgetTree();
  }
}

Future<void> setup() async {
  final mapboxKey = Env.mapboxKey;
  if (mapboxKey.isEmpty) {
    print("⚠️ Warning: MAPBOX_ACCESS_TOKEN not found in environment variables");
    return;
  }
  MapboxOptions.setAccessToken(mapboxKey);
}
