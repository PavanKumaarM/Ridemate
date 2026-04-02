import 'package:maplibre_gl/maplibre_gl.dart';

/// Creates a CircleOptions for the agent location (blue circle with white border)
CircleOptions createAgentMarker(LatLng position) {
  return CircleOptions(
    geometry: position,
    circleColor: '#2563EB',
    circleRadius: 12.0,
    circleStrokeColor: '#FFFFFF',
    circleStrokeWidth: 3.0,
  );
}