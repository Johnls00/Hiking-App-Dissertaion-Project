import 'package:firebase_auth/firebase_auth.dart';
import 'package:hiking_app/screens/login.dart';
import 'package:hiking_app/screens/profile_screen.dart';
import 'package:hiking_app/screens/register_screen.dart';
import 'package:hiking_app/screens/saved_trails_screen.dart';
import 'package:hiking_app/screens/trail_browse.dart';
import 'package:flutter/material.dart';
import 'package:hiking_app/screens/trail_map_view.dart';
import 'package:hiking_app/screens/trail_recording.dart';
import 'package:hiking_app/screens/trail_view.dart';
import 'package:hiking_app/screens/trail_waypoints_view.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({Key? key}) : super(key: key);

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const TrailBrowserScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
      routes: {
        '/home': (context) => const TrailBrowserScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/trail_view': (context) => const TrailViewScreen(),
        '/trail_waypoints_view': (context) => const TrailWaypointsScreen(),
        '/map_view': (context) => const TrailMapViewScreen(),
        '/trail_recording': (context) => const TrailRecordingScreen(),
        '/saved_trails': (context) => const SavedTrailsScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
