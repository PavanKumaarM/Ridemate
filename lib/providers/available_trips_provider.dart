import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ridemate_app/providers/trip_provider.dart';
import '../data/models/trip_model.dart';
import '../data/repositories/trip_repository.dart';

final availableTripsProvider =
    FutureProvider<List<TripModel>>((ref) async {
  final repo = ref.read(tripRepositoryProvider);
  return repo.fetchTrips();
});