import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ridemate_app/data/models/trip_model.dart';

class AvailableTripsScreen extends StatefulWidget {
  const AvailableTripsScreen({super.key});

  @override
  State<AvailableTripsScreen> createState() => _AvailableTripsScreenState();
}

class _AvailableTripsScreenState extends State<AvailableTripsScreen> {
  List<TripModel> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableTrips();
  }

  Future<void> _fetchAvailableTrips() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Get IDs of trips already booked by current user
      final bookedTripIds = <String>{};
      if (user != null) {
        final bookingsResponse = await Supabase.instance.client
            .from('bookings')
            .select('trip_id')
            .eq('booker_id', user.id)
            .inFilter('status', ['pending', 'accepted']);
        
        bookedTripIds.addAll(
          (bookingsResponse as List).map((b) => b['trip_id'] as String),
        );
      }

      // Get IDs of trips that have accepted bookings (hide from everyone)
      final acceptedBookingsResponse = await Supabase.instance.client
          .from('bookings')
          .select('trip_id')
          .eq('status', 'accepted');
      
      final acceptedTripIds = (acceptedBookingsResponse as List)
          .map((b) => b['trip_id'] as String)
          .toSet();

      final response = await Supabase.instance.client
          .from('trips')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false);

      setState(() {
        _trips = (response as List)
            .map((json) => TripModel.fromJson(json))
            .where((trip) => 
                trip.agentId != user?.id && // Exclude user's own trips
                !bookedTripIds.contains(trip.id) && // Exclude already booked by current user
                !acceptedTripIds.contains(trip.id)) // Exclude trips accepted by anyone
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trips: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No available trips',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later or post your own trip!',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAvailableTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (context, index) {
          final trip = _trips[index];
          return _TripCard(
            trip: trip,
            onTap: () => context.push('/bookTrip', extra: trip),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;

  const _TripCard({required this.trip, required this.onTap});

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
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'AVAILABLE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
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
                    '${trip.availableSeats} seats available',
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
