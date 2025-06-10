import 'package:hiking_app/models/route.dart';

/// A class which represents a hiking route and includes essessential information about the route.
/// 
class HikingRoute extends Route{
  final String location;
  final Duration timeToComplete;
  final double distance;
  final String difficulty;
  final String description;
  final List<String> images;
  final List<String> keyPoints;

  HikingRoute(this.timeToComplete, this.description, this.images, this.keyPoints, { required this.location, required this.difficulty, required this.distance,}) : super(name: '', routeFile: '');

  @override
  void printSummary() {
    print('$name: $distance km, Description: $description');
  }

}