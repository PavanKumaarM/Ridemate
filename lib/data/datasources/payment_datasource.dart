import '../../core/services/supabase_service.dart';

class PaymentDatasource {

  final client = SupabaseService.client;

  Future<void> createPayment(Map<String,dynamic> data) async {

    await client.from('payments').insert(data);

  }

}