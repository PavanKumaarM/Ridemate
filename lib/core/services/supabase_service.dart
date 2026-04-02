import 'package:ridemate_app/core/constraints/api_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class SupabaseService {
 static SupabaseClient get client =>
      Supabase.instance.client;
  static Future<void> initialize() async {

    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      anonKey: ApiConstants.supabaseAnonKey,
    );

  }

}
