import 'package:flutter/material.dart';
import 'package:hiking_app/widgets/saved_trails_list.dart';
import 'package:hiking_app/widgets/navigation_bar_bottom_main.dart';

class SavedTrailsScreen extends StatelessWidget {
  const SavedTrailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Trails'),
        automaticallyImplyLeading: false,
      ),
      body: const SavedTrailsList(),
      bottomNavigationBar: const MainBottomNavigationBar(currentIndex: 2),
    );
  }
}
