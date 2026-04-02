import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationProvider =
    FutureProvider<Position>((ref) async {
  return Geolocator.getCurrentPosition();
});