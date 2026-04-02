import 'package:flutter/material.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:go_router/go_router.dart';
import 'package:ridemate_app/data/models/trip_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/destination_picker.dart';
import '../widgets/seat_selector.dart';
import '../widgets/fare_calculator.dart';

// Simple LatLng class for coordinates
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  int seats = 1;
  double fare = 100;

  String startLocation = '';
  String destination = '';

  double startLat = 0;
  double startLng = 0;

  double destLat = 0;
  double destLng = 0;

  bool get _hasRoute =>
      startLat != 0 && startLng != 0 && destLat != 0 && destLng != 0;

  LatLng get _routeCenter => _hasRoute
      ? LatLng((startLat + destLat) / 2, (startLng + destLng) / 2)
      : const LatLng(12.9716, 77.5946);

  double get _distanceKm {
    if (!_hasRoute) return 0;
    const double earthRadius = 6371;
    final double dLat = _toRadians(destLat - startLat);
    final double dLng = _toRadians(destLng - startLng);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(startLat)) *
            cos(_toRadians(destLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Enter Your Destination',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── LOCATION PICKERS ──────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  DestinationPicker(
                    label: 'Your Location',
                    iconColor: const Color(0xFF2563EB),
                    onSelected: (address, lat, lng) {
                      setState(() {
                        startLocation = address;
                        startLat = lat;
                        startLng = lng;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DestinationPicker(
                    label: 'Destination',
                    iconColor: const Color(0xFFEF4444),
                    onSelected: (address, lat, lng) {
                      setState(() {
                        destination = address;
                        destLat = lat;
                        destLng = lng;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── ROUTE MAP PREVIEW ─────────────────────────────────────
            // Shows a real flutter_map with OSM tiles + OSRM road route polyline.
            ClipRRect(
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: _hasRoute
                    ? _RouteMapPreview(
                        startLatLng: LatLng(startLat, startLng),
                        destLatLng: LatLng(destLat, destLng),
                        center: _routeCenter,
                      )
                    : const _MapHintPlaceholder(),
              ),
            ),

            const SizedBox(height: 16),

            // ── SEAT + FARE ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SeatSelector(
                    onChanged: (value) {
                      setState(() => seats = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  FareCalculator(
                    distanceKm: _distanceKm,
                    onFareChanged: (value) {
                      setState(() => fare = value);
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── POST TRIP BUTTON ──────────────────────────────
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
                      onPressed: () async {
                        if (startLocation.isEmpty || destination.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Select both locations'),
                            ),
                          );
                          return;
                        }

                        final user =
                            Supabase.instance.client.auth.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please login to post a trip'),
                            ),
                          );
                          return;
                        }

                        final existingTrips = await Supabase.instance.client
                            .from('trips')
                            .select()
                            .eq('agent_id', user.id)
                            .eq('status', 'active');

                        if ((existingTrips as List).isNotEmpty) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'You can only host one trip at a time. Please complete or cancel your existing trip first.'),
                              ),
                            );
                          }
                          return;
                        }

                        final trip = TripModel(
                          id: '',
                          agentId: user.id,
                          startLat: startLat,
                          startLng: startLng,
                          destLat: destLat,
                          destLng: destLng,
                          startAddress: startLocation,
                          destAddress: destination,
                          departureTime:
                              DateTime.now().add(const Duration(hours: 1)),
                          availableSeats: seats,
                          basePrice: fare,
                          status: 'active',
                          createdAt: DateTime.now(),
                        );

                        try {
                          await Supabase.instance.client.from('users').upsert({
                            'id': user.id,
                          });

                          final response = await Supabase.instance.client
                              .from('trips')
                              .insert(trip.toJson()..remove('id'))
                              .select()
                              .single();
                          final insertedTrip = TripModel.fromJson(response);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Trip posted successfully!'),
                            ),
                          );
                          context.go('/tripDetails', extra: insertedTrip);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to post trip: $e'),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Post Trip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Real interactive map using flutter_map (OSM tiles) + OSRM road route
// Packages needed:
//   flutter_map: ^7.0.2
//   latlong2: ^0.9.1
//   http: (already in most Flutter projects)
// ─────────────────────────────────────────────────────────────────────────────
class _RouteMapPreview extends StatefulWidget {
  final LatLng startLatLng;
  final LatLng destLatLng;
  final LatLng center;

  const _RouteMapPreview({
    required this.startLatLng,
    required this.destLatLng,
    required this.center,
  });

  @override
  State<_RouteMapPreview> createState() => _RouteMapPreviewState();
}

class _RouteMapPreviewState extends State<_RouteMapPreview> {
  List<ll.LatLng> _routePoints = [];
  bool _isLoading = true;
  String? _error;
  double? _routeDistanceKm;
  int? _routeDurationMin;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  @override
  void didUpdateWidget(_RouteMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch if coordinates changed
    if (oldWidget.startLatLng.latitude != widget.startLatLng.latitude ||
        oldWidget.destLatLng.latitude != widget.destLatLng.latitude) {
      _fetchRoute();
    }
  }

  /// Calls the free OSRM API to get the real road route polyline.
  /// No API key required. Perfectly fine for development and moderate usage.
  Future<void> _fetchRoute() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _routePoints = [];
    });

    try {
      final start = widget.startLatLng;
      final dest = widget.destLatLng;

      // OSRM public demo server — free, no API key needed
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${dest.longitude},${dest.latitude}'
          '?overview=full&geometries=geojson';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final coords =
              routes[0]['geometry']['coordinates'] as List;

          final points = coords
              .map((c) => ll.LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();

          final distanceM =
              (routes[0]['distance'] as num).toDouble();
          final durationS =
              (routes[0]['duration'] as num).toDouble();

          setState(() {
            _routePoints = points;
            _routeDistanceKm = distanceM / 1000;
            _routeDurationMin = (durationS / 60).round();
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'No route found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Route fetch failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error';
        _isLoading = false;
      });
    }
  }

  /// Auto-calculates zoom so both markers fit inside the map view
  double _calcZoom() {
    final latDiff =
        (widget.startLatLng.latitude - widget.destLatLng.latitude).abs();
    final lngDiff =
        (widget.startLatLng.longitude - widget.destLatLng.longitude).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    if (maxDiff < 0.01) return 14;
    if (maxDiff < 0.05) return 13;
    if (maxDiff < 0.1) return 12;
    if (maxDiff < 0.3) return 11;
    if (maxDiff < 0.6) return 10;
    if (maxDiff < 1.5) return 9;
    return 8;
  }

  @override
  Widget build(BuildContext context) {
    final center =
        ll.LatLng(widget.center.latitude, widget.center.longitude);
    final startLL =
        ll.LatLng(widget.startLatLng.latitude, widget.startLatLng.longitude);
    final destLL =
        ll.LatLng(widget.destLatLng.latitude, widget.destLatLng.longitude);

    return Stack(
      children: [
        // ── flutter_map widget ──────────────────────────────────────
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: _calcZoom(),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none, // static preview, no gesture
            ),
          ),
          children: [
            // OSM tile layer — free, no API key
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.ridemate.app',
              maxZoom: 19,
            ),

            // Road route polyline (only when loaded)
            if (_routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.0,
                    color: const Color(0xFF2563EB),
                    borderStrokeWidth: 2.0,
                    borderColor: Colors.white.withOpacity(0.6),
                  ),
                ],
              ),

            // Start & end markers
            MarkerLayer(
              markers: [
                // Start marker (blue)
                Marker(
                  point: startLL,
                  width: 40,
                  height: 50,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('A',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                // Destination marker (red)
                Marker(
                  point: destLL,
                  width: 40,
                  height: 50,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('B',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── Loading spinner ───────────────────────────────────────────
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.55),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                strokeWidth: 2.5,
              ),
            ),
          ),

        // ── Error chip ────────────────────────────────────────────────
        if (_error != null && !_isLoading)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '⚠ $_error — showing straight line',
                  style: TextStyle(
                      fontSize: 11, color: Colors.red.shade700),
                ),
              ),
            ),
          ),

        // ── Route info pill at bottom ─────────────────────────────────
        if (_routeDistanceKm != null && _routeDurationMin != null)
          Positioned(
            bottom: 8,
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.route,
                      size: 15, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text(
                    '${_routeDistanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(Icons.access_time_outlined,
                      size: 15, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Text(
                    '$_routeDurationMin min',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder shown before both locations are selected
// ─────────────────────────────────────────────────────────────────────────────
class _MapHintPlaceholder extends StatelessWidget {
  const _MapHintPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF4FF),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _GridPainter(),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_outlined,
                      size: 32, color: Color(0xFF2563EB)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Select both locations to see route',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB).withOpacity(0.07)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}