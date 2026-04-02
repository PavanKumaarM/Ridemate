import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../core/services/supabase_service.dart';

final rideRequestProvider =
    StateNotifierProvider<RideRequestNotifier, bool>((ref) {
  return RideRequestNotifier();
});

class RideRequestNotifier extends StateNotifier<bool> {
  RideRequestNotifier() : super(false);

  final client = SupabaseService.client;

  Future<void> requestRide(
      String tripId,
      String passengerId) async {

    state = true;

    await client.from('ride_requests').insert({
      "trip_id": tripId,
      "passenger_id": passengerId
    });

    state = false;
  }
}