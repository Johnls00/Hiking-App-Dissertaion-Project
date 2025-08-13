// lib/widgets/trails_card.dart
import 'package:flutter/material.dart';
import 'package:hiking_app/models/route.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TrailCard extends StatelessWidget {
  final TrailRoute trailRoute;

  const TrailCard({super.key, required this.trailRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/trail_view', arguments: trailRoute);
        },
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                // child: trailRoute.images.isNotEmpty 
                //   ? CachedNetworkImage(
                //       imageUrl: trailRoute.images.first,
                //       width: double.maxFinite,
                //       height: 150,
                //       fit: BoxFit.cover,
                //       placeholder: (context, url) => Container(
                //         height: 150,
                //         color: Colors.grey[300],
                //         child: const Center(child: CircularProgressIndicator()),
                //       ),
                //       errorWidget: (context, url, error) {
                //         print("❌ Image loading failed for ${trailRoute.name}: $error");
                //         return Container(
                //           height: 150,
                //           color: Colors.grey[300],
                //           child: const Center(
                //             child: Icon(
                //               Icons.broken_image,
                //               size: 50,
                //               color: Colors.grey,
                //             ),
                //           ),
                //         );
                //       },
                //     )
                 child: trailRoute.images.isNotEmpty
                     ? Image.asset(
                         trailRoute.images.first,
                         width: double.maxFinite,
                         height: 150,
                         fit: BoxFit.cover,
                       )
                     : Container(
                         height: 150,
                         color: Colors.grey[300],
                         child: const Center(
                           child: Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
                    ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // trail name text
                    Text(
                      trailRoute.name,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    //location text
                    Text(
                      trailRoute.location,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    // trail description
                    Text(
                      trailRoute.description.length > 100
                          ? '${trailRoute.description.substring(0, 100)}...'
                          : trailRoute.description,
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Distance: ${(trailRoute.distance/1000).toStringAsFixed(2)} km",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue[700]),
                    ),
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
