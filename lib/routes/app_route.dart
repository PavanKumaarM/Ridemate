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
import 'package:ridemate_app/features/notifications/screens/notifications_screen.dart';
import '../features/trip/screens/create_trip_screen.dart';
import '../features/trip/screens/trip_details_screen.dart';
import '../features/trip/screens/trip_tracking_screen.dart';
import '../features/trip/screens/trip_history_screen.dart';

import '../features/matching/screens/find_trip_screen.dart';

import '../features/profile/screens/profile_screen.dart';

class AppRouter {

  static FutureOr<String?> redirect(BuildContext context, GoRouterState state) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null;
    final isAuthPage = state.uri.toString() == '/login' || state.uri.toString() == '/signup';

    if (!isAuthenticated && !isAuthPage) return '/login';
    if (isAuthenticated && isAuthPage) return '/home';
    return null;
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