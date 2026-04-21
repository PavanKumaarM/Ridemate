import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Service for handling free SMS OTP using Firebase Phone Authentication
/// 
/// Firebase Phone Auth provides free tier:
/// - 10,000 verifications/month for Indian numbers
/// - No charges for failed attempts
/// - Reliable SMS delivery
class FirebaseOtpService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? _verificationId;
  static int? _resendToken;

  /// Send OTP to phone number
  /// Returns true if OTP sent successfully
  static Future<bool> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          onAutoVerified(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
      return true;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      return false;
    }
  }

  /// Verify the entered OTP code
  /// Returns UserCredential if successful, null if failed
  static Future<UserCredential?> verifyOtp(String smsCode) async {
    if (_verificationId == null) {
      throw Exception('Verification ID not found. Please request OTP first.');
    }

    try {
      // Create credential
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Sign in with credential
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error verifying OTP: ${e.message}');
      throw Exception(e.message ?? 'Invalid OTP code');
    }
  }

  /// Resend OTP to the same phone number
  static Future<bool> resendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException error) onError,
  }) async {
    if (_resendToken == null) {
      return false;
    }

    return sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      onAutoVerified: (_) {},
    );
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;
}
