// lib/widgets/trails_card.dart
import 'package:flutter/material.dart';
import 'package:hiking_app/models/route.dart';

class TrailCard extends StatelessWidget {
  final TrailRoute trailRoute;
  
  const TrailCard({
    required this.trailRoute,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/trail_view');
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // trail image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  trailRoute.images.first,
                  width: 150, // fixed width for the image
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // trail name text
                    Text(
                      trailRoute.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    //location text
                    Text(
                      trailRoute.location,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    SizedBox(height: 8),
                    // trail description
                    Text(trailRoute.description),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
