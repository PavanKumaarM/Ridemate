import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for streaming live location updates during a trip.
/// Used by the host (driver) to broadcast their location to passengers.
class LiveLocationService {
  static final LiveLocationService _instance = LiveLocationService._internal();
  factory LiveLocationService() => _instance;
  LiveLocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _updateTimer;
  String? _currentTripId;

  /// Start streaming location updates for a trip
  /// Call this when the trip starts (host side)
  Future<void> startLocationStreaming(String tripId) async {
    _currentTripId = tripId;

    // Request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions permanently denied');
    }

    // Start listening to location updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(_onLocationUpdate);

    // Also update every 5 seconds as a fallback
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final position = await Geolocator.getCurrentPosition();
      _updateLocation(tripId, position.latitude, position.longitude);
    });
  }

  void _onLocationUpdate(Position position) {
    if (_currentTripId != null) {
      _updateLocation(_currentTripId!, position.latitude, position.longitude);
    }
  }

  Future<void> _updateLocation(String tripId, double lat, double lng) async {
    try {
      await Supabase.instance.client
          .from('trips')
          .update({
            'current_lat': lat,
            'current_lng': lng,
            'location_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId);
    } catch (e) {
      // Silently handle errors - don't crash the app if update fails
      print('Failed to update location: $e');
    }
  }

  /// Stop streaming location updates
  /// Call this when the trip ends (host side)
  void stopLocationStreaming() {
    _positionStream?.cancel();
    _positionStream = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    _currentTripId = null;
  }

  /// Subscribe to live location updates for a trip
  /// Returns a stream of location updates (passenger side)
  Stream<Map<String, dynamic>> subscribeToTripLocation(String tripId) {
    return Supabase.instance.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((data) {
          if (data.isEmpty) return {};
          final trip = data.first;
          return {
            'lat': trip['current_lat'],
            'lng': trip['current_lng'],
            'updatedAt': trip['location_updated_at'],
            'status': trip['status'],
          };
        });
  }

  /// Get the current location once
  static Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Stream passenger location to bookings table
  /// Call this when passenger books a trip and is waiting for pickup
  StreamSubscription<Position>? startPassengerLocationStreaming(String bookingId) {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      try {
        await Supabase.instance.client
            .from('bookings')
            .update({
              'passenger_lat': position.latitude,
              'passenger_lng': position.longitude,
              'location_updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId);
      } catch (e) {
        print('Failed to update passenger location: $e');
      }
    });
  }

  /// Returns stream of passenger locations (for host)
  Stream<List<Map<String, dynamic>>> subscribeToPassengerLocations(String tripId) {
    return Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .map((bookings) {
          return bookings
              .where((b) =>
                  b['trip_id'] == tripId &&
                  b['status'] == 'confirmed' &&
                  b['passenger_lat'] != null &&
                  b['passenger_lng'] != null)
              .map((b) => {
                    'bookingId': b['id'],
                    'passengerId': b['passenger_id'],
                    'lat': b['passenger_lat'],
                    'lng': b['passenger_lng'],
                    'updatedAt': b['location_updated_at'],
                  })
              .toList();
        });
  }
}
