import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

class SupabaseAuthDatasource {

  final client = SupabaseService.client;

  Future<void> signInWithPhone(String phone) async {

    await client.auth.signInWithOtp(
      phone: phone,
    );

  }

  Future<void> verifyOtp(String phone,String token) async {

    await client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );

  }

}