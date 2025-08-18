import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hiking_app/auth.dart';
import 'package:hiking_app/models/trail.dart';
import 'package:hiking_app/models/waypoint.dart';
import 'package:hiking_app/widgets/navigation_bar_bottom_main.dart';
import 'package:hiking_app/widgets/trail_card.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TrailBrowserScreen extends StatefulWidget {
  const TrailBrowserScreen({super.key});

  @override
  State<TrailBrowserScreen> createState() => _TrailBrowserScreenState();
}

class _TrailBrowserScreenState extends State<TrailBrowserScreen> {
  final User? user = Auth().currentUser;
  List<Trail> trails = <Trail>[];

  // Trail? campSiteRoute;
  // Trail? mourneWayRoute;
  // Trail? libraryRoute;
  // Trail? lawrenceRoute;
  // Trail? sanFranRoute;
  // Trail? myRecordingRoute;
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTrail();
  }

  Future<void> loadTrail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Load all trails from Firestore
      final query = await FirebaseFirestore.instance
          .collection('trails')
          .orderBy('created_at', descending: true)
          .get();

      final loadedTrails = <Trail>[];

      for (var doc in query.docs) {
        final data = doc.data();
        
        debugPrint("📄 Processing trail: ${doc.id}");
        debugPrint("📊 Raw data types: image_path=${data['image_path'].runtimeType}, waypoints=${data['waypoints'].runtimeType}, trackpoints=${data['trackpoints'].runtimeType}");
        
        // Parse images
        List<String> images = [];
        if (data['image_path'] != null) {
          if (data['image_path'] is List) {
            images = List<String>.from(data['image_path']);
          } else if (data['image_path'] is String) {
            images = [data['image_path']];
          }
        }

        // Parse waypoints
        List<Waypoint> waypoints = [];
        if (data['waypoints'] != null && data['waypoints'] is List) {
          for (var w in data['waypoints']) {
            if (w is Map<String, dynamic>) {
              waypoints.add(Waypoint(
                lat: w['lat']?.toDouble() ?? 0.0,
                lon: w['lon']?.toDouble() ?? 0.0,
                ele: w['ele']?.toDouble() ?? 0.0,
                name: w['name'] ?? '',
                distanceFromStart: w['distance_from_start_m']?.toDouble() ?? 0.0,
              ));
            }
          }
        }

        // Parse trackpoints
        List<Point> trackpoints = [];
        if (data['trackpoints'] != null && data['trackpoints'] is List) {
          for (var tp in data['trackpoints']) {
            if (tp is Map<String, dynamic>) {
              trackpoints.add(Point(
                coordinates: Position(
                  tp['lon']?.toDouble() ?? 0.0,
                  tp['lat']?.toDouble() ?? 0.0,
                ),
              ));
            }
          }
        }

        // Create Trail object with proper parameter mapping
        try {
          final trail = Trail(
            doc.id,
            data['display_name'] ?? data['name'] ?? 'Untitled',
            data['location'] ?? '',
            Duration(minutes: data['time_to_complete_m'] ?? 0),
            (data['track_length_m'] ?? 0).toDouble(),
            (data['elevation_gain_m'] ?? 0).toDouble(),
            data['difficulty'] ?? '',
            data['description'] ?? '',
            images,
            waypoints,
            trackpoints,
          );

          loadedTrails.add(trail);
          debugPrint("✅ Successfully created trail: ${trail.name}");
        } catch (e) {
          debugPrint("❌ Error creating trail for doc ${doc.id}: $e");
          debugPrint("📋 Data was: $data");
        }
      }

      if (!mounted) return;
      setState(() {
        trails = loadedTrails;
        isLoading = false;
      });
        
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error loading trails: $e';
        isLoading = false;
      });
    }
  }

  @override
    //     GpxFileUtil.readGpxAsset('assets/library.gpx'), // library
    //     GpxFileUtil.readGpxAsset('assets/lawrence street loop.gpx'), // lawrence
    //     GpxFileUtil.readGpxAsset('assets/san_fran_test.gpx'),
    //     GpxFileUtil.readGpxAsset('assets/my_recording.gpx'), // sanFranTest
    //   ]);

    //   final rostrevorCampSite = gpxList[0];
    //   final mourneWay = gpxList[1];
    //   final library = gpxList[2];
    //   final lawrence = gpxList[3];
    //   final sanFranTest = gpxList[4];
    //   final myRecording = gpxList[5];

    //   // 2) Build TrailRoute objects (uses snapped waypoints, distance+elev, Naismith, difficulty)
    //   final campSite = GpxFileUtil.buildTrailRouteFromGpx(
    //     rostrevorCampSite,
    //     name: rostrevorCampSite.metadata?.name ?? '',
    //     location: 'Rostrevor',
    //     description: rostrevorCampSite.metadata?.desc ?? '',
    //     images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
    //     walkingSpeedKmh: 5.1,
    //   );

    //   final mourne = GpxFileUtil.buildTrailRouteFromGpx(
    //     mourneWay,
    //     name: mourneWay.metadata?.name ?? '',
    //     location: 'Mourne Mountains',
    //     description: mourneWay.metadata?.desc ?? '',
    //     images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
    //     walkingSpeedKmh: 5.1,
    //   );

    //   final libraryTrail = GpxFileUtil.buildTrailRouteFromGpx(
    //     library,
    //     name: library.metadata?.name ?? '',
    //     location: 'Belfast',
    //     description: library.metadata?.desc ?? '',
    //     images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
    //     walkingSpeedKmh: 5.1,
    //   );

    //   final lawrenceTrail = GpxFileUtil.buildTrailRouteFromGpx(
    //     lawrence,
    //     name: lawrence.metadata?.name ?? '',
    //     location: 'Belfast',
    //     description: lawrence.metadata?.desc ?? '',
    //     images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
    //     walkingSpeedKmh: 5.1,
    //   );

    //   final sanFran = GpxFileUtil.buildTrailRouteFromGpx(
    //     sanFranTest,
    //     name: sanFranTest.metadata?.name ?? '',
    //     location: 'San Francisco',
    //     description: sanFranTest.metadata?.desc ?? '',
    //     images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
    //     walkingSpeedKmh: 5.1,
    //   );

    //   final myRecordingFile = GpxFileUtil.buildTrailRouteFromGpx(
    //     myRecording,
    //     name: myRecording.metadata?.name ?? 'My Recording',
    //     location: 'Local Area',
    //     description: myRecording.metadata?.desc ?? 'Recorded trail',
    //     images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
    //     walkingSpeedKmh: 5.1,
    //   );

    //   if (!mounted) return;
    //   setState(() {
    //     campSiteRoute = campSite;
    //     mourneWayRoute = mourne;
    //     libraryRoute = libraryTrail;
    //     lawrenceRoute = lawrenceTrail;
    //     sanFranRoute = sanFran;
    //     myRecordingRoute = myRecordingFile;
    //     isLoading = false;
    //   });
    // } catch (e) {
    //   debugPrint("❌ Error loading trails: $e");
    //   if (!mounted) return;
    //   setState(() {
    //     errorMessage = "Failed to load trails. Please try again.";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: SizedBox(
                  width: double.infinity,
                  child: SearchAnchor(
                    builder:
                        (BuildContext context, SearchController controller) {
                          return SearchBar(
                            controller: controller,
                            padding: const WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(horizontal: 16.0),
                            ),
                            onTap: () {
                              controller.openView();
                            },
                            onChanged: (_) {
                              controller.openView();
                            },
                            leading: const Icon(Icons.search),
                          );
                        },
                    suggestionsBuilder:
                        (BuildContext context, SearchController controller) {
                          return List<ListTile>.generate(5, (int index) {
                            final String item = 'item $index';
                            return ListTile(
                              title: Text(item),
                              onTap: () {
                                setState(() {
                                  controller.closeView(item);
                                });
                              },
                            );
                          });
                        },
                  ),
                ),
              ),
              // Spacer box
              SizedBox(height: 15),

              // Error message
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: loadTrail,
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Trail cards with loading states
              if (isLoading && errorMessage == null)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!isLoading && errorMessage == null) ...[
                // Display trails from server
                ...trails.map((trail) => TrailCard(trailRoute: trail)).toList(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavigationBar(currentIndex: 0),
    );
  }
}
