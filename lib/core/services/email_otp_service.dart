import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Free Email-based OTP Service
/// 
/// Sends OTP via email using Supabase's built-in email functionality
/// Completely FREE - no SMS charges
class EmailOtpService {
  static final _supabase = Supabase.instance.client;

  /// Generate a random 6-digit OTP
  static String generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send OTP to user's email via Supabase
  /// Returns true if email sent successfully
  static Future<bool> sendOtpToEmail({
    required String userId,
    required String email,
    required String otp,
    required String tripId,
  }) async {
    try {
      // Store OTP in database with expiration
      final expiresAt = DateTime.now().add(const Duration(minutes: 10));
      
      await _supabase.from('email_otp_codes').upsert({
        'user_id': userId,
        'trip_id': tripId,
        'otp_code': otp,
        'email': email,
        'expires_at': expiresAt.toIso8601String(),
        'verified': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send email using Supabase Edge Function or direct email
      // Using Supabase's built-in auth email template or custom RPC
      await _supabase.rpc('send_otp_email', params: {
        'to_email': email,
        'otp_code': otp,
        'trip_id': tripId,
      });

      return true;
    } catch (e) {
      debugPrint('Error sending email OTP: $e');
      return false;
    }
  }

  /// Verify the OTP entered by host
  static Future<bool> verifyOtp({
    required String tripId,
    required String otp,
  }) async {
    try {
      final response = await _supabase
          .from('email_otp_codes')
          .select()
          .eq('trip_id', tripId)
          .eq('otp_code', otp)
          .eq('verified', false)
          .maybeSingle();

      if (response == null) {
        return false;
      }

      // Check if OTP expired
      final expiresAt = DateTime.parse(response['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        return false;
      }

      // Mark OTP as verified
      await _supabase
          .from('email_otp_codes')
          .update({'verified': true, 'verified_at': DateTime.now().toIso8601String()})
          .eq('id', response['id']);

      return true;
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return false;
    }
  }

  /// Alternative: Store OTP directly in trips table (simpler approach)
  static Future<bool> storeOtpInTrip({
    required String tripId,
    required String otp,
  }) async {
    try {
      await _supabase.from('trips').update({
        'otp_code': otp,
        'otp_generated_at': DateTime.now().toIso8601String(),
        'otp_expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
      }).eq('id', tripId);

      return true;
    } catch (e) {
      debugPrint('Error storing OTP: $e');
      return false;
    }
  }
}

/// Alternative FREE OTP using WhatsApp (if user prefers)
/// Uses WhatsApp Business API free tier or WhatsApp Web API
class WhatsAppOtpService {
  /// Generate WhatsApp click-to-chat link with OTP message
  static String generateWhatsAppLink({
    required String phoneNumber,
    required String otp,
    required String tripId,
  }) {
    // Format: https://wa.me/<number>?text=<message>
    final message = Uri.encodeComponent(
      'Hello! Your RideMate OTP for trip #$tripId is: $otp\n\n'
      'Please share this code with your driver to start the trip.\n\n'
      'This code expires in 10 minutes.'
    );
    
    // Remove + and spaces from phone number
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\+\s]'), '');
    return 'https://wa.me/$cleanNumber?text=$message';
  }

  /// Generate OTP message for any messaging platform
  static String generateOtpMessage({
    required String otp,
    required String tripId,
    required String passengerName,
  }) {
    return '''🚗 RideMate Trip OTP

Hello $passengerName,

Your OTP for trip #$tripId is: $otp

Share this code with your driver to start the trip.

⏰ This code expires in 10 minutes.
🚫 Do not share this code with anyone else.

Thank you for using RideMate!''';}
}
