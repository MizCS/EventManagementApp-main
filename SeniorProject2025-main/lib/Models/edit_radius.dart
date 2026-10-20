import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
//import 'package:geocoding/geocoding.dart';
import 'package:icebreaker/assets/geoloc.dart';
import 'package:logger/logger.dart';

class EditRadius extends StatefulWidget {
  //final SupabaseClient supabase;
  //final String? userId;
  
  const EditRadius({super.key,});

  @override
  EditRadiusState createState() => EditRadiusState();
  
}

class EditRadiusState extends State<EditRadius> {
  final currentUser = Supabase.instance.client.auth.currentUser;
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(26.306188175031327, -98.17458523021418); // Default position
  bool _isLoading = true;
  late String userId;
  double _radius = 1; // Default radius in miles
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  double zoomLevel = 16.0; // Base zoom level
  bool _isMeters = true; // Track if we're in meters mode
  final _logger = Logger();
  @override
  void initState() {
    super.initState();
    userId = currentUser?.id ?? '';
    _getCurrentLocation();
    _getRadius();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final currentLocation = await GeoLocatorService.getCurrentLatLng();
      if (currentLocation != null) {
        if (mounted) {
          setState(() {
            _initialPosition = currentLocation;
            _updateMapMarkers();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _logger.e("Error getting current location: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getRadius() async {
    final response = await Supabase.instance.client
        .from('Users')
        .select('radius_meters')
        .eq('user_id', userId)
        .single();
    if (mounted) {
      setState(() {
        // Convert to double and handle null case
        final radiusValue = response['radius_meters'];
        if (radiusValue != null) {
          // Convert to double and then to miles
          final meters = double.parse(radiusValue.toString());
          _radius = meters / 1609.34;
          // Set initial mode based on radius
          _isMeters = meters <= 200;
          if (_isMeters) {
            // If in meters mode, ensure the value is within slider range
            _radius = meters.clamp(10.0, 200.0) / 1609.34;
          }
        } else {
          _radius = 10 / 1609.34; // Default to 10 meters
          _isMeters = true;
        }
      });
    }
    _updateZoomLevel();
  }

  void _updateZoomLevel() {
    if (_mapController == null) return;
    
    // Get the actual distance in meters for zoom calculation
    final meters = _radius * 1609.34;
    
    // Adjust zoom level based on distance in meters
    if (meters <= 50) {
      zoomLevel = 18.0; // Very close view for small distances
    } else if (meters <= 100) {
      zoomLevel = 17.0;
    } else if (meters <= 200) {
      zoomLevel = 16.0;
    } else if (meters <= 500) {
      zoomLevel = 15.0;
    } else if (meters <= 1000) {
      zoomLevel = 14.0;
    } else if (meters <= 2000) {
      zoomLevel = 13.0;
    } else if (meters <= 5000) {
      zoomLevel = 12.0;
    } else if (meters <= 10000) {
      zoomLevel = 11.0;
    } else if (meters <= 20000) {
      zoomLevel = 10.0;
    } else {
      zoomLevel = 9.0; // Maximum zoom out for large distances
    }

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _initialPosition,
          zoom: zoomLevel,
        ),
      ),
    );
  }

  void _updateMapMarkers() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('user_location'),
          position: _initialPosition,
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      };

      _circles = {
        Circle(
          circleId: const CircleId('radius_circle'),
          center: _initialPosition,
          radius: _radius * 1609.34, // Convert miles to meters
          fillColor: Colors.blue.withValues(alpha:0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      };
    });
    _updateZoomLevel();
  }

  void _onRadiusChanged(double value) {
    setState(() {
      if (_isMeters) {
        if (value >= 200) {
          // Switch to miles mode
          _isMeters = false;
          _radius = 0.125; // Start at 0.125 miles (200 meters)
        } else {
          _radius = value / 1609.34; // Convert meters to miles for internal storage
        }
      } else {
        _radius = value;
        if (value < 0.125) {
          // Switch to meters mode
          _isMeters = true;
          _radius = 10 / 1609.34; // Start at 10 meters
        }
      }
      _updateMapMarkers();
    });
  }

  Future<void> _onConfirmRadius() async {
    try {
      // Convert miles back to meters before saving and round to nearest integer
      final radiusInMeters = (_radius * 1609.34).round();
      await Supabase.instance.client
          .from('Users')
          .update({'radius_meters': radiusInMeters})
          .eq('user_id', userId);
      
      if (mounted) {
        setState(() {
          Navigator.of(context).pop();
        });
      }
    } catch (e) {
      _logger.e("Error updating radius: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update radius. Please try again.')),
        );
      }
    }
  }

  String _getRadiusDisplay() {
    if (_isMeters) {
      final meters = (_radius * 1609.34).round();
      return '$meters meters';
    } else {
      return '${_radius.toStringAsFixed(1)} miles';
    }
  }

  double _getSliderValue() {
    if (_isMeters) {
      final meters = (_radius * 1609.34).clamp(10.0, 200.0);
      return meters;
    }
    return _radius.clamp(0.125, 20.0);
  }

  double _getSliderMin() {
    return _isMeters ? 10 : 0.125;
  }

  double _getSliderMax() {
    return _isMeters ? 200 : 20;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Radius', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            Expanded(
              child: Stack(
                children: [
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition,
                        zoom: zoomLevel,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        setState(() {
                          _mapController = controller;
                        });
                        _updateMapMarkers();
                      },
                      markers: _markers,
                      circles: _circles,
                      zoomControlsEnabled: false,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Slider(
              value: _getSliderValue(),
              min: _getSliderMin(),
              max: _getSliderMax(),
              onChanged: _onRadiusChanged,
            ),
            Text(_getRadiusDisplay(), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _onConfirmRadius,
              child: const Text("Confirm Radius"),
            ),
          ],
        ),
      ),
    );
  }
}