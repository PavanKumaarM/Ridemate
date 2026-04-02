import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../widgets/route_map_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  final LatLng agentLocation =
      const LatLng(13.0827, 80.2707); // Chennai example

  final LatLng passengerLocation =
      const LatLng(13.0674, 80.2376);

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Trip Map"),
      ),

      body: RouteMapWidget(
        agentLocation: agentLocation,
        passengerLocation: passengerLocation,
      ),
    );
  }
}