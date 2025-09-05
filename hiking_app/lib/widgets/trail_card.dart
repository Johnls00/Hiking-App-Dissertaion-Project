// lib/widgets/trails_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hiking_app/models/trail.dart';
import 'package:hiking_app/utilities/image_loader.dart';

class TrailCard extends StatefulWidget {
  final Trail trailRoute;

  const TrailCard({super.key, required this.trailRoute});

  @override
  State<TrailCard> createState() => _TrailCardState();
}

class _TrailCardState extends State<TrailCard> {
  String? imageUrl;
  bool isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _loadImageUrl();
  }

  Future<void> _loadImageUrl() async {
    if (widget.trailRoute.images.isNotEmpty) {
      try {
        final String imagePath = widget.trailRoute.images.first;
        final downloadUrl = await ImageLoader.getImageUrl(imagePath);
        
        if (mounted) {
          setState(() {
            imageUrl = downloadUrl;
            isLoadingImage = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading image for ${widget.trailRoute.name}: $e");
        if (mounted) {
          setState(() {
            imageUrl = null;
            isLoadingImage = false;
          });
        }
      }
    } else {
      setState(() {
        isLoadingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/trail_view', arguments: widget.trailRoute);
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
                child: _buildImage(),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // trail name text
                    Text(
                      widget.trailRoute.name,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    //location text
                    Text(
                      widget.trailRoute.location,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    // trail description
                    Text(
                      widget.trailRoute.description.length > 100
                          ? '${widget.trailRoute.description.substring(0, 100)}...'
                          : widget.trailRoute.description,
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Distance: ${(widget.trailRoute.distance/1000).toStringAsFixed(2)} km",
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

  Widget _buildImage() {
    if (isLoadingImage) {
      return Container(
        height: 150,
        color: Colors.grey[300],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text(
                'Loading image...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: double.maxFinite,
        height: 150,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 150,
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          debugPrint("CachedNetworkImage error for ${widget.trailRoute.name}: $error");
          return Container(
            height: 150,
            color: Colors.grey[300],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 40,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Image failed to load',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // No image available or empty image path
    return Container(
      height: 150,
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.landscape,
              size: 40,
              color: Colors.grey[600],
            ),
            SizedBox(height: 8),
            Text(
              'No image available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
