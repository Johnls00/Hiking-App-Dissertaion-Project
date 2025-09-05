// Flutter Web: GPX Uploader + Mapper (waypoints + trackpoints only)
// ---------------------------------------------------------------
// es
// - Lets a user select a .gpx file
// - Parses only <wpt> and <trkpt> using the `gpx` package
// - Renders waypoints (markers) and trackpoints (polyline) on a Leaflet map via `flutter_map`
// - (Optional) Uploads the ORIGINAL file and a SANITIZED GPX (wpt+trkpt only) to Firebase Storage
// - Writes minimal metadata (counts, bbox, length) to Firestore
import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gpx/gpx.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path; // avoid name clash
import 'package:uploader_web/firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';


// ---- Firebase (optional) ----
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:uploader_web/models/trackpoint.dart';
import 'package:uploader_web/models/waypoint.dart';

class GpxUploaderAndMapper extends StatefulWidget {
  const GpxUploaderAndMapper({super.key});

  @override
  State<GpxUploaderAndMapper> createState() => _GpxUploaderAndMapperState();
}

class _GpxUploaderAndMapperState extends State<GpxUploaderAndMapper> {
  // ignore: non_constant_identifier_names
  final GEOCODING_API_KEY = dotenv.env['GEOCODING_API_KEY'] ?? '';
  // ignore: non_constant_identifier_names
  final MAPBOX_ACCESS_TOKEN = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  
  

  Gpx? _parsed;
  List<Trackpoint> _trackPoints = [];
  List<Waypoint> _waypoints = [];
  // LatLng? _center;
  double _trackLengthMeters = 0;
  double _elevationGainMeters = 0;
  int _timeToComplete = 0; // in minutes
  String? _fileName;
  String? _status;
  String? _location;
  String? _difficulty;
  Uint8List? _trailImageBytes;
  String? _trailImageName;
  
  Future<void> _pickTrailImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _trailImageBytes = file.bytes!;
      _trailImageName = file.name;
      // ignore: unnecessary_brace_in_string_interps
      _status = 'Selected cover photo: ${_trailImageName}';
    });
  }

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _firebaseReady = false;

  @override
  void initState() {
    super.initState();
    _initFirebase();
    assert(
      MAPBOX_ACCESS_TOKEN.isNotEmpty,
      'MAPBOX_ACCESS_TOKEN is empty — check .env load & pubspec assets',
    );
    debugPrint('Mapbox token length: ${MAPBOX_ACCESS_TOKEN.length}');
    debugPrint('Geocoding API key : ${GEOCODING_API_KEY.length}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // If you don't want Firebase, you can leave it uninitialized.
      setState(() => _firebaseReady = Firebase.apps.isNotEmpty);
    } catch (_) {
      // Safe: ignore if not configured; widget still works without Firebase
      setState(() => _firebaseReady = false);
    }
    
  }

  Future<void> _pickAndParseGpx() async {
    setState(() {
      _status = 'Picking file…';
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      setState(() => _status = 'No file selected');
      return;
    }

    final file = result.files.first;
    _fileName = file.name;

    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _status = 'Could not read file bytes');
      return;
    }

    setState(() => _status = 'Parsing GPX…');

    final xml = utf8.decode(bytes);
    final gpx = GpxReader().fromString(xml);

    // Extract only waypoints and trackpoints
    final wpts = <Waypoint>[];
    for (final w in gpx.wpts) {
      if (w.lat != null && w.lon != null) {
        wpts.add(
          Waypoint(
            lat: w.lat!,
            lon: w.lon!,
            ele: w.ele ?? 0.0,
            name: w.name ?? '',
            distanceFromStart: 0.0,
          ),
        );
      }
    }

    final trkpts = <Trackpoint>[];
    for (final trk in gpx.trks) {
      for (final seg in trk.trksegs) {
        for (final p in seg.trkpts) {
          if (p.lat != null && p.lon != null) {
            trkpts.add(Trackpoint(lat: p.lat!, lon: p.lon!, ele: p.ele ?? 0.0));
          }
        }
      }
    }

    // Compute length in meters of trackpoints polyline (Haversine via LatLong Distance)
    final distance = Distance();
    double meters = 0;
    final cumulative = <double>[];
    if (trkpts.isNotEmpty) {
      cumulative.add(0);
      for (int i = 1; i < trkpts.length; i++) {
        meters += distance(
          _toLatLngTrack(trkpts[i - 1]),
          _toLatLngTrack(trkpts[i]),
        );
        cumulative.add(meters);
      }
    }

    // Compute distance-from-start for each waypoint as the cumulative distance at the nearest trackpoint index
    if (trkpts.isNotEmpty && wpts.isNotEmpty) {
      for (final w in wpts) {
        int nearestIdx = 0;
        double best = double.infinity;
        final wLatLng = _toLatLngWay(w);
        for (int i = 0; i < trkpts.length; i++) {
          final d = distance(wLatLng, _toLatLngTrack(trkpts[i]));
          if (d < best) {
            best = d;
            nearestIdx = i;
          }
        }
        w.distanceFromStart = cumulative.isNotEmpty
            ? cumulative[nearestIdx]
            : 0.0;
      }
    }

        // Add auto-generated Start, Midpoint, End waypoints based on trackpoints
    if (trkpts.isNotEmpty) {
      final firstTp = trkpts.first;
      final lastTp = trkpts.last;
      final midIdx = trkpts.length ~/ 2;
      final midTp = trkpts[midIdx];

      // Ensure cumulative distances exist for distanceFromStart
      final distStart = 0.0;
      final distMid = cumulative.isNotEmpty && midIdx < cumulative.length ? cumulative[midIdx] : 0.0;
      final distEnd = cumulative.isNotEmpty ? cumulative.last : meters;

      wpts.addAll([
        Waypoint(
          lat: firstTp.lat,
          lon: firstTp.lon,
          ele: firstTp.ele,
          name: 'Start',
          description: 'Start of the track',
          distanceFromStart: distStart,
        ),
        Waypoint(
          lat: midTp.lat,
          lon: midTp.lon,
          ele: midTp.ele,
          name: 'Midpoint',
          description: 'Midpoint of the track',
          distanceFromStart: distMid,
        ),
        Waypoint(
          lat: lastTp.lat,
          lon: lastTp.lon,
          ele: lastTp.ele,
          name: 'End',
          description: 'End of the track',
          distanceFromStart: distEnd,
        ),
      ]);
    }

    Future<String?> reverseGeocode(
      double lat,
      double lon, {
      required String apiKey,
    }) async {
      if (apiKey.isEmpty) return null;

      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '$lat,$lon',
        'key': apiKey,
      });

      try {
        final resp = await http.get(uri).timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return null;

        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        final results = (data['results'] as List?) ?? const [];

        if (status != 'OK' || results.isEmpty) return null;

        final first = results.first as Map<String, dynamic>;
        final components = (first['address_components'] as List?) ?? const [];

        // Build a map of type -> long_name (last one wins, fine for our use)
        final parts = <String, String>{};
        for (final c in components.cast<Map<String, dynamic>>()) {
          final types = (c['types'] as List?)?.cast<String>() ?? const [];
          final name = (c['long_name'] as String?) ?? '';
          for (final t in types) {
            parts[t] = name;
          }
        }

        final locality =
            parts['locality'] ?? parts['postal_town'] ?? parts['sublocality'];
        final admin =
            parts['administrative_area_level_1'] ??
            parts['administrative_area_level_2'];

        if ((locality != null && locality.isNotEmpty) &&
            (admin != null && admin.isNotEmpty)) {
          return '$locality, $admin';
        }

        return first['formatted_address'] as String?;
      } catch (_) {
        return null;
      }
    }

    String classifyDifficulty(
      double distanceMeters,
      double elevationGainMeters,
    ) {
      final km = distanceMeters / 1000.0;

      if (km <= 6 && elevationGainMeters <= 200) {
        return "easy";
      }
      if (km <= 12 && elevationGainMeters <= 600) {
        return "moderate";
      }
      return "hard";
    }

    double elevationGain(
      List<Map<String, dynamic>> pts, {
      double threshold = 2.0,
    }) {
      double gain = 0.0;

      for (int i = 0; i < pts.length - 1; i++) {
        final double ele1 = (pts[i]['ele'] ?? 0.0).toDouble();
        final double ele2 = (pts[i + 1]['ele'] ?? 0.0).toDouble();
        final double d = ele2 - ele1;

        if (d > threshold) {
          gain += d;
        }
      }
      return gain;
    }

    int naismithMinutes(
      double distanceM,
      double elevationGainM, {
      double baseSpeedKmh = 5.1,
    }) {
      final hours =
          (distanceM / 1000.0) / baseSpeedKmh + (elevationGainM / 600.0);
      return (hours * 60).round();
    }

    final elevationGainM = elevationGain(
      trkpts.map((p) => {'lat': p.lat, 'lon': p.lon, 'ele': p.ele}).toList(),
    );

    final nice = await reverseGeocode(
      trkpts.first.lat,
      trkpts.first.lon,
      apiKey: GEOCODING_API_KEY,
    );

    final difficulty = classifyDifficulty(meters, elevationGainM);
    final timeToComplete = naismithMinutes(meters, elevationGainM);

    // LatLng? center;
    // if (trkpts.isNotEmpty || wpts.isNotEmpty) {
    //   final allTrackLats = trkpts.map((p) => p.lat).toList();
    //   final allTrackLons = trkpts.map((p) => p.lon).toList();
    //   final allWayLats = wpts.map((w) => w.lat).toList();
    //   final allWayLons = wpts.map((w) => w.lon).toList();

    //   final allLats = [...allTrackLats, ...allWayLats];
    //   final allLons = [...allTrackLons, ...allWayLons];

    //   final minLat = allLats.reduce(math.min);
    //   final maxLat = allLats.reduce(math.max);
    //   final minLon = allLons.reduce(math.min);
    //   final maxLon = allLons.reduce(math.max);
    //   center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    // }

    setState(() {
      _parsed = gpx;
      _waypoints = wpts;
      _trackPoints = trkpts;
      // _center = const LatLng(54.5, 8.0);
      _trackLengthMeters = meters;
      _elevationGainMeters = elevationGainM;
      _timeToComplete = timeToComplete;
      _difficulty = difficulty;
      _location =
          nice ??
          '${trkpts.first.lat.toStringAsFixed(5)},${trkpts.first.lon.toStringAsFixed(5)}';
      _status = 'Parsed ${wpts.length} waypoints, ${trkpts.length} trackpoints';
    });
  }

  Future<void> _uploadToFirebase() async {
    if (!_firebaseReady) {
      setState(() => _status = 'Firebase not initialized. Skipping upload.');
      return;
    }

    if (_parsed == null || _fileName == null) {
      setState(() => _status = 'Nothing to upload');
      return;
    }

    try {
      setState(() => _status = 'Uploading to Firebase…');

      // Prepare a new doc ref so we can use its id for storage path
      final docRef = FirebaseFirestore.instance.collection('trails').doc();

      // Optional: upload cover image first
      String? imagePath;
      if (_trailImageBytes != null) {
        // Determine extension and content type
        String ext = 'jpg';
        String contentType = 'image/jpeg';
        if (_trailImageName != null) {
          final lower = _trailImageName!.toLowerCase();
          if (lower.endsWith('.png')) {
            ext = 'png';
            contentType = 'image/png';
          } else if (lower.endsWith('.webp')) {
            ext = 'webp';
            contentType = 'image/webp';
          } else if (lower.endsWith('.jpeg') || lower.endsWith('.jpg')) {
            ext = 'jpg';
            contentType = 'image/jpeg';
          }
        }
        imagePath = 'trail_covers/${docRef.id}.$ext';
        final storageRef = firebase_storage.FirebaseStorage.instance
            .ref()
            .child(imagePath);
        final metadata = firebase_storage.SettableMetadata(contentType: contentType);
        await storageRef.putData(_trailImageBytes!, metadata);
        // Removed: imageUrl = await storageRef.getDownloadURL();
      }

      final meta = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'location': _location?.trim(),
        'difficulty': _difficulty,
        'created_at': FieldValue.serverTimestamp(),
        'waypoint_count': _waypoints.length,
        'trackpoint_count': _trackPoints.length,
        'track_length_m': _trackLengthMeters.round(),
        'elevation_gain_m': _elevationGainMeters.round(),
        'time_to_complete_m': _timeToComplete,
        'image_path': imagePath,
        // Arrays of points
        'waypoints': _waypoints
            .map(
              (w) => {
                'lat': w.lat,
                'lon': w.lon,
                'ele': w.ele,
                'name': w.name,
                'distance_from_start_m': w.distanceFromStart,
              },
            )
            .toList(),
        'trackpoints': _trackPoints
            .map((p) => {'lat': p.lat, 'lon': p.lon, 'ele': p.ele})
            .toList(),
      };

      await docRef.set(meta);

      setState(
        () => _status = 'Uploaded trail (points + cover photo) to Firestore',
      );
    } catch (e, st) {
      debugPrint('Upload failed: $e\n$st');
      setState(() => _status = 'Upload failed: $e');
    }
  }

  // Map<String, dynamic>? _computeBboxMap() {
  //   if (_trackPoints.isEmpty && _waypoints.isEmpty) return null;

  //   final trackLats = _trackPoints.map((p) => p.lat).toList();
  //   final trackLons = _trackPoints.map((p) => p.lon).toList();
  //   final wayLats = _waypoints.map((w) => w.lat).toList();
  //   final wayLons = _waypoints.map((w) => w.lon).toList();

  //   final allLats = [...trackLats, ...wayLats];
  //   final allLons = [...trackLons, ...wayLons];

  //   final minLat = allLats.reduce(math.min);
  //   final maxLat = allLats.reduce(math.max);
  //   final minLon = allLons.reduce(math.min);
  //   final maxLon = allLons.reduce(math.max);
  //   return {
  //     'min_lat': minLat,
  //     'min_lon': minLon,
  //     'max_lat': maxLat,
  //     'max_lon': maxLon,
  //   };
  // }

  LatLng _toLatLngTrack(Trackpoint p) => LatLng(p.lat, p.lon);
  LatLng _toLatLngWay(Waypoint w) => LatLng(w.lat, w.lon);

  @override
  Widget build(BuildContext context) {
    final hasData = _trackPoints.isNotEmpty || _waypoints.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trail name',
                hintText: 'e.g., Cave Hill Loop',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Short description for this upload',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _pickAndParseGpx,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose GPX'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _pickTrailImage,
                  icon: const Icon(Icons.photo),
                  label: const Text('Add cover photo'),
                ),
                if (_firebaseReady)
                  FilledButton.tonalIcon(
                    onPressed: hasData ? _uploadToFirebase : null,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload to Firebase'),
                  ),
              ],
            ),
            if (_trailImageBytes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _trailImageBytes!,
                      height: 96,
                      width: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _trailImageName ?? 'cover_photo',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_status != null)
          Text(_status!, style: const TextStyle(fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildMap(),
          ),
        ),
        const SizedBox(height: 6),
        if (hasData)
          Text(
            'Waypoints: ${_waypoints.length} | Trackpoints: ${_trackPoints.length} | Length: ${(_trackLengthMeters / 1000).toStringAsFixed(2)} km',
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildMap() {
    // Ireland bounding box (approx): SW(51.386, -10.56) to NE(55.473, -5.34)
    final irelandBounds = LatLngBounds.fromPoints(const [
      LatLng(51.386, -10.56), // south-west
      LatLng(55.473, -5.34), // north-east
    ]);

    // Build bounds from current data if available
    final dataPoints = <LatLng>[
      ..._trackPoints.map((p) => LatLng(p.lat, p.lon)),
      ..._waypoints.map((w) => LatLng(w.lat, w.lon)),
    ];

    final hasData = dataPoints.isNotEmpty;
    final fit = hasData
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(dataPoints),
            padding: const EdgeInsets.all(24),
          )
        : CameraFit.bounds(
            bounds: irelandBounds,
            padding: const EdgeInsets.all(24),
          );

    final markers = _waypoints.map((p) {
      // Choose icon & color for auto points
      IconData icon = Icons.location_on;
      Color? color;
      if (p.name == 'Start') {
        icon = Icons.flag;
        color = Colors.green;
      } else if (p.name == 'Midpoint') {
        icon = Icons.adjust;
        color = Colors.orange;
      } else if (p.name == 'End') {
        icon = Icons.flag;
        color = Colors.red;
      } else {
        icon = Icons.circle;
        color = Colors.blue;
      }

      final title = (p.name.isNotEmpty) ? p.name : 'Waypoint';
      final distKm = (p.distanceFromStart / 1000).toStringAsFixed(2);

      return Marker(
        point: LatLng(p.lat, p.lon),
        width: 28,
        height: 28,
        child: Tooltip(
          message: '$title\n${p.lat.toStringAsFixed(5)}, ${p.lon.toStringAsFixed(5)}\n$distKm km from start',
          child: Icon(icon, size: 28, color: color),
        ),
      );
    }).toList();

    final polyline = Polyline(
      points: _trackPoints.map(_toLatLngTrack).toList(),
      color: Colors.red,
      strokeWidth: 4.0,
    );

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: fit,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        if (MAPBOX_ACCESS_TOKEN.isNotEmpty)
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/{id}/tiles/512/{z}/{x}/{y}@2x?access_token={accessToken}',
            additionalOptions: {
              'accessToken': MAPBOX_ACCESS_TOKEN,
              'id': 'mapbox/outdoors-v12',
            },
            userAgentPackageName: 'com.your.app',
            // ignore: deprecated_member_use
            tileSize: 512,
            zoomOffset: -1,
            maxNativeZoom: 22,
          )
        else
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.your.app',
            maxNativeZoom: 19,
          ),
        if (_trackPoints.isNotEmpty) PolylineLayer(polylines: [polyline]),
        if (_waypoints.isNotEmpty) MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              '© Mapbox © OpenStreetMap',
              onTap: () =>
                  launchUrl(Uri.parse('https://www.mapbox.com/about/maps/')),
            ),
            TextSourceAttribution(
              'Improve this map',
              onTap: () =>
                  launchUrl(Uri.parse('https://www.mapbox.com/map-feedback/')),
            ),
          ],
        ),
      ],
    );
  }
}

// Simple Haversine via latlong2 Distance class
class Distance {
  static const double _degToRad = math.pi / 180.0;
  static const double _earthRadius = 6371000.0; // meters

  double call(LatLng a, LatLng b) {
    final dLat = (b.latitude - a.latitude) * _degToRad;
    final dLon = (b.longitude - a.longitude) * _degToRad;
    final lat1 = a.latitude * _degToRad;
    final lat2 = b.latitude * _degToRad;

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return _earthRadius * c;
  }
}
