import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/trip_model.dart';
import '../data/repositories/trip_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository();
});

final tripProvider =
    FutureProvider<List<TripModel>>((ref) async {
  final repo = ref.read(tripRepositoryProvider);
  return repo.fetchTrips();
});