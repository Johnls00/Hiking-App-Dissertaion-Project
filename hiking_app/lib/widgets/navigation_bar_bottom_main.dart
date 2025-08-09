import 'package:flutter/material.dart';

class MainBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const MainBottomNavigationBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/trail_recording');
        break;
      case 2:
        break;
      case 3:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      onTap: (index) => _onItemTapped(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined, size: 30, color: Colors.black),
          label: 'home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined, size: 30, color: Colors.black),
          label: 'map',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_border, size: 30, color: Colors.black),
          label: 'favourites',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_outlined, size: 30, color: Colors.black),
          label: 'profile',
        ),
      ],
    );
  }
}