import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class RouteMapWidget extends StatefulWidget {

  final LatLng agentLocation;
  final LatLng passengerLocation;

  const RouteMapWidget({
    super.key,
    required this.agentLocation,
    required this.passengerLocation,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  MapLibreMapController? _controller;

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    _addAnnotations();
  }

  void _addAnnotations() async {
    if (_controller == null) return;

    // Add line between agent and passenger
    await _controller!.addLine(
      LineOptions(
        geometry: [widget.agentLocation, widget.passengerLocation],
        lineColor: '#2563EB',
        lineWidth: 5.0,
      ),
    );

    // Add agent marker (blue circle)
    await _controller!.addCircle(
      CircleOptions(
        geometry: widget.agentLocation,
        circleColor: '#2563EB',
        circleRadius: 12.0,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3.0,
      ),
    );

    // Add passenger marker (red circle)
    await _controller!.addCircle(
      CircleOptions(
        geometry: widget.passengerLocation,
        circleColor: '#EF4444',
        circleRadius: 12.0,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3.0,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: 'https://demotiles.maplibre.org/style.json',
      initialCameraPosition: CameraPosition(
        target: widget.agentLocation,
        zoom: 13.0,
      ),
      onMapCreated: _onMapCreated,
    );
  }
}