import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/trip_model.dart';
import '../../../core/services/live_location_service.dart';

/// Live tracking screen for both host (driver) and passenger.
/// 
/// Host Mode: Streams current location to Supabase
/// Passenger Mode: Subscribes to host's location updates
class LiveTrackingScreen extends StatefulWidget {
  final TripModel trip;
  final bool isHost; // true = driver/host, false = passenger

  const LiveTrackingScreen({
    super.key,
    required this.trip,
    required this.isHost,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  final LiveLocationService _locationService = LiveLocationService();

  // Location tracking
  ll.LatLng? _currentLocation;
  ll.LatLng? _driverLocation;
  StreamSubscription<Map<String, dynamic>>? _tripSubscription;
  StreamSubscription<Position>? _hostPositionStream;

  // Route polyline points
  List<ll.LatLng> _routePoints = [];

  // UI state
  bool _isLoading = true;
  String? _error;
  double? _distanceToDestination;
  int? _estimatedMinutes;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch route polyline
      await _fetchRoute();

      if (widget.isHost) {
        // Host mode: Start streaming location
        await _locationService.startLocationStreaming(widget.trip.id);
        
        // Also listen to own position for UI updates
        _hostPositionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          setState(() {
            _currentLocation = ll.LatLng(position.latitude, position.longitude);
          });
          _mapController.move(_currentLocation!, _mapController.camera.zoom);
        });
      } else {
        // Passenger mode: Subscribe to driver's location
        _tripSubscription = _locationService
            .subscribeToTripLocation(widget.trip.id)
            .listen((data) {
          if (data.isNotEmpty && data['lat'] != null && data['lng'] != null) {
            setState(() {
              _driverLocation = ll.LatLng(
                (data['lat'] as num).toDouble(),
                (data['lng'] as num).toDouble(),
              );
            });
            // Center map on driver
            _mapController.move(_driverLocation!, _mapController.camera.zoom);
          }
        });
      }

      // Get initial position
      final position = await LiveLocationService.getCurrentLocation();
      setState(() {
        _currentLocation = ll.LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRoute() async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${widget.trip.startLng},${widget.trip.startLat};'
          '${widget.trip.destLng},${widget.trip.destLat}'
          '?overview=full&geometries=geojson';

      final response = await Supabase.instance.client
          .rpc('http_get', params: {'url': url})
          .timeout(const Duration(seconds: 10));

      final data = response as Map<String, dynamic>;
      final routes = data['routes'] as List?;

      if (routes != null && routes.isNotEmpty) {
        final coords = routes[0]['geometry']['coordinates'] as List;
        setState(() {
          _routePoints = coords
              .map((c) => ll.LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
          _distanceToDestination = (routes[0]['distance'] as num).toDouble() / 1000;
          _estimatedMinutes = ((routes[0]['duration'] as num).toDouble() / 60).round();
        });
      }
    } catch (e) {
      // Fallback: just show start and destination
      setState(() {
        _routePoints = [
          ll.LatLng(widget.trip.startLat, widget.trip.startLng),
          ll.LatLng(widget.trip.destLat, widget.trip.destLng),
        ];
      });
    }
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _hostPositionStream?.cancel();
    if (widget.isHost) {
      _locationService.stopLocationStreaming();
    }
    _mapController.dispose();
    super.dispose();
  }

  void _endTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip?'),
        content: const Text('Are you sure you want to end this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _completeTrip();
            },
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTrip() async {
    try {
      await Supabase.instance.client
          .from('trips')
          .update({'status': 'completed'})
          .eq('id', widget.trip.id);

      if (widget.isHost) {
        _locationService.stopLocationStreaming();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip completed!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _currentLocation ??
        _driverLocation ??
        ll.LatLng(
          (widget.trip.startLat + widget.trip.destLat) / 2,
          (widget.trip.startLng + widget.trip.destLng) / 2,
        );

    final liveLocation = widget.isHost ? _currentLocation : _driverLocation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
            ),
            children: [
              // OSM tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ridemate.app',
              ),

              // Route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4,
                      color: const Color(0xFF2563EB),
                      borderStrokeWidth: 1,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Start marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: ll.LatLng(widget.trip.startLat, widget.trip.startLng),
                    width: 40,
                    height: 50,
                    child: _buildMarker(
                      icon: Icons.location_on,
                      color: const Color(0xFF2563EB),
                      label: 'Start',
                    ),
                  ),
                  // Destination marker
                  Marker(
                    point: ll.LatLng(widget.trip.destLat, widget.trip.destLng),
                    width: 40,
                    height: 50,
                    child: _buildMarker(
                      icon: Icons.flag,
                      color: const Color(0xFFEF4444),
                      label: 'End',
                    ),
                  ),
                  // Live location marker (driver/current position)
                  if (liveLocation != null)
                    Marker(
                      point: liveLocation,
                      width: 50,
                      height: 50,
                      child: _buildLiveMarker(),
                    ),
                ],
              ),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xFF2563EB)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading live tracking...',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),

          // Error overlay
          if (_error != null && !_isLoading)
            Container(
              color: Colors.white.withOpacity(0.9),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFEF4444), size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initializeTracking,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Top bar with back button and trip info
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Trip info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isHost ? 'Your Trip (Host)' : 'Live Tracking',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.trip.startAddress} → ${widget.trip.destAddress}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.isHost ? 'Sharing' : 'Live',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom panel with trip details and action button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Trip stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStat(
                            icon: Icons.route,
                            value: _distanceToDestination != null
                                ? '${_distanceToDestination!.toStringAsFixed(1)} km'
                                : '--',
                            label: 'Distance',
                          ),
                        ),
                        Expanded(
                          child: _buildStat(
                            icon: Icons.access_time,
                            value: _estimatedMinutes != null
                                ? '$_estimatedMinutes min'
                                : '--',
                            label: 'Est. Time',
                          ),
                        ),
                        Expanded(
                          child: _buildStat(
                            icon: Icons.currency_rupee,
                            value: '₹${widget.trip.basePrice.toInt()}',
                            label: 'Fare',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isHost
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: widget.isHost ? _endTrip : null,
                        child: Text(
                          widget.isHost ? 'End Trip' : 'Trip in Progress',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    if (!widget.isHost)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Wait for the host to end the trip',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMarker() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0xFF2563EB),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.navigation,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2563EB)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
