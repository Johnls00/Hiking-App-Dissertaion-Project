import 'package:flutter/material.dart';
import 'package:hiking_app/models/route.dart';

class TrailViewScreen extends StatefulWidget {
  const TrailViewScreen({super.key});

  @override
  State<TrailViewScreen> createState() => _TrailViewScreenState();
}

int waypointIndex = 0;

class _TrailViewScreenState extends State<TrailViewScreen> {
  @override
  Widget build(BuildContext context) {
    final trailRoute = ModalRoute.of(context)!.settings.arguments as TrailRoute;

    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),

      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(trailRoute.name, textAlign: TextAlign.center),

          Image.asset(
            trailRoute.images.first,
            width: double.infinity,
            height: 400,
            fit: BoxFit.cover,
          ),

          SizedBox(height: 8),

          Row(
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

              Column(
                children: [
                  Text(trailRoute.waypoints[waypointIndex].name),
                  Text(trailRoute.waypoints[waypointIndex].returnCoordinates()),
                ],
              ),

              IconButton(
                onPressed: () {
                  setState(() {
                    if (waypointIndex < (trailRoute.waypoints.length - 1)) {
                      waypointIndex++;
                    }
                  });
                },
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
