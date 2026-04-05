import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/trip_model.dart';

/// Mixin that automatically navigates passengers to live tracking
/// when their booking is accepted by the host.
/// 
/// Add this to screens where passengers should auto-redirect:
/// class MyScreen extends StatefulWidget with PassengerLiveTrackingMixin
/// 
/// Or use as a widget that listens in the background.
class LiveTrackingRedirector extends StatefulWidget {
  final Widget child;
  
  const LiveTrackingRedirector({super.key, required this.child});
  
  @override
  State<LiveTrackingRedirector> createState() => _LiveTrackingRedirectorState();
}

class _LiveTrackingRedirectorState extends State<LiveTrackingRedirector> {
  StreamSubscription? _bookingsSubscription;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    _startListeningForAcceptedBookings();
  }

  void _startListeningForAcceptedBookings() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Listen for accepted bookings with trips in 'in_progress' status
    _bookingsSubscription = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .listen((bookings) async {
          if (_hasRedirected || bookings.isEmpty) return;

          // Filter for this user's accepted bookings
          final userAcceptedBookings = bookings.where(
            (b) => b['passenger_id'] == user.id && b['status'] == 'accepted'
          ).toList();
          
          if (userAcceptedBookings.isEmpty) return;

          // Check if the trip is now in_progress
          final booking = userAcceptedBookings.first;
          final tripId = booking['trip_id'] as String?;
          
          if (tripId == null) return;

          try {
            final tripResponse = await Supabase.instance.client
                .from('trips')
                .select()
                .eq('id', tripId)
                .eq('status', 'in_progress')
                .single();

            final trip = TripModel.fromJson(tripResponse);
            
            _hasRedirected = true; // Prevent multiple redirects
            
            // Show a snackbar first
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your ride is starting! Joining live tracking...'),
                duration: Duration(seconds: 2),
              ),
            );

            // Wait a moment then navigate
            await Future.delayed(const Duration(seconds: 2));
            
            if (mounted) {
              context.push('/liveTracking', extra: {
                'trip': trip,
                'isHost': false,
              });
            }
          } catch (e) {
            // Trip not in progress yet, ignore
          }
        });
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
