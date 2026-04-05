import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ridemate_app/data/models/trip_model.dart';
import 'package:ridemate_app/features/dashboard/available_companions_screen.dart';
import 'package:ridemate_app/features/home/screens/dashboard_screen.dart';
import 'package:ridemate_app/features/payement/screens/payment_screen.dart';
import 'package:ridemate_app/features/payement/screens/payment_success_screen.dart';
import 'package:ridemate_app/features/profile/screens/edit_profile_screen.dart';
import 'package:ridemate_app/features/auth/screens/login_screen.dart';
import 'package:ridemate_app/features/auth/screens/signup_screen.dart';


import 'package:ridemate_app/features/home/screens/home_shell.dart';
import 'package:ridemate_app/features/trip/screens/my_trips_screen.dart';
import 'package:ridemate_app/features/trip/screens/available_trips_screen.dart';

import 'package:ridemate_app/features/trip/screens/book_trip_screen.dart';
import 'package:ridemate_app/features/trip/screens/live_tracking_screen.dart';
import 'package:ridemate_app/features/notifications/screens/notifications_screen.dart';
import '../features/trip/screens/create_trip_screen.dart';
import '../features/trip/screens/trip_details_screen.dart';
import '../features/trip/screens/trip_tracking_screen.dart';
import '../features/trip/screens/trip_history_screen.dart';

import '../features/matching/screens/find_trip_screen.dart';

import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/profile_setup_screen.dart';
import '../features/profile/screens/verification_pending_screen.dart';
import '../features/profile/screens/verification_rejected_screen.dart';

class AppRouter {

  static Future<String?> redirect(BuildContext context, GoRouterState state) async {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null;
    final path = state.uri.toString();
    final isAuthPage = path == '/login' || path == '/signup';
    final isProfileSetupPage = path == '/profileSetup';
    final isVerificationPage = path == '/verificationPending';
    final isRejectedPage = path == '/verificationRejected';

    // Not authenticated - go to login
    if (!isAuthenticated && !isAuthPage) return '/login';
    
    // Authenticated but on auth page - check profile and verification
    if (isAuthenticated && isAuthPage) {
      final userData = await _getUserData(user.id);
      if (userData == null || userData['is_profile_complete'] != true) {
        return '/profileSetup';
      }
      if (userData['status'] == 'rejected') {
        return '/verificationRejected';
      }
      if (userData['status'] != 'verified') {
        return '/verificationPending';
      }
      return '/home';
    }

    // Allow profile setup, pending and rejected pages
    if (isAuthenticated && (isProfileSetupPage || isVerificationPage || isRejectedPage)) return null;

    // Authenticated - check if allowed to access home
    if (isAuthenticated) {
      final userData = await _getUserData(user.id);
      if (userData == null || userData['is_profile_complete'] != true) {
        return '/profileSetup';
      }
      if (userData['status'] == 'rejected') {
        return '/verificationRejected';
      }
      if (userData['status'] != 'verified') {
        return '/verificationPending';
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('is_profile_complete, status')
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  static final GoRouter router = GoRouter(
    initialLocation: "/login",
    redirect: redirect,
    routes: [
      GoRoute(
        path: "/availableTrips",
        builder: (context,state) =>
            const AvailableCompanionsScreen(),
      ),
       GoRoute(
        path: "/dashboard",
        builder: (context,state) =>
            const DashboardScreen(),
      ),

      GoRoute(
        path: "/profileSetup",
        builder: (context, state) => const EditProfileScreen(),
      ),

      // Shell route for home with bottom navigation
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home/myTrips',
            builder: (context, state) => const MyTripsScreen(),
          ),
          GoRoute(
            path: '/home/availableTrips',
            builder: (context, state) => const AvailableTripsScreen(),
          ),
        ],
      ),

      // Legacy redirect from /home to /home/myTrips
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/home/myTrips',
      ),

      GoRoute(
        path: "/createTrip",
        builder: (context, state) => const CreateTripScreen(),
      ),

      GoRoute(
        path: "/tripDetails",
        builder: (context, state) {
          final extra = state.extra;
          final args = extra is TripDetailsArgs
              ? extra
              : TripDetailsArgs(
                  trip: extra as TripModel,
                  isCreator: true,
                );
          return TripDetailsScreen(args: args);
        },
      ),

      GoRoute(
        path: "/bookTrip",
        builder: (context, state) => BookTripScreen(trip: state.extra as TripModel),
      ),

      GoRoute(
        path: "/notifications",
        builder: (context, state) => const NotificationsScreen(),
      ),

      GoRoute(
        path: "/tripTracking",
        builder: (context, state) => const TripTrackingScreen(),
      ),

      GoRoute(
        path: "/liveTracking",
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return LiveTrackingScreen(
            trip: args['trip'] as TripModel,
            isHost: args['isHost'] as bool,
          );
        },
      ),

      GoRoute(
        path: "/tripHistory",
        builder: (context, state) => const TripHistoryScreen(),
      ),

      GoRoute(
        path: "/findTrip",
        builder: (context, state) => const FindTripScreen(),
      ),

      GoRoute(
        path: "/payment",
        builder: (context, state) => PaymentScreen(
          tripId: state.extra as String,
          payerId: '',
          fare: 0,
        ),
      ),

      GoRoute(
        path: "/paymentSuccess",
        builder: (context, state) => const PaymentSuccessScreen(),
      ),

      GoRoute(
        path: "/profile",
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: "/profileSetup",
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: "/verificationPending",
        builder: (context, state) => const VerificationPendingScreen(),
      ),
      GoRoute(
        path: "/verificationRejected",
        builder: (context, state) => const VerificationRejectedScreen(),
      ),
      GoRoute(
        path: "/login",
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: "/signup",
        builder: (context, state) => const SignupScreen(),
      ),

    ],
  );

}