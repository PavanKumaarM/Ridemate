import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/trip_model.dart';
import '../../../core/services/live_location_service.dart';
import '../../../core/services/email_otp_service.dart';

/// Live tracking screen for both host (driver) and passenger.
/// 
/// Host Mode: Streams current location to Supabase and shows passenger locations
/// Passenger Mode: Subscribes to host's location updates and streams own location
class LiveTrackingScreen extends StatefulWidget {
  final TripModel trip;
  final bool isHost; // true = driver/host, false = passenger
  final String? bookingId; // For passenger to stream their location

  const LiveTrackingScreen({
    super.key,
    required this.trip,
    required this.isHost,
    this.bookingId,
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
  List<ll.LatLng> _passengerLocations = []; // For host to see passenger locations
  StreamSubscription<Map<String, dynamic>>? _tripSubscription;
  StreamSubscription<Position>? _hostPositionStream;
  StreamSubscription<Position>? _passengerPositionStream;
  StreamSubscription<List<Map<String, dynamic>>>? _passengerLocationsSubscription;

  // Route polyline points
  List<ll.LatLng> _routePoints = [];
  List<ll.LatLng> _hostToPassengerRoute = []; // Route from host to passenger pickup

  // UI state
  bool _isLoading = true;
  String? _error;
  double? _distanceToDestination;
  double? _distanceToPickup;
  int? _estimatedMinutes;
  bool _showOtpButton = false;
  bool _tripStarted = false;

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
        // Host mode: Start streaming location and subscribe to passenger locations
        await _locationService.startLocationStreaming(widget.trip.id);
        
        // Listen to own position for UI updates
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
          // Update route to passenger when host moves
          _fetchHostToPassengerRoute();
        });

        // Subscribe to passenger locations
        _passengerLocationsSubscription = _locationService
            .subscribeToPassengerLocations(widget.trip.id)
            .listen((passengers) {
          setState(() {
            _passengerLocations = passengers
                .map((p) => ll.LatLng(
                      (p['lat'] as num).toDouble(),
                      (p['lng'] as num).toDouble(),
                    ))
                .toList();
          });
          // Update route from host to passenger when passenger locations change
          _fetchHostToPassengerRoute();
        });
      } else {
        // Passenger mode: Subscribe to driver's location and track own position
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
            _mapController.move(_driverLocation!, _mapController.camera.zoom);
          }
        });

        // Track passenger position for OTP verification and sharing with host
        _passengerPositionStream = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          setState(() {
            _currentLocation = ll.LatLng(position.latitude, position.longitude);
            _checkDistanceToPickup();
          });
        });

        // Stream passenger location to host (get bookingId from extra args)
        final bookingId = widget.bookingId;
        if (bookingId != null) {
          _locationService.startPassengerLocationStreaming(bookingId);
        }

        // Start polling for trip status to detect when host verifies OTP
        _startTripStatusPolling();
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

  Future<void> _fetchHostToPassengerRoute() async {
    if (_currentLocation == null || _passengerLocations.isEmpty) return;
    
    // Find nearest passenger
    final nearestPassenger = _passengerLocations.first;
    
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${_currentLocation!.longitude},${_currentLocation!.latitude};'
          '${nearestPassenger.longitude},${nearestPassenger.latitude}'
          '?overview=full&geometries=geojson';

      final response = await Supabase.instance.client
          .rpc('http_get', params: {'url': url})
          .timeout(const Duration(seconds: 10));

      final data = response as Map<String, dynamic>;
      final routes = data['routes'] as List?;

      if (routes != null && routes.isNotEmpty) {
        final coords = routes[0]['geometry']['coordinates'] as List;
        setState(() {
          _hostToPassengerRoute = coords
              .map((c) => ll.LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
        });
      }
    } catch (e) {
      // Fallback: straight line to passenger
      setState(() {
        _hostToPassengerRoute = [
          _currentLocation!,
          nearestPassenger,
        ];
      });
    }
  }

  Future<void> _fetchRouteFromCurrentLocation() async {
    if (_currentLocation == null) return;
    
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${_currentLocation!.longitude},${_currentLocation!.latitude};'
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
      // Fallback: straight line from current location to destination
      setState(() {
        _routePoints = [
          _currentLocation!,
          ll.LatLng(widget.trip.destLat, widget.trip.destLng),
        ];
      });
    }
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    _hostPositionStream?.cancel();
    _passengerPositionStream?.cancel();
    _passengerLocationsSubscription?.cancel();
    if (widget.isHost) {
      _locationService.stopLocationStreaming();
    }
    _mapController.dispose();
    super.dispose();
  }

  void _checkDistanceToPickup() {
    if (_currentLocation == null) return;
    
    final pickupLocation = ll.LatLng(widget.trip.startLat, widget.trip.startLng);
    final distance = ll.Distance().distance(_currentLocation!, pickupLocation);
    
    setState(() {
      _distanceToPickup = distance;
      // Show OTP button when within 100 meters of pickup
      _showOtpButton = distance <= 100 && !_tripStarted;
    });
  }

  void _showOtpGenerationDialog() async {
    setState(() => _isLoading = true);
    
    try {
      // Get current user's email from Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add an email to your profile to receive OTP')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Generate OTP using free service
      final otp = EmailOtpService.generateOtp();
      
      // Store OTP in database
      final success = await EmailOtpService.storeOtpInTrip(
        tripId: widget.trip.id,
        otp: otp,
      );
      
      setState(() => _isLoading = false);
      
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate OTP. Please try again.')),
        );
        return;
      }
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mark_email_read, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('OTP Sent to Email'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.email_outlined, size: 48, color: Color(0xFF10B981)),
                const SizedBox(height: 16),
                Text(
                  'OTP sent to: ${user!.email}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Your OTP code has been sent to your email address.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF166534)),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Share this code with your driver to start the trip.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                  ),
                  child: Text(
                    otp,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can also share this code via WhatsApp or call',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Share via WhatsApp - TODO: Implement url_launcher
                  Navigator.pop(context);
                  _startTripStatusPolling();
                },
                child: const Text('Share via WhatsApp'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _startTripStatusPolling();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: $e')),
        );
      }
    }
  }

  void _startTripStatusPolling() {
    // Poll every 3 seconds to check if host verified OTP and started trip
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _tripStarted) {
        timer.cancel();
        return;
      }
      
      try {
        final response = await Supabase.instance.client
            .from('trips')
            .select('status')
            .eq('id', widget.trip.id)
            .single();
        
        if (response['status'] == 'in_progress') {
          setState(() => _tripStarted = true);
          await _fetchRouteFromCurrentLocation();
          timer.cancel();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Trip started! Host has verified your OTP.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        // Silently handle errors during polling
      }
    });
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

              // Route polyline (trip route)
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

              // Route from host to passenger (for host mode)
              if (widget.isHost && _hostToPassengerRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _hostToPassengerRoute,
                      strokeWidth: 5,
                      color: const Color(0xFF10B981), // Green route to passenger
                      borderStrokeWidth: 2,
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
                  // Passenger location markers (for host)
                  if (widget.isHost)
                    ..._passengerLocations.asMap().entries.map((entry) {
                      final index = entry.key;
                      final location = entry.value;
                      return Marker(
                        point: location,
                        width: 40,
                        height: 50,
                        child: _buildMarker(
                          icon: Icons.person_pin,
                          color: const Color(0xFF10B981),
                          label: 'P${index + 1}',
                        ),
                      );
                    }),
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
                    if (!widget.isHost && _showOtpButton && !_tripStarted)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _showOtpGenerationDialog,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user),
                              SizedBox(width: 8),
                              Text(
                                'Generate OTP for Host',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isHost
                                ? const Color(0xFFEF4444)
                                : _tripStarted
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: widget.isHost ? _endTrip : null,
                          child: Text(
                            widget.isHost
                                ? 'End Trip'
                                : _tripStarted
                                    ? 'Trip in Progress'
                                    : 'Waiting for Host',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                    if (!widget.isHost && !_showOtpButton && !_tripStarted)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _distanceToPickup != null
                              ? 'Distance to pickup: ${(_distanceToPickup! / 1000).toStringAsFixed(2)} km'
                              : 'Calculating distance...',
                          style: const TextStyle(
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
