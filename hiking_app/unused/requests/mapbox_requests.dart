import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:hiking_app/env/env.dart';
import '../helpers/dio_exceptions.dart';

const String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';
final String _accessToken = Env.mapboxKey;

final Dio _dio = Dio(BaseOptions(
  contentType: Headers.jsonContentType,
));

/// Fetches a route from Mapbox Directions API.
/// 
/// [source] and [destination] are the start and end coordinates.
/// [navType] is the profile to use (e.g. `walking`, `driving`, `cycling`).
/// 
/// Returns the decoded JSON response as a [Map], or `null` if an error occurs.
Future<Map<String, dynamic>?> getRouteUsingMapbox(
  LatLng source,
  LatLng destination,
  String navType,
) async {
  final url =
      '$_baseUrl/$navType/${source.longitude},${source.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?alternatives=true'
      '&continue_straight=true'
      '&geometries=geojson'
      '&language=en'
      '&overview=full'
      '&steps=true'
      '&access_token=$_accessToken';

  debugPrint('Fetching route: $url');

  try {
    final response = await _dio.get(url);
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    final errorMessage = DioExceptions.fromDioError(e).toString();
    debugPrint('Mapbox request failed: $errorMessage');
    return null;
  }
}