import 'package:flutter/material.dart';

class MainBottomNavigationBar extends StatelessWidget {
  const MainBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: const <BottomNavigationBarItem>[
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
          icon: Icon(
            Icons.person_outline_outlined,
            size: 30,
            color: Colors.black,
          ),
          label: 'profile',
        ),
      ],
    );
  }
}
