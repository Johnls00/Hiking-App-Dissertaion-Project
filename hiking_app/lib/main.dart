import 'package:flutter/material.dart';
import 'package:hiking_app/screens/login.dart';
import 'package:hiking_app/screens/trail_browse.dart';
import 'package:hiking_app/screens/trail_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/home': (context) => TrailBrowserScreen(),
        '/trail_view': (content) => TrailViewScreen(),
      },
    ),
  );
}
