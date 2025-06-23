// lib/widgets/trails_card.dart
import 'package:flutter/material.dart';
import 'package:hiking_app/models/route.dart';

class TrailCard extends StatelessWidget {
  final TrailRoute trailRoute;

  const TrailCard({super.key, required this.trailRoute});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/trail_waypoints_view', arguments: trailRoute);
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  trailRoute.images.first,
                  width: double.maxFinite, // fixed width for the image
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              // trail name text
              Text(
                trailRoute.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              //location text
              Text(
                trailRoute.location,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
              SizedBox(height: 8),
              // trail description
              Text(trailRoute.description),
              Text(trailRoute.distance.toStringAsFixed(2)),
            ],
          ),
        ),
      ),
    );
  }
}
