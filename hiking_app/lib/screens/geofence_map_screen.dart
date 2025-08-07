import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:hiking_app/models/trail_geofence.dart';
import 'package:hiking_app/providers/trail_geofence_service.dart';
import 'package:hiking_app/utilities/maping_utils.dart';

class GeofenceMapScreen extends StatefulWidget {
  const GeofenceMapScreen({super.key});

  @override
  State<GeofenceMapScreen> createState() => _GeofenceMapScreenState();
}

class _GeofenceMapScreenState extends State<GeofenceMapScreen> {
  MapboxMap? _mapboxMapController;
  final TrailGeofenceService _geofenceService = TrailGeofenceService();
  final List<TrailGeofence> _trailGeofences = [];

  @override
  void initState() {
    super.initState();
    _setupGeofences();
    _listenToGeofenceEvents();
  }

  void _setupGeofences() {
    // Example geofences for demonstration
    final geofences = [
      TrailGeofence(
        id: 'start',
        name: 'Trail Start',
        center: LatLng(37.7749, -122.4194), // San Francisco
        radius: 100.0,
        description: 'Starting point of the trail',
        type: GeofenceType.trailStart,
      ),
      TrailGeofence(
        id: 'waypoint1',
        name: 'Scenic Overlook',
        center: LatLng(37.7849, -122.4094),
        radius: 75.0,
        description: 'Beautiful scenic overlook',
        type: GeofenceType.waypoint,
      ),
      TrailGeofence(
        id: 'rest_area',
        name: 'Rest Area',
        center: LatLng(37.7949, -122.3994),
        radius: 50.0,
        description: 'Rest and hydration point',
        type: GeofenceType.restArea,
      ),
      TrailGeofence(
        id: 'end',
        name: 'Trail End',
        center: LatLng(37.8049, -122.3894),
        radius: 100.0,
        description: 'End point of the trail',
        type: GeofenceType.trailEnd,
      ),
    ];

    _trailGeofences.addAll(geofences);
    
    // Add to geofence service
    for (final geofence in geofences) {
      _geofenceService.addGeofence(geofence);
    }
  }

  void _listenToGeofenceEvents() {
    _geofenceService.eventStream.listen((event) {
      _showGeofenceAlert(event);
      _updateGeofenceVisualization(event);
    });
  }

  void _showGeofenceAlert(GeofenceEvent event) {
    final message = event.eventType == GeofenceEventType.enter
        ? 'Entered ${event.geofence.name}'
        : 'Exited ${event.geofence.name}';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: event.eventType == GeofenceEventType.enter
            ? Colors.green
            : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _updateGeofenceVisualization(GeofenceEvent event) {
    if (_mapboxMapController == null) return;

    if (event.eventType == GeofenceEventType.enter) {
      // Highlight active geofence
      highlightActiveGeofence(_mapboxMapController!, event.geofence);
    } else {
      // Return to normal colors
      addGeofenceCircle(_mapboxMapController!, event.geofence);
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMapController = mapboxMap;
    
    // Add geofence visualizations to map
    await _addGeofencesToMap();
    
    // Set camera to show all geofences
    await _setCameraToShowAllGeofences();
  }

  Future<void> _addGeofencesToMap() async {
    if (_mapboxMapController == null) return;

    // Add all geofences to map with different colors based on type
    for (final geofence in _trailGeofences) {
      final colors = _getColorsForGeofenceType(geofence.type);
      
      await addGeofenceCircle(
        _mapboxMapController!,
        geofence,
        fillColor: colors['fill']!,
        borderColor: colors['border']!,
        borderWidth: 2.0,
      );
      
      // Add center marker
      await addGeofenceCenterMarker(_mapboxMapController!, geofence);
    }
  }

  Map<String, int> _getColorsForGeofenceType(GeofenceType type) {
    switch (type) {
      case GeofenceType.trailStart:
        return {'fill': 0x4000FF00, 'border': 0xFF00FF00}; // Green
      case GeofenceType.trailEnd:
        return {'fill': 0x40FF0000, 'border': 0xFFFF0000}; // Red
      case GeofenceType.waypoint:
        return {'fill': 0x400000FF, 'border': 0xFF0000FF}; // Blue
      case GeofenceType.restArea:
        return {'fill': 0x40FFFF00, 'border': 0xFFFFFF00}; // Yellow
      case GeofenceType.dangerZone:
        return {'fill': 0x40FF8000, 'border': 0xFFFF8000}; // Orange
      default:
        return {'fill': 0x40808080, 'border': 0xFF808080}; // Gray
    }
  }

  Future<void> _setCameraToShowAllGeofences() async {
    if (_mapboxMapController == null || _trailGeofences.isEmpty) return;

    final points = _trailGeofences.map((g) => 
      Point(coordinates: Position(g.center.longitude, g.center.latitude))
    ).toList();
    
    await cameraBoundsFromPoints(_mapboxMapController!, points);
  }

  void _toggleGeofenceMonitoring() async {
    try {
      if (_geofenceService.isMonitoring) {
        await _geofenceService.stopMonitoring();
      } else {
        await _geofenceService.startMonitoring();
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _simulateMovement() {
    // Simulate movement to first geofence for testing
    if (_trailGeofences.isNotEmpty) {
      final firstGeofence = _trailGeofences.first;
      // Simulate being at the geofence location
      _geofenceService.simulateGeofenceEvent(GeofenceEvent(
        geofence: firstGeofence,
        eventType: GeofenceEventType.enter,
        location: firstGeofence.center,
        timestamp: DateTime.now(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Trail Map'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListenableBuilder(
                      listenable: _geofenceService,
                      builder: (context, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Geofence Status: ${_geofenceService.isMonitoring ? "Monitoring" : "Stopped"}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text('Active Geofences: ${_geofenceService.activeGeofences.length}'),
                            if (_geofenceService.activeGeofences.isNotEmpty)
                              Text('Current: ${_geofenceService.getActiveGeofenceObjects().map((g) => g.name).join(", ")}'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _toggleGeofenceMonitoring,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _geofenceService.isMonitoring 
                                          ? Colors.red 
                                          : Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(_geofenceService.isMonitoring 
                                        ? 'Stop Monitoring' 
                                        : 'Start Monitoring'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _simulateMovement,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Test Movement'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _geofenceService.dispose();
    super.dispose();
  }
}
