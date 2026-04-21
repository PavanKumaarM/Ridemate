import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
          onPressed: () => context.go('/home'),
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
            _RiderCard(trip: trip, isCreator: isCreator),
            const SizedBox(height: 16),
            _TripInfoCard(trip: trip),
            const SizedBox(height: 16),
            if (isCreator) ...[
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
                  onPressed: () => _startTrip(context, trip),
                  child: const Text(
                    'Start Trip',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showCancelConfirmation(context, trip),
                  child: const Text(
                    'Cancel Trip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else ...[
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
                  onPressed: () => _bookTrip(context, trip),
                  child: const Text(
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
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, TripModel trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text(
          'Are you sure you want to cancel this trip? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Trip'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _cancelTrip(context, trip);
            },
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip(BuildContext context, TripModel trip) async {
    try {
      await Supabase.instance.client
          .from('trips')
          .update({'status': 'cancelled'})
          .eq('id', trip.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip cancelled successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel trip: $e')),
        );
      }
    }
  }

  Future<void> _bookTrip(BuildContext context, TripModel trip) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to book a trip')),
        );
        return;
      }

      // Generate OTP for this booking
      final otp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();

      final bookingResponse = await Supabase.instance.client
          .from('bookings')
          .insert({
            'trip_id': trip.id,
            'passenger_id': user.id,
            'status': 'confirmed',
            'otp_code': otp,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final bookingId = bookingResponse['id'] as String;

      await Supabase.instance.client
          .from('trips')
          .update({'available_seats': trip.availableSeats - 1})
          .eq('id', trip.id);

      // Fetch host details
      final hostResponse = await Supabase.instance.client
          .from('users')
          .select('name, phone, vehicle_number')
          .eq('id', trip.agentId)
          .maybeSingle();

      if (context.mounted) {
        // Show booking confirmation dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _BookingConfirmationDialog(
            trip: trip,
            bookingId: bookingId,
            otp: otp,
            hostName: hostResponse?['name'] ?? 'Driver',
            hostPhone: hostResponse?['phone'] ?? '',
            vehicleNumber: hostResponse?['vehicle_number'] ?? 'N/A',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e')),
        );
      }
    }
  }

  void _startTrip(BuildContext context, TripModel trip) async {
    try {
      await Supabase.instance.client
          .from('trips')
          .update({'status': 'waiting_for_passenger'})
          .eq('id', trip.id);
      
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _OtpVerificationDialog(trip: trip),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start trip: $e')),
        );
      }
    }
  }
}

class _OtpVerificationDialog extends StatefulWidget {
  final TripModel trip;

  const _OtpVerificationDialog({required this.trip});

  @override
  State<_OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _BookingConfirmationDialog extends StatefulWidget {
  final TripModel trip;
  final String bookingId;
  final String otp;
  final String hostName;
  final String hostPhone;
  final String vehicleNumber;

  const _BookingConfirmationDialog({
    required this.trip,
    required this.bookingId,
    required this.otp,
    required this.hostName,
    required this.hostPhone,
    required this.vehicleNumber,
  });

  @override
  State<_BookingConfirmationDialog> createState() => _BookingConfirmationDialogState();
}

class _BookingConfirmationDialogState extends State<_BookingConfirmationDialog> {
  ll.LatLng? _hostLocation;
  StreamSubscription<dynamic>? _locationSubscription;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _subscribeToHostLocation();
  }

  void _subscribeToHostLocation() {
    _locationSubscription = Supabase.instance.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', widget.trip.id)
        .listen((data) {
          if (data.isNotEmpty && data[0]['current_lat'] != null && data[0]['current_lng'] != null) {
            setState(() {
              _hostLocation = ll.LatLng(
                (data[0]['current_lat'] as num).toDouble(),
                (data[0]['current_lng'] as num).toDouble(),
              );
              _isLoadingLocation = false;
            });
          }
        });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  void _startTracking() {
    Navigator.pop(context);
    context.push('/liveTracking', extra: {
      'trip': widget.trip,
      'isHost': false,
      'bookingId': widget.bookingId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking Confirmed!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Trip #${widget.trip.id.substring(0, 8)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // OTP Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981), width: 2),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Your Trip OTP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.otp,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Share this OTP with driver when they arrive',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF166534),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Host Details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Driver Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(Icons.person, 'Name', widget.hostName),
                          const SizedBox(height: 8),
                          _buildDetailRow(Icons.directions_car, 'Vehicle', widget.vehicleNumber),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Mini Map
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: _hostLocation ??
                                ll.LatLng(widget.trip.startLat, widget.trip.startLng),
                            initialZoom: 14,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.ridemate.app',
                            ),
                            MarkerLayer(
                              markers: [
                                // Host location marker
                                if (_hostLocation != null)
                                  Marker(
                                    point: _hostLocation!,
                                    width: 40,
                                    height: 50,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Color(0xFF10B981),
                                      size: 40,
                                    ),
                                  ),
                                // Pickup location marker
                                Marker(
                                  point: ll.LatLng(widget.trip.startLat, widget.trip.startLng),
                                  width: 40,
                                  height: 50,
                                  child: const Icon(
                                    Icons.flag,
                                    color: Color(0xFF2563EB),
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingLocation)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Loading driver location...',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ],
                      )
                    else
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Driver location live',
                            style: TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        // Call Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.hostPhone.isNotEmpty
                                ? () => _makePhoneCall(widget.hostPhone)
                                : null,
                            icon: const Icon(Icons.phone),
                            label: const Text('Call Driver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer Button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Start Live Tracking',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
              ),
            ),
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
      ],
    );
  }
}

class _OtpVerificationDialogState extends State<_OtpVerificationDialog> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Check against bookings table where OTP is stored
      final response = await Supabase.instance.client
          .from('bookings')
          .select('id, otp_code')
          .eq('trip_id', widget.trip.id)
          .eq('otp_code', otp)
          .maybeSingle();

      if (response != null && response['otp_code'] == otp) {
        await Supabase.instance.client
            .from('trips')
            .update({'status': 'in_progress'})
            .eq('id', widget.trip.id);

        if (mounted) {
          Navigator.pop(context);
          context.push('/liveTracking', extra: {
            'trip': widget.trip,
            'isHost': true,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP verified! Trip started successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid OTP. Please ask passenger for the correct code.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF2563EB)),
          SizedBox(width: 8),
          Text('Enter Passenger OTP'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ask the passenger for their OTP code and enter it below to verify and start the trip:',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: Color(0xFF2563EB),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
                color: Colors.grey.shade400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          onPressed: _isVerifying ? null : _verifyOtp,
          child: _isVerifying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Verify & Start Trip'),
        ),
      ],
    );
  }
}

class _RiderCard extends StatelessWidget {
  final TripModel trip;
  final bool isCreator;

  const _RiderCard({required this.trip, required this.isCreator});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCreator ? 'Your Trip' : 'Trip Agent',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 13, color: Color(0xFF6B7280)),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'Going to ${trip.destAddress}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(width: 4),
        for (int i = 0; i < 5; i++)
          Icon(
            i < full ? Icons.star : (i == full && hasHalf) ? Icons.star_half : Icons.star_border,
            size: 16,
            color: const Color(0xFFFBBF24),
          ),
      ],
    );
  }
}

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
          _InfoRow(icon: Icons.radio_button_checked, iconColor: const Color(0xFF2563EB), label: 'From', value: trip.startAddress),
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
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _InfoRow(icon: Icons.location_pin, iconColor: const Color(0xFFEF4444), label: 'To', value: trip.destAddress),
          const Divider(height: 24, color: Color(0xFFF3F4F6)),
          Row(
            children: [
              Expanded(child: _MetaChip(icon: Icons.event_seat, label: '${trip.availableSeats} Seats')),
              const SizedBox(width: 10),
              Expanded(child: _MetaChip(icon: Icons.access_time, label: _formatTime(trip.departureTime))),
              const SizedBox(width: 10),
              Expanded(child: _MetaChip(icon: Icons.currency_rupee, label: '₹${trip.basePrice.toInt()}')),
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
  const _InfoRow({required this.icon, required this.iconColor, required this.label, required this.value});

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
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
              const SizedBox(height: 1),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
