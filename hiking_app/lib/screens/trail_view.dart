import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hiking_app/models/trail.dart';
import 'package:hiking_app/screens/trail_waypoints_view.dart';
import 'package:hiking_app/utilities/image_loader.dart';
import 'package:hiking_app/utilities/maping_utils.dart';
import 'package:hiking_app/utilities/user_profile_manager.dart';
import 'package:hiking_app/widgets/round_back_button.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrailViewScreen extends StatefulWidget {

  const TrailViewScreen({super.key});

  @override
  State<TrailViewScreen> createState() => _TrailViewScreenState();
}

late MapboxMap mapboxMapController;

class _TrailViewScreenState extends State<TrailViewScreen> {
  bool _isFavorited = false;
  bool _hasCheckedFavoriteStatus = false;
  String? imageUrl;
  bool isLoadingImage = true;
  Trail? trailRoute;

  @override
  void initState() {
    super.initState();
  }

  // trail data is initialised here instead of initState to ensure context is available - this will only run when the widgets are built
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize trailRoute from route arguments if not already set
    if (trailRoute == null) {
      trailRoute = ModalRoute.of(context)!.settings.arguments as Trail;
      _loadImageUrl(); // Load image after we have the trail data
    }
    
    if (!_hasCheckedFavoriteStatus) {
      _checkFavoriteStatus();
      _hasCheckedFavoriteStatus = true;
    }
  }

  Future<void> _loadImageUrl() async {
    if (trailRoute != null && trailRoute!.images.isNotEmpty) {
      try {
        final String imagePath = trailRoute!.images.first;
        final downloadUrl = await ImageLoader.getImageUrl(imagePath);

        if (mounted) {
          setState(() {
            imageUrl = downloadUrl;
            isLoadingImage = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading image for ${trailRoute?.name}: $e");
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

  Future<void> _checkFavoriteStatus() async {
    if (trailRoute != null) {
      final isFavorited = await UserProfileManager.isTrailFavorited(
        trailRoute!.name,
      );
      if (mounted) {
        setState(() {
          _isFavorited = isFavorited;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (trailRoute == null) return;

    try {
      if (_isFavorited) {
        await UserProfileManager.removeFromFavorites(trailRoute!.name);
      } else {
        await UserProfileManager.addToFavorites(trailRoute!.name);
      }

      if (mounted) {
        setState(() {
          _isFavorited = !_isFavorited;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorited ? 'Added to favorites' : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onMapCreated(MapboxMap controller) async {
    mapboxMapController = controller;

    await mapboxMapController.loadStyleURI(MapboxStyles.OUTDOORS);

    if (!mounted || trailRoute == null) return;

    // adding the trail line to the map
    await addTrailLine(mapboxMapController, trailRoute!.trackpoints);

    // focusing the map view to show the whole route line
    await cameraBoundsFromPoints(mapboxMapController, trailRoute!.trackpoints);

    debugPrint(trailRoute!.waypoints[0].toString());
  }

  @override
  Widget build(BuildContext context) {
    // trailRoute is now initialized in didChangeDependencies
    if (trailRoute == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top navigation row with back button and favorite button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RoundBackButton(),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {
                          UserProfileManager.addToFavorites(trailRoute!.name);
                          _toggleFavorite();
                        },
                        icon: Icon(
                          _isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorited ? Colors.red : Colors.grey[600],
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImage(),
                ),
              ),

              SizedBox(height: 8),

              Row(
                children: [
                  SizedBox(width: 10),
                  Text(trailRoute!.name, style: TextStyle(fontSize: 24)),
                ],
              ),
              Row(
                children: [
                  SizedBox(width: 10),
                  Text(
                    trailRoute!.location,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(width: 10),
                  Text(
                    "Rating",
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            (trailRoute!.distance / 1000).toStringAsFixed(2),
                            style: TextStyle(fontSize: 32, color: Colors.black),
                          ),
                          Text(
                            "km",
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        ],
                      ),
                      Text(
                        "Distance",
                        style: TextStyle(color: Colors.black45, fontSize: 16),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            (trailRoute!.elevation).toStringAsFixed(2),
                            style: TextStyle(fontSize: 32, color: Colors.black),
                          ),
                          Text(
                            "m",
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        ],
                      ),
                      Text(
                        "Elevation Gain",
                        style: TextStyle(color: Colors.black45, fontSize: 16),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            trailRoute!.timeToComplete.inMinutes.toString(),
                            style: TextStyle(fontSize: 32, color: Colors.black),
                          ),
                          Text(
                            "mins",
                            style: TextStyle(color: Colors.black, fontSize: 20),
                          ),
                        ],
                      ),
                      Text(
                        "Average time",
                        style: TextStyle(color: Colors.black45, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),
              Row(
                children: [
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      trailRoute!.description,
                      style: TextStyle(color: Colors.black, fontSize: 13),
                      softWrap: true,
                    ),
                  ),
                  SizedBox(width: 10),
                ],
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),
              Row(
                children: [
                  SizedBox(width: 10),
                  Text(
                    "Trail Overview",
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: double.maxFinite,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: MapWidget(
                    key: ValueKey(
                      waypointIndex,
                    ), // rebuilds map when index changes
                    onMapCreated: _onMapCreated,
                    // cameraOptions: CameraOptions(
                    //   center: trailRoute.trackpoints.first,
                    //   zoom: 15.5,
                    // ),
                  ),
                ),
              ),
              Divider(color: Colors.black, indent: 10, endIndent: 10),

              InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/trail_waypoints_view',
                    arguments: trailRoute,
                  );
                },
                child: SizedBox(
                  height: 49,
                  width: double.infinity,
                  child: Row(
                    children: [
                      SizedBox(width: 15),
                      Ink(
                        width: 49,
                        height: 49,
                        decoration: const ShapeDecoration(
                          color: Color.fromRGBO(221, 221, 221, 1),
                          shape: CircleBorder(),
                        ),
                        child: Icon(Icons.flag_outlined),
                      ),
                      const SizedBox(
                        width: 10,
                      ), // spacing between icon and text
                      Expanded(
                        child: Text(
                          "Explore points of interest",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Icon(size: 30, Icons.arrow_circle_right_outlined),
                      const SizedBox(width: 20), // optional right padding
                    ],
                  ),
                ),
              ),

              SizedBox(height: 12),

              InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/trail_waypoints_view',
                    arguments: trailRoute,
                  );
                },
                child: SizedBox(
                  height: 49,
                  width: double.infinity,
                  child: Row(
                    children: [
                      SizedBox(width: 15),
                      Ink(
                        width: 49,
                        height: 49,
                        decoration: const ShapeDecoration(
                          color: Color.fromRGBO(221, 221, 221, 1),
                          shape: CircleBorder(),
                        ),
                        child: Icon(Icons.rate_review_outlined),
                      ),
                      const SizedBox(
                        width: 10,
                      ), // spacing between icon and text
                      Expanded(
                        child: Text(
                          "Read reviews",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Icon(size: 30, Icons.arrow_circle_right_outlined),
                      const SizedBox(width: 20), // optional right padding
                    ],
                  ),
                ),
              ),

              Divider(color: Colors.black, indent: 10, endIndent: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 166,
                    height: 42,
                    child: Ink(
                      decoration: ShapeDecoration(
                        color: Color.fromRGBO(221, 221, 221, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              "Download",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 166,
                    height: 42,
                    child: Ink(
                      decoration: ShapeDecoration(
                        color: Color.fromRGBO(221, 221, 221, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/map_view',
                                arguments: trailRoute,
                              );
                            },
                            child: Text(
                              "View Map",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
          debugPrint(
            "CachedNetworkImage error for ${trailRoute!.name}: $error",
          );
          return Container(
            height: 150,
            color: Colors.grey[300],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'Image failed to load',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
            Icon(Icons.landscape, size: 40, color: Colors.grey[600]),
            SizedBox(height: 8),
            Text(
              'No image available',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
