import '../../core/services/supabase_service.dart';

class RatingRepository {

  final client = SupabaseService.client;

  Future<void> submitRating(Map<String,dynamic> data) async {

    await client.from('ratings').insert(data);

  }

}