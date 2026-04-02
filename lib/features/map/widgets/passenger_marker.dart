import 'package:maplibre_gl/maplibre_gl.dart';

/// Creates a CircleOptions for the passenger location (red circle with white border)
CircleOptions createPassengerMarker(LatLng position) {
  return CircleOptions(
    geometry: position,
    circleColor: '#EF4444',
    circleRadius: 12.0,
    circleStrokeColor: '#FFFFFF',
    circleStrokeWidth: 3.0,
  );
}