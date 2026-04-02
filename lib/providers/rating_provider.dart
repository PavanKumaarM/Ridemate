import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/repositories/rating_repository.dart';

final ratingRepositoryProvider =
    Provider<RatingRepository>((ref) {
  return RatingRepository();
});

final ratingProvider =
    StateNotifierProvider<RatingNotifier, bool>((ref) {
  return RatingNotifier(ref.read(ratingRepositoryProvider));
});

class RatingNotifier extends StateNotifier<bool> {
  final RatingRepository repository;

  RatingNotifier(this.repository) : super(false);

  Future<void> submitRating(Map<String, dynamic> data) async {
    state = true;

    await repository.submitRating(data);

    state = false;
  }
}