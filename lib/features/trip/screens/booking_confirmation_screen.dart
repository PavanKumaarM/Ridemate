import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/trip_model.dart';

/// Booking Confirmation Screen - Shows OTP, host details, map, and call button
/// Navigates to Live Tracking when user clicks "Start Live Tracking"
class BookingConfirmationScreen extends StatefulWidget {
  final TripModel trip;
  final String bookingId;
  final String otp;
  final String hostName;
  final String hostPhone;
  final String vehicleNumber;

  const BookingConfirmationScreen({
    super.key,
    required this.trip,
    required this.bookingId,
    required this.otp,
    required this.hostName,
    required this.hostPhone,
    required this.vehicleNumber,
  });

  @override
  State<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  ll.LatLng? _hostLocation;
  StreamSubscription<List<Map<String, dynamic>>>? _locationSubscription;
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
    context.push('/liveTracking', extra: {
      'trip': widget.trip,
      'isHost': false,
      'bookingId': widget.bookingId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home/availableTrips'),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Confirmed!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Your trip is ready',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OTP Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981), width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_user,
                      color: Color(0xFF10B981),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your Trip OTP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.otp,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Share this OTP with driver when they arrive',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF166534),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Driver Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.person, 'Name', widget.hostName),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.directions_car, 'Vehicle', widget.vehicleNumber),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Map
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 12),
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

              // Call Driver Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: widget.hostPhone.isNotEmpty
                      ? () => _makePhoneCall(widget.hostPhone)
                      : null,
                  icon: const Icon(Icons.phone, size: 24),
                  label: const Text(
                    'Call Driver',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Start Live Tracking Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startTracking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.my_location, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Start Live Tracking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
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
