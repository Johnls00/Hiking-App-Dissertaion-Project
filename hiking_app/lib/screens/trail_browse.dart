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

  @override
  void initState() {
    super.initState();
    loadTrail();
  }

  void loadTrail() async {
    Gpx rostrevorCampSite = await GpxFileUtil.readGpxFile(
      'assets/park_route.gpx',
    );
    Gpx mourneWay = await GpxFileUtil.readGpxFile('assets/mourne_way.gpx');

    setState(() {
      campSiteRoute = TrailRoute(
        rostrevorCampSite.metadata!.name.toString(),
        'Rostrevor',
        GpxFileUtil.calculateWalkingDuration(
          GpxFileUtil.calculateTotalDistance(rostrevorCampSite),
          5.1,
        ),
        GpxFileUtil.calculateTotalDistance(rostrevorCampSite),
        GpxFileUtil.calculateElevationGain(rostrevorCampSite),
        'easy',
        rostrevorCampSite.metadata!.desc.toString(),
        ['assets/images/pexels-ivanlodo-2961929.jpg'],
        GpxFileUtil.mapWaypoints(rostrevorCampSite),
        GpxFileUtil.mapTrackpoints(rostrevorCampSite),
      );

      mourneWayRoute = TrailRoute(
        mourneWay.metadata!.name.toString(),
        'Mourne mountains',
        GpxFileUtil.calculateWalkingDuration(
          GpxFileUtil.calculateTotalDistance(mourneWay),
          5.1,
        ),
        GpxFileUtil.calculateTotalDistance(mourneWay),
        GpxFileUtil.calculateElevationGain(mourneWay),
        'easy',
        mourneWay.metadata!.desc.toString(),
        ['assets/images/pexels-ivanlodo-2961929.jpg'],
        GpxFileUtil.mapWaypoints(mourneWay),
        GpxFileUtil.mapTrackpoints(mourneWay),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),

      body: SafeArea(
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
                  builder: (BuildContext context, SearchController controller) {
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

            // Trail cards
            campSiteRoute != null
                ? TrailCard(trailRoute: campSiteRoute!)
                : const CircularProgressIndicator(),
            mourneWayRoute != null
                ? TrailCard(trailRoute: mourneWayRoute!)
                : const CircularProgressIndicator(),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavigationBar(),
    );
  }
}
