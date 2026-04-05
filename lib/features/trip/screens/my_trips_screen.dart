import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ridemate_app/data/models/trip_model.dart';
import 'package:ridemate_app/data/models/booking_model.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  List<TripModel> _myTrips = [];
  Map<String, List<BookingModel>> _tripBookings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyTripsWithBookings();
  }

  Future<void> _fetchMyTripsWithBookings() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Clear existing data first to force UI update
      setState(() {
        _myTrips = [];
        _tripBookings = {};
      });

      // Fetch only active trips
      final tripsResponse = await Supabase.instance.client
          .from('trips')
          .select()
          .eq('agent_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final trips = (tripsResponse as List)
          .map((json) => TripModel.fromJson(json))
          .toList();

      debugPrint('Fetched ${trips.length} active trips for user ${user.id}');

      // Fetch bookings for all trips
      final bookingsMap = <String, List<BookingModel>>{};
      for (final trip in trips) {
        final bookingsResponse = await Supabase.instance.client
            .from('bookings')
            .select('*, trips(*)')
            .eq('trip_id', trip.id)
            .order('created_at', ascending: false);

        bookingsMap[trip.id] = (bookingsResponse as List)
            .map((json) => BookingModel.fromJson(json))
            .toList();
      }

      if (mounted) {
        setState(() {
          _myTrips = trips;
          _tripBookings = bookingsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trips: $e')),
        );
      }
    }
  }

  Future<void> _acceptBooking(BookingModel booking) async {
    try {
      // Get trip data before removing from list
      final trip = _myTrips.firstWhere((t) => t.id == booking.tripId);

      // Immediately remove the trip from local list for instant feedback
      setState(() {
        _myTrips.removeWhere((t) => t.id == booking.tripId);
        _tripBookings.remove(booking.tripId);
      });

      // Update booking status to accepted
      await Supabase.instance.client
          .from('bookings')
          .update({'status': 'accepted'})
          .eq('id', booking.id);

      // Update trip status to 'in_progress' instead of 'completed'
      await Supabase.instance.client
          .from('trips')
          .update({'status': 'in_progress'})
          .eq('id', booking.tripId);

      // Send notification to booker
      await Supabase.instance.client.from('notifications').insert({
        'user_id': booking.bookerId,
        'type': 'booking_accepted',
        'title': 'Booking Accepted!',
        'message': 'Your booking request has been accepted. The trip is starting now!',
        'data': {
          'trip_id': booking.tripId,
          'booking_id': booking.id,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking accepted! Starting live tracking...')),
        );

        // Navigate to live tracking screen for host
        context.push('/liveTracking', extra: {
          'trip': trip,
          'isHost': true,
        });
      }
    } catch (e) {
      debugPrint('Error accepting booking: $e');
      // Refresh to restore the trip if there was an error
      await _fetchMyTripsWithBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept booking: $e')),
        );
      }
    }
  }

  Future<void> _rejectBooking(BookingModel booking) async {
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'status': 'rejected'})
          .eq('id', booking.id);

      // Send notification to booker
      await Supabase.instance.client.from('notifications').insert({
        'user_id': booking.bookerId,
        'type': 'booking_rejected',
        'title': 'Booking Rejected',
        'message': 'Your booking request was rejected by the trip host.',
        'data': {
          'trip_id': booking.tripId,
          'booking_id': booking.id,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking rejected. Notification sent to rider.')),
        );
      }

      await _fetchMyTripsWithBookings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject booking: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myTrips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_taxi_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No trips posted yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.push('/createTrip'),
              child: const Text('Post Your First Trip'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyTripsWithBookings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTrips.length,
        itemBuilder: (context, index) {
          final trip = _myTrips[index];
          final bookings = _tripBookings[trip.id] ?? [];
          final pendingBookings = bookings.where((b) => b.status == 'pending').toList();

          return Column(
            children: [
              _TripCard(
                trip: trip,
                pendingCount: pendingBookings.length,
                onTap: () => context.push('/tripDetails', extra: trip),
              ),
              // Show pending booking requests
              ...pendingBookings.map((booking) => _BookingRequestCard(
                booking: booking,
                onAccept: () => _acceptBooking(booking),
                onReject: () => _rejectBooking(booking),
              )),
            ],
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;
  final int pendingCount;

  const _TripCard({required this.trip, required this.onTap, this.pendingCount = 0});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: trip.status == 'active'
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trip.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: trip.status == 'active'
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pendingCount PENDING',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '₹${trip.basePrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.startAddress,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.destAddress,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.event_seat, color: Colors.grey.shade600, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${trip.availableSeats} seats',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, color: Colors.grey.shade600, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(trip.departureTime),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _BookingRequestCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _BookingRequestCard({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Booking Request',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Seats: ${booking.seatsBooked} • Fare: ₹${booking.totalFare.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
