import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/trip_model.dart';

class TripDetailsArgs {
  final TripModel trip;
  final bool isCreator;

  TripDetailsArgs({required this.trip, required this.isCreator});
}

class TripDetailsScreen extends StatelessWidget {
  final TripDetailsArgs args;

  const TripDetailsScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final trip = args.trip;
    final isCreator = args.isCreator;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          onPressed:
              false
                  ? null
                  : () {
                    if (context.canPop()) {
                      context.pop();
                    }
                  },
          color: Colors.black,
        ),
        title: const Text(
          'Trip Details',
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

            // ── RIDER CARD ────────────────────────────────────────────
            _RiderCard(
              trip: trip,
              isCreator: isCreator,
            ),

            const SizedBox(height: 16),

            // ── TRIP INFO CARD ────────────────────────────────────────
            _TripInfoCard(trip: trip),

            const SizedBox(height: 16),

            // ── ACTION BUTTON ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCreator
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {},
                child: Text(
                  isCreator ? 'Cancel Trip' : 'Request Ride',
                  style: const TextStyle(
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
// Rider profile card — avatar, name, destination, fare, rating
// ─────────────────────────────────────────────────────────────────────────────
class _RiderCard extends StatelessWidget {
  final TripModel trip;
  final bool isCreator;

  const _RiderCard({required this.trip, required this.isCreator});

  @override
  Widget build(BuildContext context) {
    // Placeholder rating — wire up to your model when available
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
            child: Icon(
              isCreator ? Icons.person : Icons.directions_car,
              size: 34,
              color: const Color(0xFF2563EB),
            ),
          ),

          const SizedBox(width: 14),

          // ── Info ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Name (use agentId as placeholder; swap with real name)
                Text(
                  isCreator ? 'Your Trip' : 'Trip Agent',
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
// Star rating widget
// ─────────────────────────────────────────────────────────────────────────────
class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(width: 4),
        for (int i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star
                : (i == full && hasHalf)
                    ? Icons.star_half
                    : Icons.star_border,
            size: 16,
            color: const Color(0xFFFBBF24),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip info card — from / to / seats / departure
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
        children: [
          _InfoRow(
            icon: Icons.radio_button_checked,
            iconColor: const Color(0xFF2563EB),
            label: 'From',
            value: trip.startAddress,
          ),

          // Dotted vertical connector
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              children: [
                Column(
                  children: List.generate(
                    4,
                    (_) => Container(
                      width: 2,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          _InfoRow(
            icon: Icons.location_pin,
            iconColor: const Color(0xFFEF4444),
            label: 'To',
            value: trip.destAddress,
          ),

          const Divider(height: 24, color: Color(0xFFF3F4F6)),

          Row(
            children: [
              Expanded(
                child: _MetaChip(
                  icon: Icons.event_seat,
                  label: '${trip.availableSeats} Seats',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaChip(
                  icon: Icons.access_time,
                  label: _formatTime(trip.departureTime),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetaChip(
                  icon: Icons.currency_rupee,
                  label: '₹${trip.basePrice.toInt()}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2563EB)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}