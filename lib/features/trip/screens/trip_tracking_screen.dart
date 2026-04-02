import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class TripTrackingScreen extends StatefulWidget {
  const TripTrackingScreen({super.key});

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  MapLibreMapController? _controller;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Tracking"),
      ),
      body: MapLibreMap(
        styleString: 'https://demotiles.maplibre.org/style.json',
        initialCameraPosition: const CameraPosition(
          target: LatLng(12.9716, 77.5946),
          zoom: 14.0,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}