import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ridemate_app/providers/trip_provider.dart';
import '../data/repositories/trip_repository.dart';

final createTripProvider =
    StateNotifierProvider<CreateTripNotifier, bool>((ref) {
  return CreateTripNotifier(ref.read(tripRepositoryProvider));
});

class CreateTripNotifier extends StateNotifier<bool> {
  final TripRepository repository;

  CreateTripNotifier(this.repository) : super(false);

  Future<void> createTrip(Map<String, dynamic> data) async {
    state = true;

    await repository.createTrip(data);

    state = false;
  }
}