import 'package:flutter/material.dart';
import 'package:gpx/gpx.dart';
import 'package:hiking_app/models/route.dart';
import 'package:hiking_app/utilities/gpx_file_util.dart';
import 'package:hiking_app/widgets/navigation_bar_bottom_main.dart';
import 'package:hiking_app/widgets/trail_card.dart';

class TrailBrowserScreen extends StatefulWidget {
  const TrailBrowserScreen({super.key});

  @override
  State<TrailBrowserScreen> createState() => _TrailBrowserScreenState();
}

class _TrailBrowserScreenState extends State<TrailBrowserScreen> {
  TrailRoute? campSiteRoute;
  TrailRoute? mourneWayRoute;
  TrailRoute? libraryRoute;
  TrailRoute? lawrenceRoute;
  TrailRoute? sanFranRoute;
  TrailRoute? myRecordingRoute;
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
      // 1) Read all GPX assets in parallel
      final gpxList = await Future.wait<Gpx>([
        GpxFileUtil.readGpxAsset('assets/park_route.gpx'), // rostrevorCampSite
        GpxFileUtil.readGpxAsset('assets/mourne_way.gpx'), // mourneWay
        GpxFileUtil.readGpxAsset('assets/library.gpx'), // library
        GpxFileUtil.readGpxAsset('assets/lawrence street loop.gpx'), // lawrence
        GpxFileUtil.readGpxAsset('assets/san_fran_test.gpx'),
        GpxFileUtil.readGpxAsset('assets/my_recording.gpx'), // sanFranTest
      ]);

      final rostrevorCampSite = gpxList[0];
      final mourneWay = gpxList[1];
      final library = gpxList[2];
      final lawrence = gpxList[3];
      final sanFranTest = gpxList[4];
      final myRecording = gpxList[5];

      // 2) Build TrailRoute objects (uses snapped waypoints, distance+elev, Naismith, difficulty)
      final campSite = GpxFileUtil.buildTrailRouteFromGpx(
        rostrevorCampSite,
        name: rostrevorCampSite.metadata?.name ?? '',
        location: 'Rostrevor',
        description: rostrevorCampSite.metadata?.desc ?? '',
        images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
        walkingSpeedKmh: 5.1,
      );

      final mourne = GpxFileUtil.buildTrailRouteFromGpx(
        mourneWay,
        name: mourneWay.metadata?.name ?? '',
        location: 'Mourne Mountains',
        description: mourneWay.metadata?.desc ?? '',
        images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
        walkingSpeedKmh: 5.1,
      );

      final libraryTrail = GpxFileUtil.buildTrailRouteFromGpx(
        library,
        name: library.metadata?.name ?? '',
        location: 'Belfast',
        description: library.metadata?.desc ?? '',
        images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
        walkingSpeedKmh: 5.1,
      );

      final lawrenceTrail = GpxFileUtil.buildTrailRouteFromGpx(
        lawrence,
        name: lawrence.metadata?.name ?? '',
        location: 'Belfast',
        description: lawrence.metadata?.desc ?? '',
        images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
        walkingSpeedKmh: 5.1,
      );

      final sanFran = GpxFileUtil.buildTrailRouteFromGpx(
        sanFranTest,
        name: sanFranTest.metadata?.name ?? '',
        location: 'San Francisco',
        description: sanFranTest.metadata?.desc ?? '',
        images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
        walkingSpeedKmh: 5.1,
      );

      final myRecordingFile = GpxFileUtil.buildTrailRouteFromGpx(
        myRecording,
        name: myRecording.metadata?.name ?? 'My Recording',
        location: 'Local Area',
        description: myRecording.metadata?.desc ?? 'Recorded trail',
        images: const ['assets/images/pexels-ivanlodo-2961929.jpg'],
        walkingSpeedKmh: 5.1,
      );

      if (!mounted) return;
      setState(() {
        campSiteRoute = campSite;
        mourneWayRoute = mourne;
        libraryRoute = libraryTrail;
        lawrenceRoute = lawrenceTrail;
        sanFranRoute = sanFran;
        myRecordingRoute = myRecordingFile;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error loading trails: $e");
      if (!mounted) return;
      setState(() {
        errorMessage = "Failed to load trails. Please try again.";
        isLoading = false;
      });
    }
  }

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
                const CircularProgressIndicator()
              else if (!isLoading && errorMessage == null) ...[
                // Local trails
                campSiteRoute != null
                    ? TrailCard(trailRoute: campSiteRoute!)
                    : const SizedBox.shrink(),
                mourneWayRoute != null
                    ? TrailCard(trailRoute: mourneWayRoute!)
                    : const SizedBox.shrink(),
                libraryRoute != null
                    ? TrailCard(trailRoute: libraryRoute!)
                    : const SizedBox.shrink(),
                lawrenceRoute != null
                    ? TrailCard(trailRoute: lawrenceRoute!)
                    : const SizedBox.shrink(),
                sanFranRoute != null
                    ? TrailCard(trailRoute: sanFranRoute!)
                    : const SizedBox.shrink(),
                myRecordingRoute != null
                    ? TrailCard(trailRoute: myRecordingRoute!)
                    : const SizedBox.shrink(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavigationBar(currentIndex: 0),
    );
  }
}
