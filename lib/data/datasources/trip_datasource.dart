import '../../core/services/supabase_service.dart';
import '../models/trip_model.dart';

class TripDatasource {

  final client = SupabaseService.client;

  Future<List<TripModel>> getTrips() async {

    final response = await client
        .from('trips')
        .select();

    return (response as List)
        .map((e)=>TripModel.fromJson(e))
        .toList();
  }

  Future<void> createTrip(Map<String,dynamic> data) async {

    await client.from('trips').insert(data);

  }

}