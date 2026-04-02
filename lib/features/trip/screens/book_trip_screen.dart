import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/trip_model.dart';

class BookTripScreen extends StatefulWidget {
  final TripModel trip;

  const BookTripScreen({super.key, required this.trip});

  @override
  State<BookTripScreen> createState() => _BookTripScreenState();
}

class _BookTripScreenState extends State<BookTripScreen> {
  bool _isLoading = false;

  Future<void> _bookTrip() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Ensure user exists in users table before creating booking
      await Supabase.instance.client.from('users').upsert({
        'id': currentUser.id,
      });

      // Ensure host exists in users table (for notification foreign key)
      await Supabase.instance.client.from('users').upsert({
        'id': widget.trip.agentId,
      });

      // 1. Create booking record
      final bookingResponse = await Supabase.instance.client
          .from('bookings')
          .insert({
            'trip_id': widget.trip.id,
            'booker_id': currentUser.id,
            'host_id': widget.trip.agentId,
            'status': 'pending',
            'seats_booked': 1,
            'total_fare': widget.trip.basePrice,
          })
          .select()
          .single();

      // 2. Create notification for the host
      try {
        await Supabase.instance.client.from('notifications').insert({
          'user_id': widget.trip.agentId,
          'type': 'booking_request',
          'title': 'New Booking Request',
          'message': 'Someone wants to book your trip from ${widget.trip.startAddress} to ${widget.trip.destAddress}',
          'data': {
            'trip_id': widget.trip.id,
            'booking_id': bookingResponse['id'],
            'booker_id': currentUser.id,
          },
        });
      } catch (notificationError) {
        // Log notification error but don't fail the booking
        debugPrint('Failed to create notification: $notificationError');
      }

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Request Sent!'),
              ],
            ),
            content: const Text(
              'Your booking request has been sent to the trip host. You will be notified when they accept your request.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/home/availableTrips');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to book trip try again: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Book Trip',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── TRIP HOST CARD ────────────────────────────────────────────
            _HostCard(trip: widget.trip),

            const SizedBox(height: 16),

            // ── TRIP INFO CARD ────────────────────────────────────────────
            _TripInfoCard(trip: widget.trip),

            const SizedBox(height: 16),

            // ── BOOK TRIP BUTTON ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _bookTrip,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Book Trip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Host profile card — shows trip creator info
// ─────────────────────────────────────────────────────────────────────────────
class _HostCard extends StatelessWidget {
  final TripModel trip;

  const _HostCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    const double rating = 4.8;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ────────────────────────────────────────────────
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFE0E7FF),
            child: const Icon(
              Icons.directions_car,
              size: 34,
              color: Color(0xFF2563EB),
            ),
          ),

          const SizedBox(width: 14),

          // ── Info ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Host',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),

                const SizedBox(height: 3),

                // Destination subtitle
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 13, color: Color(0xFF6B7280)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'Going to ${trip.destAddress}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Fare + Rating row
                Row(
                  children: [
                    // Fare pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '₹${trip.basePrice.toInt()} Shared Fare',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Star rating
                    _StarRating(rating: rating),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip info card — start location, destination, seats, time
// ─────────────────────────────────────────────────────────────────────────────
class _TripInfoCard extends StatelessWidget {
  final TripModel trip;

  const _TripInfoCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── From Location ─────────────────────────────────────────
          _LocationRow(
            icon: Icons.circle,
            iconColor: const Color(0xFF2563EB),
            label: 'From',
            address: trip.startAddress,
          ),

          // ── Connector ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 2,
                  height: 30,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // ── To Location ───────────────────────────────────────────
          _LocationRow(
            icon: Icons.location_on,
            iconColor: const Color(0xFFEF4444),
            label: 'To',
            address: trip.destAddress,
          ),

          const Divider(height: 32),

          // ── Trip Stats Row ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                icon: Icons.event_seat,
                label: '${trip.availableSeats} Seats',
              ),
              _StatChip(
                icon: Icons.access_time,
                label: _formatTime(trip.departureTime),
              ),
              _StatChip(
                icon: Icons.currency_rupee,
                label: '₹${trip.basePrice.toInt()}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location row widget
// ─────────────────────────────────────────────────────────────────────────────
class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip widget for seats, time, price
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Star rating widget
// ─────────────────────────────────────────────────────────────────────────────
class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          rating.toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(width: 2),
        ...List.generate(5, (index) {
          final isFilled = index < rating.floor();
          final isHalf = index == rating.floor() && rating % 1 >= 0.5;

          return Icon(
            isFilled
                ? Icons.star
                : isHalf
                    ? Icons.star_half
                    : Icons.star_border,
            size: 16,
            color: const Color(0xFFFBBF24),
          );
        }),
      ],
    );
  }
}
