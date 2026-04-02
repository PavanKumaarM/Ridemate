import '../../core/services/supabase_service.dart';

class ChatDatasource {

  final client = SupabaseService.client;

  Future<void> sendMessage(Map<String,dynamic> data) async {

    await client.from('messages').insert(data);

  }

  Future<List<Map<String,dynamic>>> getMessages(String tripId) async {

    final response = await client.from('messages').select().eq('trip_id', tripId);

    return response;

  }

}