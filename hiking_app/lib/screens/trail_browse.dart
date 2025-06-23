import 'package:flutter/material.dart';
import 'package:gpx/gpx.dart';
import 'package:hiking_app/models/route.dart';
import 'package:hiking_app/models/waypoint.dart';
import 'package:hiking_app/utilities/gpx_file_util.dart';
import 'package:hiking_app/widgets/trail_card.dart';

class TrailBrowserScreen extends StatefulWidget {
  const TrailBrowserScreen({super.key});

  @override
  State<TrailBrowserScreen> createState() => _TrailBrowserScreenState();
}

class _TrailBrowserScreenState extends State<TrailBrowserScreen> {
  TrailRoute? campSiteRoute;

  @override
  void initState() {
    super.initState();
    loadTrail();
  }

  void loadTrail() async {
    Gpx gpxFile = await GpxFileUtil.readGpxFile('assets/park_route.gpx');
    List<Waypoint> waypoints = GpxFileUtil.mapWaypoints(gpxFile);

    print(waypoints);
    setState(() {
      campSiteRoute = TrailRoute(
        'Camp site loop',
        'assets/park_route.gpx',
        'Rostrevor',
        Duration(hours: 2, minutes: 3, seconds: 2),
        GpxFileUtil.calculateTotalDistance(gpxFile),
        'easy',
        'A walk around a camp site.',
        ['assets/images/pexels-ivanlodo-2961929.jpg'],
        waypoints,
      );
      print(campSiteRoute?.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(241, 244, 248, 1),

      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 45),
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
        ],
      ),
    );
  }
}
