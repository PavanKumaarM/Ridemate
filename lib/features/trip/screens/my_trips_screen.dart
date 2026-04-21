import 'dart:async';
import 'dart:convert';
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
  StreamSubscription? _notificationSubscription;
  bool _isShowingPopup = false;
  DateTime? _subscriptionStartTime;

  @override
  void initState() {
    super.initState();
    _fetchMyTripsWithBookings();
    _subscriptionStartTime = DateTime.now();
    _subscribeToBookingNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToBookingNotifications() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    debugPrint('🔔 Starting notification subscription for user: ${user.id}');
    debugPrint('⏰ Subscription start time: $_subscriptionStartTime');

    // Subscribe to new notifications for this user
    _notificationSubscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((data) async {
          debugPrint('📨 Received ${data.length} notifications from stream');
          
          for (final n in data) {
            debugPrint('  - Notification: type=${n['type']}, user_id=${n['user_id']}, is_read=${n['is_read']}, created_at=${n['created_at']}');
          }
          
          // Filter for unread booking requests for this user that are NEW (created after screen loaded)
          final newRequests = data.where((n) {
            // Check user_id
            if (n['user_id'] != user.id) {
              debugPrint('    ❌ Filtered: wrong user_id');
              return false;
            }
            // Check type
            if (n['type'] != 'booking_request') {
              debugPrint('    ❌ Filtered: wrong type (${n['type']})');
              return false;
            }
            // Check is_read
            if (n['is_read'] != false) {
              debugPrint('    ❌ Filtered: already read');
              return false;
            }
            
            // Check created_at timing
            final createdAt = DateTime.tryParse(n['created_at'] as String? ?? '');
            if (createdAt == null) {
              debugPrint('    ❌ Filtered: invalid created_at');
              return false;
            }
            if (_subscriptionStartTime == null) {
              debugPrint('    ❌ Filtered: no subscription start time');
              return false;
            }
            
            // Only show notifications created after the screen loaded
            final isNew = createdAt.isAfter(_subscriptionStartTime!);
            debugPrint('    ⏱️ Created: $createdAt, Start: $_subscriptionStartTime, IsNew: $isNew');
            return isNew;
          }).toList();
          
          debugPrint('✅ Found ${newRequests.length} new booking requests');
          
          if (newRequests.isNotEmpty && mounted && !_isShowingPopup) {
            // Get the latest notification
            final notification = newRequests.first;
            debugPrint('🎯 Processing notification: ${notification['id']}');
            
            // Extract data - handle both JSON object and string formats
            final notificationData = notification['data'];
            Map<String, dynamic> dataMap = {};
            
            if (notificationData is String) {
              try {
                dataMap = jsonDecode(notificationData) as Map<String, dynamic>;
              } catch (e) {
                debugPrint('❌ Failed to parse data as JSON string: $e');
              }
            } else if (notificationData is Map) {
              dataMap = Map<String, dynamic>.from(notificationData);
            }
            
            final bookingId = dataMap['booking_id'] as String?;
            final tripId = dataMap['trip_id'] as String?;
            
            debugPrint('📋 Extracted - bookingId: $bookingId, tripId: $tripId');
            
            if (bookingId != null && tripId != null) {
              // Fetch the booking details
              final bookingResponse = await Supabase.instance.client
                  .from('bookings')
                  .select('*, trips(*)')
                  .eq('id', bookingId)
                  .maybeSingle();
              
              if (bookingResponse != null && mounted) {
                debugPrint('✅ Booking found, showing popup');
                final booking = BookingModel.fromJson(bookingResponse);
                _showBookingRequestPopup(booking, notification['id'] as String);
              } else {
                debugPrint('❌ Booking not found or screen unmounted');
              }
            }
          }
        });
  }

  Future<void> _showBookingRequestPopup(BookingModel booking, String notificationId) async {
    if (_isShowingPopup) return;
    _isShowingPopup = true;

    // Mark notification as read
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BookingRequestPopupDialog(
        booking: booking,
        onAccept: () async {
          // Show OTP verification dialog
          final verified = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => _OtpVerificationDialog(
              booking: booking,
              tripId: booking.tripId,
            ),
          );
          Navigator.pop(context, verified);
        },
        onReject: () => Navigator.pop(context, false),
      ),
    );

    _isShowingPopup = false;

    if (result == true) {
      // Accept the booking
      await _processAcceptedBooking(booking);
    } else if (result == false) {
      // Reject the booking
      await _rejectBooking(booking);
    }
  }

  Future<void> _processAcceptedBooking(BookingModel booking) async {
    try {
      // Get trip data
      final trip = _myTrips.firstWhere(
        (t) => t.id == booking.tripId,
        orElse: () => booking.trip!,
      );

      // Update booking status to accepted
      await Supabase.instance.client
          .from('bookings')
          .update({'status': 'accepted'})
          .eq('id', booking.id);

      // Update trip status to 'in_progress'
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept booking: $e')),
        );
      }
    }
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
    // Show OTP verification dialog first
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OtpVerificationDialog(
        booking: booking,
        tripId: booking.tripId,
      ),
    );

    // If OTP was not verified, don't proceed
    if (verified != true) {
      return;
    }

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

      // Update trip status to 'in_progress'
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

// ─────────────────────────────────────────────────────────────────────────────
// Booking Request Popup Dialog for Host
// ─────────────────────────────────────────────────────────────────────────────
class _BookingRequestPopupDialog extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _BookingRequestPopupDialog({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 48,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Center(
              child: Text(
                'New Booking Request!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Center(
              child: Text(
                'A passenger wants to book your trip',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Booking Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(Icons.event_seat, 'Seats', '${booking.seatsBooked}'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.currency_rupee, 'Fare', '₹${booking.totalFare.toStringAsFixed(0)}'),
                  if (booking.trip != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.location_on, 'From', booking.trip!.startAddress),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.flag, 'To', booking.trip!.destAddress),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP Verification Dialog for Host to verify passenger OTP
// ─────────────────────────────────────────────────────────────────────────────
class _OtpVerificationDialog extends StatefulWidget {
  final BookingModel booking;
  final String tripId;

  const _OtpVerificationDialog({
    required this.booking,
    required this.tripId,
  });

  @override
  State<_OtpVerificationDialog> createState() => _OtpVerificationDialogState();
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
          .eq('trip_id', widget.tripId)
          .eq('otp_code', otp)
          .maybeSingle();

      if (response != null && response['otp_code'] == otp) {
        // OTP verified successfully
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP verified! Trip starting...'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            'Ask the passenger for their OTP code and enter it below to verify and accept the booking:',
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade300,
                letterSpacing: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
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
              : const Text('Verify & Accept'),
        ),
      ],
    );
  }
}
