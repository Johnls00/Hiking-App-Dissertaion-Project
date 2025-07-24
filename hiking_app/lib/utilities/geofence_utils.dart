import 'package:latlong2/latlong.dart';

final Distance _distance = Distance();

/// Checks whether the user's location is within a radius (in meters)
/// of any of the trail points.
bool isWithinGeofence(
  LatLng userPosition,
  List<LatLng> trailPoints, {
  double radiusMeters = 50,
}) {
  for (LatLng point in trailPoints) {
    final double meters = _distance.as(LengthUnit.Meter, userPosition, point);
    if (meters <= radiusMeters) {
      return true;
    }
  }
  return false;
}